local remote_nvim_ssh = require("remote-nvim")
local SSHJob = require("remote-nvim.ssh.job")
local util = require('remote-nvim.utils')

local RemoteNvimSession = {}

function RemoteNvimSession:new(ssh_host, ssh_options)
  local instance = {
    ssh_host = ssh_host,
    ssh_binary = remote_nvim_ssh.ssh_binary,
    ssh_prompts = remote_nvim_ssh.ssh_prompts,
    install_script = remote_nvim_ssh.install_script,
    remote_nvim_home = remote_nvim_ssh.remote_nvim_home,
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
  instance.ssh_jobs = {}

  self.__index = self
  setmetatable(instance, self)
  return instance
end

function RemoteNvimSession:add_scp_job(from_uri, to_uri, recursive)
  table.insert(self.ssh_jobs, SSHJob:new(self.ssh_host, self.ssh_options):set_scp_command(from_uri, to_uri, recursive))
  return self
end

function RemoteNvimSession:add_ssh_job(cmd)
  table.insert(self.ssh_jobs, SSHJob:new(self.ssh_host, self.ssh_options):set_ssh_command(cmd))
  return self
end

function RemoteNvimSession:run()
  local co = coroutine.create(function()
    for _, job in ipairs(self.ssh_jobs) do
      vim.notify("Job " .. job.remote_cmd .. " starting...")
      coroutine.yield(job:run(coroutine.running()))
      if job.exit_code ~= 0 then
        vim.notify("Job " .. job.remote_cmd .. " failed!")
      end
    end
  end)
  coroutine.resume(co)
end

function RemoteNvimSession:verify_successful_connection()
  self:add_ssh_job("echo 'Test connection'"):run()

  if self.ssh_jobs[1]:wait_for_completion() == 0 then
    return true
  end
  return false
end

function RemoteNvimSession:launch()
  if self:verify_successful_connection() then
    vim.notify("Connected to remote host '" .. self.ssh_host .. "' successfully.")
  else
    vim.notify("Failed to connect to host '" .. self.ssh_host .. "'")
  end
  self:setup()
end

function RemoteNvimSession:setup()
  local local_install_script_uri = self.install_script
  local remote_neovim_home_uri = self.ssh_host .. ":" .. self.remote_nvim_home
  local remote_install_script_path = util.path_join(self.remote_nvim_home, vim.fn.fnamemodify(self.install_script, ":t"))
  local remote_neovim_workspaces_home = util.path_join(self.remote_nvim_home, "workspaces")
  local new_workspace_name = util.generate_random_string(10)
  local new_workspace_path = util.path_join(remote_neovim_workspaces_home, new_workspace_name)
  local new_workspace_xdg_config_path = util.path_join(new_workspace_path, ".config")
  local local_neovim_config_path = "~/.config/nvim"
  local new_workspace_neovim_config_uri = self.ssh_host .. ":" .. util.path_join(new_workspace_xdg_config_path, "nvim")
  local neovim_version = "stable"

  self
      :add_ssh_job("mkdir -p " .. remote_neovim_workspaces_home)                                              -- Create workspace directory
      :add_scp_job(local_install_script_uri, remote_neovim_home_uri)                                          -- Copy over neovim install script
      :add_ssh_job("chmod +x " .. remote_install_script_path)                                                 -- Mark the Neovim install script as executable
      :add_ssh_job(remote_install_script_path .. " -v " .. neovim_version .. " -d " .. self.remote_nvim_home) -- Install Neovim
      :add_ssh_job("mkdir -p " .. new_workspace_xdg_config_path)                                              -- Create Neovim configuration directory
      :add_scp_job(local_neovim_config_path, new_workspace_neovim_config_uri, true)                           -- Copy over Neovim configuration directory
      :run()
end

return RemoteNvimSession
