local remote_nvim_ssh = require("remote-nvim")

local SSHJob = {}
SSHJob.__index = SSHJob

function SSHJob:new(ssh_host, ssh_options)
  local instance = {
    ssh_host = ssh_host,
    ssh_binary = remote_nvim_ssh.ssh_binary,
    scp_binary = remote_nvim_ssh.scp_binary,
    ssh_prompts = remote_nvim_ssh.ssh_prompts,
    default_remote_cmd = "echo OK",
    remote_cmd = nil,
    exit_code = nil,
    stdout_data = "",
    stderr_data = "",
    complete_cmd = nil,
    job_id = nil,
    _is_job_complete = false,
    _remote_cmd_output_separator = "===START-OF-remote-nvim-OUTPUT===",
    _stdout_lines = {},
    _stderr_lines = {},
    _stdout_last_prompt_index = 1,
    _stderr_last_prompt_index = 1,
  }

  if type(ssh_options) == "table" then
    instance.ssh_options = table.concat(ssh_options, " ")
  else
    instance.ssh_options = ssh_options
  end

  -- Actual options would only contain options and not the hostname so we filter that out
  -- We also have to escape each non-alphanumeric character because some are treated specially
  -- by Lua.
  instance.ssh_options = instance.ssh_options:gsub(instance.ssh_host:gsub("([^%w])", "%%%1"), "")
  -- We remove "-N" from SSH options if it exists; we remove extra spaces
  instance.ssh_options = instance.ssh_options:gsub("%-N", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

  instance.default_separator_cmd = "echo '" .. instance._remote_cmd_output_separator .. "'"

  setmetatable(instance, SSHJob)
  return instance
end

function SSHJob:_handle_stdout(data)
  -- Handle partial (incomplete) lines: https://neovim.io/doc/user/job_control.html#job-control
  for _, datum in ipairs(data) do
    -- Replace '\r' - terminals add it and we run the job in a terminal
    local value = datum:gsub("\r", "\n")

    self.stdout_data = self.stdout_data .. value
    table.insert(self._stdout_lines, value)
  end
  local search_field = table.concat({ unpack(self._stdout_lines, self._stdout_last_prompt_index + 1) }, "")

  for _, prompt in ipairs(self.ssh_prompts) do
    if search_field:find(prompt.match) then
      -- We found a match so all strings until now are done for
      self._stdout_last_prompt_index = #self._stdout_lines
      local prompt_label = prompt.input_prompt or ("Enter " .. prompt.match .. " ")

      local prompt_response
      -- TODO: Switch away from vim.fn.inputsecret since it is a blocking call
      if prompt.type == "secret" then
        prompt_response = vim.fn.inputsecret(prompt_label)
      else
        prompt_response = vim.fn.input(prompt_label)
      end

      vim.api.nvim_chan_send(self.job_id, prompt_response .. "\n")
    end
  end
end

function SSHJob:_handle_stderr(data)
  for _, datum in ipairs(data) do
    local value = datum:gsub("\r", "")

    self.stderr_data = self.stderr_data .. value
    table.insert(self._stderr_lines, datum:gsub("\r", ""))
  end
end

function SSHJob:_handle_exit(exit_code)
  self._is_job_complete = true

  self.exit_code = exit_code
  if exit_code ~= 0 then
    vim.notify("Remote command: " .. self.remote_cmd .. " failed.")
  else
    vim.notify("Remote command: " .. self.remote_cmd .. " succeeded.")
  end
end

function SSHJob:_filter_result(data)
  local matchPattern = "\n" .. self._remote_cmd_output_separator .. "\n"
  local start_index, end_index = (data or ""):find(matchPattern, 1, true)
  if start_index and end_index then
    return data:sub(end_index + 1):gsub("[\n]+$", "")
  end
  return nil
end

function SSHJob:set_ssh_command(cmd)
  self.remote_cmd = cmd or self.default_remote_cmd

  local complete_remote_cmd = vim.fn.shellescape(self.default_separator_cmd .. " && " .. self.remote_cmd)
  self.complete_cmd = table.concat({ self.ssh_binary, self.ssh_options, self.ssh_host, complete_remote_cmd }, " ")
  return self
end

function SSHJob:set_scp_command(from_uri, to_uri, recursive)
  local recursive_flag = recursive and "-r" or ""
  -- SSH's -p for port conflicts with -p used in scp to preserve timestampts so change that to -P
  local ssh_options = self.ssh_options:gsub("%-p", "-P")
  self.remote_cmd = "scp " .. from_uri .. " " .. to_uri

  self.complete_cmd = table.concat({ self.scp_binary, ssh_options, recursive_flag, from_uri, to_uri }, " ")
  return self
end

function SSHJob:run(co)
  assert(self.complete_cmd ~= nil, "Set run command using set_ssh_command() or set_scp_command()")
  self.job_id = vim.fn.jobstart(self.complete_cmd, {
    pty = true, -- Important because SSH commands can be interactive e.g. password authentication
    on_stdout = function(_, data)
      self:_handle_stdout(data)
    end,
    on_stderr = function(_, data)
      self:_handle_stderr(data)
    end,
    on_exit = function(_, exit_code)
      self:_handle_exit(exit_code)
      if co ~= nil then
        coroutine.resume(co)
      end
    end
  })

  return self
end

function SSHJob:wait_for_completion(timeout)
  if self._is_job_complete then
    return self.exit_code
  end
  return vim.fn.jobwait({ self.job_id }, timeout or -1)[1]
end

function SSHJob:stdout()
  return self:_filter_result(self.stdout_data)
end

function SSHJob:stderr()
  return self:_filter_result(self.stderr_data)
end

function SSHJob:is_successful()
  return (self.exit_code or -1) == 0
end

return SSHJob
