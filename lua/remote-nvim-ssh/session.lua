local remote_nvim_ssh = require("remote-nvim-ssh")
local SSHJob = require("remote-nvim-ssh.ssh.job")

local RemoteNvimSession = {}
RemoteNvimSession.__index = RemoteNvimSession

function RemoteNvimSession:new(ssh_options)
  local instance = {
    ssh_binary = remote_nvim_ssh.ssh_binary,
    ssh_prompts = remote_nvim_ssh.ssh_prompts,
  }

  if type(ssh_options) == "table" then
    instance.ssh_options = table.concat(ssh_options, " ")
  else
    instance.ssh_options = ssh_options
  end
  instance.ssh_options = instance.ssh_options:gsub("^%s*ssh%s*", "")

  setmetatable(instance, RemoteNvimSession)
  return instance
end

function RemoteNvimSession:verify_successful_connection()
  return SSHJob:new(self.ssh_options):verify_successful_connection()
end

function RemoteNvimSession:launch()
  if self:verify_successful_connection() then
    vim.notify("Connected to remote host successfully.")
  else
    vim.notify("Failed to connect to the remote host.")
  end
end

return RemoteNvimSession
