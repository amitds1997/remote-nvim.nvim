local remote_neovim = require("remote-nvim")
local ssh_utils = require("remote-nvim.providers.ssh.ssh_utils")
local logger = require("remote-nvim.utils").logger

---@class SSHRemoteExecutor
---@field remote_host string Host name of the remote host
---@field ssh_connection_options string Connection options to run SSH to remote host
---@field scp_connection_options string Connection options to run SCP to remote host
---@field ssh_binary string Binary to use for SSH operations
---@field scp_binary string Binary to use for SCP operations
---@field job_id integer|nil Job ID of the current running job
---@field complete_cmd string|nil Complete SSH command being run
---@field job_binary string|nil Binary being used to run the SSH operation
---@field job_connection_options string Connection options used when running the job
---@field is_job_complete boolean If the job running on executor has completed
---@field stdout_bufr string[] Buffer containing stdout data if job is running
---@field stderr_bufr string[] Buffer containing stdout data if job is running
---@field last_stdout_processed_idx number Index of last processed index for inputs in stdout
---@field ssh_prompts RemoteNeovimSSHPrompts[] SSH prompts registered for processing for input
---@field saved_prompts table<string,string> Saved SSH prompts
local SSHRemoteExecutor = {}
SSHRemoteExecutor.__index = SSHRemoteExecutor

---Get a new instance of SSH Executor
---@param host string Host on which the remote executor would work
---@param connection_options string Connection options needed to work with remote host
---@return SSHRemoteExecutor
function SSHRemoteExecutor:new(host, connection_options)
  ---@type SSHRemoteExecutor
  local instance = setmetatable({}, SSHRemoteExecutor)

  instance.remote_host = host
  instance.ssh_connection_options = connection_options
  instance.scp_connection_options = connection_options:gsub("%-p", "-P") .. " -r "

  -- Configurations passed into plugin
  instance.ssh_binary = remote_neovim.config.ssh_config.ssh_binary
  instance.scp_binary = remote_neovim.config.ssh_config.scp_binary
  instance.ssh_prompts = vim.deepcopy(remote_neovim.config.ssh_config.ssh_prompts)

  -- Internal state management params
  instance.job_id = nil
  instance.complete_cmd = nil
  instance.job_binary = nil
  instance.job_connection_options = nil
  instance.is_job_complete = nil
  instance.is_job_complete = false
  instance.stdout_bufr = {}
  instance.stderr_bufr = {}
  instance.last_stdout_processed_idx = 0
  instance.saved_prompts = {}

  return instance
end

---@private
---Reset the state of the executor
function SSHRemoteExecutor:reset()
  self.job_id = nil
  self.complete_cmd = nil
  self.job_binary = nil
  self.job_connection_options = nil
  self.is_job_complete = false
  self.stdout_bufr = {}
  self.stderr_bufr = {}
  self.last_stdout_processed_idx = 0
  self.saved_prompts = {}
end

---Upload file/directory from local to remote host
---@param localPath string Local path where it is to be downloaded
---@param remotePath string Path on the remote host
---@return SSHRemoteExecutor executor Executor on which the command is running
function SSHRemoteExecutor:upload(localPath, remotePath)
  local remotePathURI = self.remote_host .. ":" .. remotePath
  local cmd = localPath .. " " .. remotePathURI

  return self:set_command(cmd, self.scp_binary, self.scp_connection_options):run_job()
end

---Download file/directory from remote host to local machine
---@param remotePath string Path on the remote host
---@param localPath string Local path where it is to be downloaded
---@return SSHRemoteExecutor executor Executor on which the command is running
function SSHRemoteExecutor:download(remotePath, localPath)
  local remotePathURI = self.remote_host .. ":" .. remotePath
  local cmd = remotePathURI .. " " .. localPath

  return self:set_command(cmd, self.scp_binary, self.scp_connection_options):run_job()
end

---@private
---Set remote command to execute over the server
---@param command string Command to run on the remote server
---@param binary? string Binary to use for running this operation
---@param connection_options? string Connection options to use for the operation
---@return SSHRemoteExecutor executor Executor on which the command is running
function SSHRemoteExecutor:set_command(command, binary, connection_options)
  -- Reset the state of the executor
  self:reset()

  -- By default, we use the SSH binary and connection options
  self.job_binary = binary or self.ssh_binary
  self.job_connection_options = connection_options or self.ssh_connection_options

  -- For SSH commands, we need to correctly shell escape the command so it gets executed correctly on remote
  if self.job_binary == self.ssh_binary then
    command = vim.fn.shellescape(command)
    self.job_connection_options = self.job_connection_options .. " " .. self.remote_host
  end

  self.complete_cmd = table.concat({ self.job_binary, self.job_connection_options, command }, " ")

  return self
end

---SSH command to run over the remote host
---@param command string Command to run on the remote host
---@param connection_options? string Connection operations for the command to be run
---@param exit_cb? function Function to be run on exit of job
---@return SSHRemoteExecutor executor Executor on which the command is running
function SSHRemoteExecutor:run_command(command, connection_options, exit_cb)
  return self:set_command(command, self.ssh_binary, connection_options):run_job(exit_cb)
end

