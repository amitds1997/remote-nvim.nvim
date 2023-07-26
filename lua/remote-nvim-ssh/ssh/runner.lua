local remote_nvim_ssh = require("remote-nvim-ssh")
M = {}

local function handle_ssh_exit(job_id, exit_code, _)
  if exit_code ~= 0 then
    vim.notify("Job ID " .. job_id .. " failed. Please check.")
  else
    vim.notify("Job ID " .. job_id .. " completed.")
  end
end

local function handle_ssh_stdout(job_id, data, _)
  local p = string.gsub(table.concat(data, "\n"), "\r", "")
  for _, prompt_info in ipairs(remote_nvim_ssh.ssh_prompts) do
    if string.find(p, prompt_info.match) then
      local prompt_response = nil
      local input_prompt = prompt_info.input_prompt or ("Enter " .. prompt_info.match .. " ")
      if prompt_info.type == "secret" then
        prompt_response = vim.fn.inputsecret(input_prompt)
      else
        prompt_response = vim.fn.input(input_prompt)
      end
      vim.api.nvim_chan_send(job_id, prompt_response .. "\n")
    end
  end
end

local function handle_ssh_stderr(job_id, data, _)
  handle_ssh_stdout(job_id, data, _)
end

function M.run_ssh_command(ssh_args, cmd)
  -- Create SSH connection string
  local ssh_dest_and_options
  if type(ssh_args) == "table" then
    ssh_dest_and_options = table.concat(ssh_args, " ")
  else
    ssh_dest_and_options = ssh_args
  end

  -- If nothing, just run exit
  local cmd_on_remote = cmd or "exit"
  local ssh_cmd = table.concat({ remote_nvim_ssh.ssh_binary, ssh_dest_and_options, cmd_on_remote }, " ")

  local job_id = vim.fn.jobstart(ssh_cmd, {
    pty = true, -- Important because SSH commands can be interactive e.g. password authentication
    on_stdout = handle_ssh_stdout,
    on_stderr = handle_ssh_stderr,
    on_exit = handle_ssh_exit,
  })
  return job_id
end

return M
