---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

local function ssh_manual_action(_)
  local ssh_args = vim.trim(vim.fn.input("ssh "))
  if ssh_args == "" then
    return
  end
  local ssh_host = ssh_args:match("%S+@%S+")

  --- If there is only one parameter provided, it must be remote host
  if #vim.split(ssh_args, "%s") == 1 then
    ssh_host = ssh_args
  end

  if ssh_host == nil or ssh_host == "" then
    vim.notify("Could not automatically determine host", vim.log.levels.WARN)
    ssh_host = vim.fn.input("Enter hostname in conn. string: ")
  end

  -- If no valid host name has been provided, exit
  if ssh_host == "" then
    vim.notify("Failed to determine the host to connect to. Aborting..", vim.log.levels.ERROR)
    return
  end
  remote_nvim.session_provider
    :get_or_initialize_session({
      host = ssh_host,
      provider_type = "ssh",
      conn_opts = { ssh_args },
    })
    :launch_neovim()
end

return {
  name = "Remote SSH: Set up using connection string",
  value = "remote-ssh-manual-input",
  action = ssh_manual_action,
  priority = 80,
  help = [[
## Description

Allows you to pass your own SSH connection string. Useful if you want to connect to a SSH host temporarily but do not want to add it to your `ssh_config` file.

Supports both key-based and password-based authentication.
]],
}
