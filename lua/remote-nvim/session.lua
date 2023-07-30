local remote_nvim_ssh = require("remote-nvim")
local SSHJob = require("remote-nvim.ssh.job")
local util = require('remote-nvim.utils')

local RemoteNvimSession = {}

function RemoteNvimSession:new(ssh_host, ssh_options)
  local instance = {
    ssh_binary = remote_nvim_ssh.ssh_binary,
    ssh_prompts = remote_nvim_ssh.ssh_prompts,
    install_script = remote_nvim_ssh.install_script,
    local_nvim_config_path = remote_nvim_ssh.local_neovim_config_path
  }
  assert(ssh_host ~= nil, "Host name cannot be nil")
  instance.ssh_host = ssh_host

  if ssh_options ~= nil then
    if type(ssh_options) == "table" then
      instance.ssh_options = table.concat(ssh_options, " ")
    else
      instance.ssh_options = ssh_options
    end
    -- The prefix `ssh` is not an option so we filter that out, if present
    instance.ssh_options = instance.ssh_options:gsub("^%s*ssh%s*", "")
  else
    instance.ssh_options = nil
  end

  -- Determine identifier for the host in the workspace.json file
  instance.host_config_identifier = ssh_host
  if instance.ssh_options ~= nil then
    local port = instance.ssh_options:match("-p%s*(%d+)")
    if port ~= nil then
      instance.host_config_identifier = instance.host_config_identifier .. ":" .. port
    end
  end
  if not remote_nvim_ssh.remote_nvim_host_config:host_exists(instance.host_config_identifier) then
    remote_nvim_ssh.remote_nvim_host_config:add_host_config(instance.host_config_identifier, {
      workspace_id = util.generate_random_string(10),
      connection_options = instance.ssh_options,
      remote_nvim_home = remote_nvim_ssh.remote_nvim_home,
    })
  end
  instance.remote_host_config = remote_nvim_ssh.remote_nvim_host_config:get_workspace_config(instance
    .host_config_identifier)

  -- Workspace related configurations
  instance.workspace_id = instance.remote_host_config.workspace_id
  instance.ssh_options = instance.ssh_options or instance.remote_host_config.connection_options
  instance.remote_nvim_home = instance.remote_host_config.remote_nvim_home
  instance.remote_nvim_workspaces = util.path_join(instance.remote_nvim_home, "workspaces")
  instance.remote_nvim_scripts_path = util.path_join(instance.remote_nvim_home, "scripts")
  instance.remote_install_script_location = util.path_join(instance.remote_nvim_scripts_path,
    vim.fn.fnamemodify(instance.install_script, ":t"))
  instance.workspace_path = util.path_join(instance.remote_nvim_workspaces, instance.workspace_id)
  instance.workspace_xdg_config_path = util.path_join(instance.workspace_path, ".config")
  instance.workspace_neovim_config_uri = instance.ssh_host ..
  ":" .. util.path_join(instance.workspace_xdg_config_path, "nvim")

  -- Track jobs executed during the session
  instance.ssh_jobs = {}
  instance.pending_ssh_jobs = {}

  self.__index = self
  setmetatable(instance, self)
  return instance
end

