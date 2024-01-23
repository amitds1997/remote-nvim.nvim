local Executor = require("remote-nvim.providers.executor")

---@class remote-nvim.providers.ssh.SSHExecutor: remote-nvim.providers.Executor
---@field super remote-nvim.providers.Executor
---@field ssh_conn_opts string Connection options for SSH command
---@field scp_connection_options string Connection options to SCP command
---@field ssh_binary string Binary to use for SSH operations
---@field scp_binary string Binary to use for SCP operations
---@field private _ssh_prompts remote-nvim.config.PluginConfig.SSHConfig.SSHPrompt[] SSH prompts registered for processing for input
---@field private _job_stdout_processed_idx number Last index processed by output processor
---@field private _job_prompt_responses table<string,string> Responses for prompts provided by user during the job
local SSHExecutor = Executor:subclass("SSHExecutor")

---Initialize SSH executor instance
---@param host string Host name
---@param conn_opts string Connection options
function SSHExecutor:init(host, conn_opts)
  SSHExecutor.super.init(self, host, conn_opts)

  self.ssh_conn_opts = self.conn_opts
  self.scp_conn_opts = self.conn_opts == "" and "-r" or self.conn_opts:gsub("%-p", "-P") .. " -r"

  local remote_neovim = require("remote-nvim")
  self.ssh_binary = remote_neovim.config.ssh_config.ssh_binary
  self.scp_binary = remote_neovim.config.ssh_config.scp_binary
  self._ssh_prompts = vim.deepcopy(remote_neovim.config.ssh_config.ssh_prompts)

  self._job_stdout_processed_idx = 0
  self._job_prompt_responses = {}
end

---Reset ssh executor
function SSHExecutor:reset()
  SSHExecutor.super.reset(self)

  self._job_stdout_processed_idx = 0
  self._job_prompt_responses = {}
end

---Upload data from local path to remote path
---@param localSrcPath string Local path
---@param remoteDestPath string Remote path
---@param job_opts remote-nvim.provider.Executor.JobOpts
function SSHExecutor:upload(localSrcPath, remoteDestPath, job_opts)
  job_opts = job_opts or {}

  local remotePath = ("%s:%s"):format(self.host, remoteDestPath)
  local scp_command = ("%s %s %s %s"):format(self.scp_binary, self.scp_conn_opts, localSrcPath, remotePath)

  return self:run_executor_job(scp_command, job_opts)
end

---Download data from remote path to local path
---@param remoteSrcPath string Remote path
---@param localDescPath string Local path
---@param job_opts remote-nvim.provider.Executor.JobOpts
function SSHExecutor:download(remoteSrcPath, localDescPath, job_opts)
  job_opts = job_opts or {}
  local remotePath = ("%s:%s"):format(self.host, remoteSrcPath)
  local scp_command = ("%s %s %s %s"):format(self.scp_binary, self.scp_conn_opts, remotePath, localDescPath)

  return self:run_executor_job(scp_command, job_opts)
end

---Run command on the remote host
---@param command string Command to be run on the remote host
---@param job_opts remote-nvim.provider.Executor.JobOpts
function SSHExecutor:run_command(command, job_opts)
  job_opts = job_opts or {}

  -- Append additional connection options (if any)
  local conn_opts = job_opts.additional_conn_opts == nil and self.ssh_conn_opts
    or (self.ssh_conn_opts .. " " .. job_opts.additional_conn_opts)

  -- Generate connection details (conn_opts + host)
  local host_conn_opts = conn_opts == "" and self.host or conn_opts .. " " .. self.host

  -- Shell escape the passed command
  local ssh_command = ("%s %s %s"):format(self.ssh_binary, host_conn_opts, vim.fn.shellescape(command))
  return self:run_executor_job(ssh_command, job_opts)
end

---@private
---Handle when the SSH job requires a job input
---@param prompt remote-nvim.config.PluginConfig.SSHConfig.SSHPrompt
function SSHExecutor:_process_prompt(prompt)
  self._job_stdout_processed_idx = #self._job_stdout
  local prompt_response

  -- If it is a "static" value prompt, use cached input values, unless values were passed in config
  -- If prompt's value would not change during the session ("static"), use cached values unless they are unset (denoted
  -- by "" string)
  if prompt.value_type == "static" and prompt.value ~= "" then
    prompt_response = prompt.value
  else
    local job_output = self:job_stdout()
    local label = prompt.input_prompt or ("%s "):format(job_output[#job_output])
    prompt_response = require("remote-nvim.providers.utils").get_input(label, prompt.type)

    -- Saving these prompt responses is handle in the job exit handler
    if prompt.value_type == "static" then
      self._job_prompt_responses[prompt.match] = prompt_response
    end
  end
  vim.api.nvim_chan_send(self._job_id, prompt_response .. "\n")
end

---@private
---Process job output
---@param output_chunks string[]
---@param cb function? Callback to call on job output
function SSHExecutor:process_stdout(output_chunks, cb)
  SSHExecutor.super.process_stdout(self, output_chunks, cb)

  local pending_search_str = table.concat(vim.list_slice(self._job_stdout, self._job_stdout_processed_idx + 1), "")
  for _, prompt in ipairs(self._ssh_prompts) do
    if pending_search_str:find(prompt.match, 1, true) then
      self:_process_prompt(prompt)
    end
  end
end

---@private
---Process job completion
---@param exit_code number Exit code of the job that was just running on the executor
function SSHExecutor:process_job_completion(exit_code)
  SSHExecutor.super.process_job_completion(self, exit_code)

  if self._job_exit_code == 0 then
    -- If the job has successfully concluded, we have the correct prompt values at hand for "static" prompts
    for idx, prompt in ipairs(self._ssh_prompts) do
      if prompt.value_type == "static" and self._job_prompt_responses[prompt.match] ~= nil then
        self._ssh_prompts[idx].value = self._job_prompt_responses[prompt.match]
      end
    end
  end
end

return SSHExecutor
