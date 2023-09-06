---@class SSHExecutor: Executor
---@field super Executor
---@field ssh_conn_opts string Connection options for SSH command
---@field scp_connection_options string Connection options to SCP command
---@field ssh_binary string Binary to use for SSH operations
---@field scp_binary string Binary to use for SCP operations
---@field _ssh_prompts RemoteNeovimSSHPrompts[] SSH prompts registered for processing for input
---@field _job_stdout_processed_idx number Last index processed by output processor
---@field _job_prompt_responses table<string,string> Responses for prompts provided by user during the job
local SSHExecutor = require("remote-nvim.providers.executor"):subclass("SSHExecutor")

---Initialize SSH executor instance
---@param host string Host name
---@param conn_opts string Connection options
function SSHExecutor:initialize(host, conn_opts)
  SSHExecutor.super:initialize(host, conn_opts)

  self.ssh_conn_opts = self.conn_opts
  self.scp_conn_opts = self.conn_opts == "" and "-r" or self.conn_opts:gsub("%-p", "-P") .. " -r"

  local remote_neovim = require("remote-nvim")
  self.ssh_binary = remote_neovim.config.ssh_config.ssh_binary
  self.scp_binary = remote_neovim.config.ssh_config.scp_binary
  self._ssh_prompts = vim.deepcopy(remote_neovim.config.ssh_config.ssh_prompts)

  self._job_stdout_processed_idx = 0
  self._job_prompt_responses = {}
end

function SSHExecutor:reset()
  SSHExecutor.super:reset()

  self._job_stdout_processed_idx = 0
  self._job_prompt_responses = {}
end

---Upload data from local path to remote path
---@param localSrcPath string Local path
---@param remoteDestPath string Remote path
---@param cb? function Callback to call after job completion
function SSHExecutor:upload(localSrcPath, remoteDestPath, cb)
  local remotePath = ("%s:%s"):format(self.host, remoteDestPath)
  local scp_command = ("%s %s %s %s"):format(self.scp_binary, self.scp_conn_opts, localSrcPath, remotePath)

  return self:run_executor_job(scp_command, cb)
end

---Download data from remote path to local path
---@param remoteSrcPath string Remote path
---@param localDescPath string Local path
---@param cb? function Callback to call after job completion
function SSHExecutor:download(remoteSrcPath, localDescPath, cb)
  local remotePath = ("%s:%s"):format(self.host, remoteSrcPath)
  local scp_command = ("%s %s %s %s"):format(self.scp_binary, self.scp_conn_opts, remotePath, localDescPath)

  return self:run_executor_job(scp_command, cb)
end

---Run command on the remote host
---@param command string Command to be run on the remote host
---@param additional_conn_opts? string Additional command options to be added to connections opts
---@param cb? function Callback to call after job completion
function SSHExecutor:run_command(command, additional_conn_opts, cb)
  -- Append additional connection options (if any)
  local conn_opts = additional_conn_opts == nil and self.ssh_conn_opts
    or (self.ssh_conn_opts .. " " .. additional_conn_opts)

  -- Generate connection details (conn_opts + host)
  local host_conn_opts = conn_opts == "" and self.host or conn_opts .. " " .. self.host

  -- Shell escape the passed command
  local ssh_command = ("%s %s %s"):format(self.ssh_binary, host_conn_opts, vim.fn.shellescape(command))
  return self:run_executor_job(ssh_command, cb)
end

---@private
---Handle when the SSH job requires a job input
---@param prompt RemoteNeovimSSHPrompts
function SSHExecutor:_process_prompt(prompt)
  self._job_stdout_processed_idx = #self._job_stdout
  local prompt_response

  -- If it is a "static" value prompt, use cached input values, unless values were passed in config
  -- If prompt's value would not change during the session ("static"), use cached values unless they are unset (denoted
  -- by "" string)
  if prompt.value_type == "static" and prompt.value ~= "" then
    prompt_response = prompt.value
  else
    local label = prompt.input_prompt or ("Enter " .. prompt.match .. " ")
    prompt_response = require("remote-nvim.providers.ssh.ssh_utils").get_user_input(label, prompt.type)

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
function SSHExecutor:process_stdout(output_chunks)
  SSHExecutor.super:process_stdout(output_chunks)

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
  SSHExecutor.super:process_job_completion(exit_code)

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