function RemoteNvimSession:add_scp_job(from_uri, to_uri, recursive)
  table.insert(self.ssh_jobs, SSHJob:new(self.ssh_host, self.ssh_options):set_scp_command(from_uri, to_uri, recursive))
  table.insert(self.pending_ssh_jobs, self.ssh_jobs[#self.ssh_jobs])
  return self
end

function RemoteNvimSession:add_ssh_job(cmd, ssh_options)
  table.insert(self.ssh_jobs, SSHJob:new(self.ssh_host, ssh_options or self.ssh_options):set_ssh_command(cmd))
  table.insert(self.pending_ssh_jobs, self.ssh_jobs[#self.ssh_jobs])
  return self
end

function RemoteNvimSession:run()
  local co = coroutine.create(function()
    while #self.pending_ssh_jobs ~= 0 do
      local job = table.remove(self.pending_ssh_jobs, 1)
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
  self
      :add_ssh_job("mkdir -p " .. self.remote_nvim_workspaces)                                 -- Create neovim workspace directory
      :add_ssh_job("mkdir -p " .. self.remote_nvim_scripts_path)                               -- Create neovim scripts directory
      :add_scp_job(util.path_join(util.get_package_root(), "scripts"), self.ssh_host .. ":" .. self.remote_nvim_home,
        true)                                                                                  -- Copy over neovim scripts
      :add_scp_job(self.install_script, self.ssh_host .. ":" .. self.remote_nvim_scripts_path) -- Copy over custom neovim install script
      :add_ssh_job("chmod +x " .. self.remote_install_script_location)                         -- Mark the Neovim install script as executable
      :add_ssh_job(self.remote_install_script_location ..
        " -v " .. self:get_neovim_version() .. " -d " .. self.remote_nvim_home)                -- Install Neovim
      :add_ssh_job("mkdir -p " .. self.workspace_xdg_config_path)                              -- Create Neovim configuration directory
      :add_scp_job(self.local_nvim_config_path, self.workspace_neovim_config_uri, true)        -- Copy over Neovim configuration directory
      :run()
  -- vim.cmd('sleep 15')
  -- self:launch_remote_neovim_server()
  -- self:_launch_local_neovim_server()
end

function RemoteNvimSession:get_neovim_version()
  return "stable"
end

function RemoteNvimSession:_launch_local_neovim_server()
  local cmd = { "nvim", "--server", "localhost:" .. self.free_port, "--remote-ui" }
  require("lazy.util").float_term(cmd, {
    interactive = true,
    on_exit_handler = function(_, exit_code)
      if exit_code ~= 0 then
        vim.notify("Local Neovim server failed")
      else
        vim.notify("Local Neovim server exited successfully")
      end

      vim.fn.jobstop(self.remote_nvim_starting_and_forwarding_job.job_id)
    end,
  })
  vim.notify("Neovim started: " .. table.concat(cmd, " "))
end

function RemoteNvimSession:_get_remote_nvim_binary_path()
  return util.path_join(self.remote_nvim_home, "nvim-downloads", self:get_neovim_version(), "bin", "nvim")
end

function RemoteNvimSession:launch_remote_neovim_server()
  -- Find a local free port
  self.free_port = util.find_free_port()

  -- Find a remote free port
  local free_remote_port_job = SSHJob:new(self.ssh_host, self.ssh_options):set_ssh_command(self
        :_get_remote_nvim_binary_path() ..
        " -l " .. util.path_join(self.remote_nvim_scripts_path, "free_port_finder.lua"))
      :run()
  free_remote_port_job:wait_for_completion()
  self.remote_free_port = free_remote_port_job:stdout()

  -- Set up SSH port forwarding from local to remote
  -- We add "-t" to make sure that the command terminates when we exit from Neovim
  local ssh_options = self.ssh_options .. " -t -L " .. self.free_port .. ":localhost:" .. self.remote_free_port
  local remote_nvim_server_cmd = "XDG_CONFIG_HOME=" ..
      self.workspace_xdg_config_path ..
      " " .. self:_get_remote_nvim_binary_path() .. " --listen 0.0.0.0:" .. self.remote_free_port .. " --headless"

  self.remote_nvim_starting_and_forwarding_job = SSHJob:new(self.ssh_host, ssh_options):set_ssh_command(
    remote_nvim_server_cmd)
  self.remote_nvim_starting_and_forwarding_job:run()
  table.insert(self.ssh_jobs, self.remote_nvim_starting_and_forwarding_job)


  -- Kill the remote forwarding job if we exit through Neovim
  vim.api.nvim_create_autocmd({ "VimLeave" }, {
    pattern = { "*" },
    callback = function()
      vim.fn.jobstop(self.remote_nvim_starting_and_forwarding_job.job_id)
    end
  })
end

return RemoteNvimSession