---@private
---@async
---Run job specified by command over the SSHExecutor
---@param exit_cb? function Function to be run on exit of job
---@return SSHRemoteExecutor executor The executor on which the job is executing
function SSHRemoteExecutor:run_job(exit_cb)
  local co = coroutine.running()
  logger.fmt_debug(
    "Starting jobstart with command %s over SSH (Inside coroutine: %s)",
    self.complete_cmd,
    co and "Yes" or "No"
  )
  self.job_id = vim.fn.jobstart(self.complete_cmd, {
    pty = true,
    on_stdout = function(_, data)
      self:handle_stdout(data)
    end,
    on_exit = function(_, exit_code)
      self:handle_exit(exit_code)
      if exit_cb ~= nil then
        exit_cb()
      end
      if co ~= nil then
        coroutine.resume(co)
      end
    end,
  })

  -- If we are running inside a coroutine, we yield now
  if co ~= nil then
    return coroutine.yield(self)
  end
  return self
end

---@private
---@param data string[] Data string array produced by the running job
function SSHRemoteExecutor:handle_stdout(data)
  ssh_utils.append_tty_data_to_buffer(self.stdout_bufr, data)

  -- Check for existence of any prompt matches which indicate SSH is waiting for an input
  local search_string = table.concat(vim.list_slice(self.stdout_bufr, self.last_stdout_processed_idx + 1), "")
  logger.fmt_debug("Current search string is %s", search_string)
  for _, prompt in ipairs(self.ssh_prompts) do
    logger.fmt_debug("Looking for %s in search string", prompt.match)
    if search_string:find(prompt.match) then
      logger.fmt_debug("Got a prompt match: %s", prompt.match)
      self.last_stdout_processed_idx = #self.stdout_bufr

      local prompt_value
      -- If it is a "static" value prompt, use cached input values, unless values were passed in config
      if prompt.value_type == "static" and prompt.value ~= "" then
        logger.fmt_debug("Using cached value for %s", prompt.match)
        prompt_value = prompt.value
      else
        logger.fmt_debug("Fetching user input for %s", prompt.match)
        local prompt_label = prompt.input_prompt or ("Enter " .. prompt.match .. " ")
        prompt_value = self:handle_input(prompt_label, prompt.type)

        -- If there was a need to get input, cache it to be used in future jobs for "static" prompts, second part of this logic runs in the exit handler
        ---@see SSHRemoteExecutor.handleExit
        if prompt.value_type == "static" then
          self.saved_prompts[prompt.match] = prompt_value
        end
      end
      vim.api.nvim_chan_send(self.job_id, prompt_value .. "\n")
    end
  end
end

---@private
---@param exit_code number Exit code of the job that was just running on the executor
function SSHRemoteExecutor:handle_exit(exit_code)
  self.exit_code = exit_code
  self.is_job_complete = true

  if self.exit_code == 0 then
    -- We assume that all static tokens passed so far are correct and they can be re-used for future jobs
    for idx, prompt in ipairs(self.ssh_prompts) do
      if prompt.value_type == "static" and self.saved_prompts[prompt.match] ~= nil then
        self.ssh_prompts[idx].value = self.saved_prompts[prompt.match]
      end
    end
  end
end

---Get status of the currently running job
---@see vim.fn.jobwait for output info
function SSHRemoteExecutor:get_status()
  if self.is_job_complete then
    return self.exit_code
  end
  return vim.fn.jobwait({ self.job_id }, 0)[1]
end

---Get if the job running on the executor was successful
---@return boolean job_successful Flag indicating if the last running job succeeded
function SSHRemoteExecutor:is_successful()
  return (self.exit_code or -1) == 0
end

---Get if the job running on the executor has completed
---@return boolean job_completed Flag indicating if the last running job completed
function SSHRemoteExecutor:is_completed()
  return self.is_job_complete
end

---Cancel the currently running job on the executor
---@return number status Returns 1 for valid job id, 0 for invalid id, including jobs have exited or stopped.
function SSHRemoteExecutor:cancel()
  return vim.fn.jobstop(self.job_id)
end

---Handle input prompts required for running the job successfully
---@param prompt_label string Prompt label to be shown
---@param input_type? prompt_type Type of value that would be input
---@return string input_response collected from the user
function SSHRemoteExecutor:handle_input(prompt_label, input_type)
  ---@type prompt_type
  local prompt_type = input_type or "plain"

  if prompt_type == "secret" then
    return vim.fn.inputsecret(prompt_label)
  else
    return vim.fn.input(prompt_label)
  end
end

---Get standard output generated by the job on the executor
---@return string[] stdout Returns stdout as an array of lines where each line is one line of stdout
function SSHRemoteExecutor:get_stdout()
  local lines = {}
  for line in table.concat(self.stdout_bufr, ""):gmatch("([^\r\n]+)[\r\n]*") do
    lines[#lines + 1] = line
  end
  return lines
end

---Get standard error generated by the job on the executor
---@return string[] stderr Returns stderr as an array of lines where each line is one stderr line
function SSHRemoteExecutor:get_stderr()
  local lines = {}
  for line in table.concat(self.stderr_bufr, ""):gmatch("([^\r\n]+)[\r\n]*") do
    lines[#lines + 1] = line
  end
  return lines
end

return SSHRemoteExecutor
