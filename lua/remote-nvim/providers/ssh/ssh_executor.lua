local ExecutorInterface = require("remote-nvim.providers.executor_interface")
local RemoteNeovimConfig = require("remote-nvim")
local SSHUtils = require("remote-nvim.providers.ssh.ssh_utils")

---@class SSHRemoteExecutor: ExecutorInterface
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

setmetatable(SSHRemoteExecutor, {
  __index = ExecutorInterface,
  __call = function(cls, ...)
    return cls.new(...)
  end,
})

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
  instance.ssh_binary = RemoteNeovimConfig.config.ssh_config.ssh_binary
  instance.scp_binary = RemoteNeovimConfig.config.ssh_config.scp_binary
  instance.ssh_prompts = vim.deepcopy(RemoteNeovimConfig.config.ssh_config.ssh_prompts)

  -- Internal state management params
  instance.job_id = nil
  instance.complete_cmd = nil
  instance.job_binary = nil
  instance.job_connection_options = nil
  instance.is_job_complete = nil
  instance.is_job_complete = false
  instance.stdout_bufr = {}
  instance.stderr_bufr = {}
  instance.last_stdout_processed_idx = 1
  instance.saved_prompts = {}

  return instance
end

---Reset the state of the executor
---@private
function SSHRemoteExecutor:resetState()
  -- If the job is running, cancel it
  if self.job_id then
    self:cancel()
  end

  self.job_id = nil
  self.job_id = nil
  self.complete_cmd = nil
  self.job_binary = nil
  self.job_connection_options = nil
  self.is_job_complete = false
  self.stdout_bufr = {}
  self.stderr_bufr = {}
  self.last_stdout_processed_idx = 1
  self.saved_prompts = {}
end

---Upload file/directory from local to remote host
---@param localPath string Local path where it is to be downloaded
---@param remotePath string Path on the remote host
---@return SSHRemoteExecutor
function SSHRemoteExecutor:upload(localPath, remotePath)
  local remotePathURI = self.remote_host .. ":" .. remotePath
  local cmd = localPath .. " " .. remotePathURI

  return self:setRemoteCommand(cmd, self.scp_binary, self.scp_connection_options):runJob()
end

---Download file/directory from remote host to local machine
---@param remotePath string Path on the remote host
---@param localPath string Local path where it is to be downloaded
---@return SSHRemoteExecutor
function SSHRemoteExecutor:download(remotePath, localPath)
  local remotePathURI = self.remote_host .. ":" .. remotePath
  local cmd = remotePathURI .. " " .. localPath

  return self:setRemoteCommand(cmd, self.scp_binary, self.scp_connection_options):runJob()
end

---@private
---Set remote command to execute over the server
---@param command string Command to run on the remote server
---@param binary? string Binary to use for running this operation
---@param connection_options? string Connection options to use for the operation
---@return SSHRemoteExecutor
function SSHRemoteExecutor:setRemoteCommand(command, binary, connection_options)
  -- Reset the state of the executor
  self:resetState()

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
---@return SSHRemoteExecutor
function SSHRemoteExecutor:runCommand(command)
  return self:setRemoteCommand(command):runJob()
end

---@private
---Run job specified by command over the SSHExecutor
---@return SSHRemoteExecutor executor The executor on which the job is executing
function SSHRemoteExecutor:runJob()
  local co = coroutine.running()
  self.job_id = vim.fn.jobstart(self.complete_cmd, {
    pty = true,
    on_stdout = function(_, data)
      self:handleStdout(data)
    end,
    on_stderr = function(_, data)
      self:handleStderr(data)
    end,
    on_exit = function(_, exit_code)
      self:handleExit(exit_code)
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
function SSHRemoteExecutor:handleStdout(data)
  SSHUtils.appendTTYDataToBuffer(self.stdout_bufr, data)

  -- Check for existence of any prompt matches which indicate SSH is waiting for an input
  local search_string = table.concat({ unpack(self.stdout_bufr, self.last_stdout_processed_idx + 1) }, "")
  for _, prompt in ipairs(self.ssh_prompts) do
    if search_string:find(prompt.match) then
      self.last_stdout_processed_idx = #self.stdout_bufr

      local prompt_value
      -- If it is a "static" value prompt, use cached input values, unless values were passed in config
      if prompt.value_type == "static" and prompt.value ~= "" then
        prompt_value = prompt.value
      else
        local prompt_label = prompt.input_prompt or ("Enter " .. prompt.match .. " ")
        prompt_value = self:handleInput(prompt_label, prompt.type)

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
---@param data string[] Error string array produced by the running job
function SSHRemoteExecutor:handleStderr(data)
  SSHUtils.appendTTYDataToBuffer(self.stderr_bufr, data)
end

---@private
---@param exit_code number Exit code of the job that was just running on the executor
function SSHRemoteExecutor:handleExit(exit_code)
  self.exit_code = exit_code
  self.is_job_complete = true

  if self.exit_code == 0 then
    -- We assume that all static tokens passed so far are correct and they can be re-used for future jobs
    for idx, prompt in ipairs(self.ssh_prompts) do
      if prompt.value_type == "static" and self.saved_prompts[prompt.match] ~= nil then
        self.ssh_prompts[idx].value = self.saved_prompts[prompt.match]
      end
    end
  else
    error("Job " .. self.complete_cmd .. " failed")
  end
end

---A way for executor to send progress report about the status of job
---@param callback function Callback function to call that will provide status of the job
function SSHRemoteExecutor:monitorProgress(callback)
  --TODO: Implement monotoring progress
  callback()
end

---Get status of the currently running job
---@see vim.fn.jobwait
function SSHRemoteExecutor:getStatus()
  if self.is_job_complete then
    return self.exit_code
  end
  return vim.fn.jobwait({ self.job_id }, 0)[1]
end

---Get if the job running on the executor was successful
function SSHRemoteExecutor:isSuccessful()
  return (self.exit_code or -1) == 0
end

---Get if the job running on the executor has completed
function SSHRemoteExecutor:isCompleted()
  return self.is_job_complete
end

---Cancel the currently running job on the executor
function SSHRemoteExecutor:cancel()
  return vim.fn.jobstop(self.job_id)
end

---Handle input prompts required for running the job successfully
---@param prompt_label string Prompt label to be shown
---@param input_type? prompt_type Type of value that would be input
---@return string input_response collected from the user
function SSHRemoteExecutor:handleInput(prompt_label, input_type)
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
function SSHRemoteExecutor:getStdout()
  local lines = {}
  for line in table.concat(self.stdout_bufr, ""):gmatch("([^\r\n]+)[\r\n]*") do
    lines[#lines + 1] = line
  end
  return lines
end

---Get standard error generated by the job on the executor
---@return string[] stderr Returns stderr as an array of lines where each line is one stderr line
function SSHRemoteExecutor:getStderr()
  local lines = {}
  for line in table.concat(self.stderr_bufr, ""):gmatch("([^\r\n]+)[\r\n]*") do
    lines[#lines + 1] = line
  end
  return lines
end

return SSHRemoteExecutor
