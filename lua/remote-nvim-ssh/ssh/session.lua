local remote_nvim_ssh = require("remote-nvim-ssh")
local SSHJob = require("remote-nvim-ssh.ssh.job")

local SSHSession = {}
SSHSession.__index = SSHSession

function SSHSession:new(ssh_options)
  local instance = {
    ssh_binary = remote_nvim_ssh.ssh_binary,
    ssh_prompts = remote_nvim_ssh.ssh_prompts,
  }

  if type(ssh_options) == "table" then
    instance.ssh_options = table.concat(ssh_options, " ")
  else
    instance.ssh_options = ssh_options
  end

  setmetatable(instance, SSHSession)
  return instance
end

function SSHSession:verify_successful_connection()
  return SSHJob:new(self.ssh_options):verify_successful_connection()
end

return SSHSession
