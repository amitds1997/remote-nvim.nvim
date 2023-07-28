local remote_nvim_ssh = require("remote-nvim-ssh")
local SSHJob = require("remote-nvim-ssh.ssh.job")

local RemoteNvimSession = {}

function RemoteNvimSession:new(ssh_host, ssh_options)
  local instance = {
    ssh_host = ssh_host,
    ssh_binary = remote_nvim_ssh.ssh_binary,
    ssh_prompts = remote_nvim_ssh.ssh_prompts,
  }
  assert(ssh_host ~= nil, "Host name cannot be nil")
  assert(ssh_options ~= nil, "SSH details have to be provided.")

  if type(ssh_options) == "table" then
    instance.ssh_options = table.concat(ssh_options, " ")
  else
    instance.ssh_options = ssh_options
  end
  -- The prefix `ssh` is not an option so we filter that out
  instance.ssh_options = instance.ssh_options:gsub("^%s*ssh%s*", "")

  self.__index = self
  setmetatable(instance, self)
  return instance
end

function RemoteNvimSession:verify_successful_connection()
  local job = SSHJob:new(self.ssh_host, self.ssh_options):run_command("echo 'Test connection'")

  if job:wait_for_completion() == 0 and job.exit_code == 0 then
    return true
  end
  return false
end

function RemoteNvimSession:launch()
  if self:verify_successful_connection() then
    vim.notify("Connected to remote host '" .. self.ssh_host .. "' successfully.")
  else
    vim.notify("Failed to connect to host '".. self.ssh_host.."'")
  end
end

return RemoteNvimSession
