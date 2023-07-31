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
    instance.ssh_options = ""
  end

  -- Determine identifier for the host in the workspace.json file
  instance.host_config_identifier = util.get_host_identifier(instance.ssh_host, instance.ssh_options)

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

function RemoteNvimSession:setup_workspace_config()
  if not remote_nvim_ssh.remote_nvim_host_config:host_exists(self.host_config_identifier) then
    remote_nvim_ssh.remote_nvim_host_config:add_host_config(self.host_config_identifier, {
      workspace_id = util.generate_random_string(10),
      connection_options = self.ssh_options,
      remote_nvim_home = remote_nvim_ssh.remote_nvim_home,
    })
  end
  self.remote_host_config = remote_nvim_ssh.remote_nvim_host_config:get_workspace_config(self
    .host_config_identifier)

  -- Workspace related configurations
  self.workspace_id = self.remote_host_config.workspace_id
  self.ssh_options = self.ssh_options or self.remote_host_config.connection_options
  self.remote_nvim_home = self.remote_host_config.remote_nvim_home
  self.remote_nvim_workspaces = util.path_join(self.remote_nvim_home, "workspaces")
  self.remote_nvim_scripts_path = util.path_join(self.remote_nvim_home, "scripts")
  self.remote_install_script_location = util.path_join(self.remote_nvim_scripts_path,
    vim.fn.fnamemodify(self.install_script, ":t"))
  self.workspace_path = util.path_join(self.remote_nvim_workspaces, self.workspace_id)
  self.workspace_xdg_config_path = util.path_join(self.workspace_path, ".config")
  self.workspace_neovim_config_uri = self.ssh_host ..
      ":" .. util.path_join(self.workspace_xdg_config_path, "nvim")
end

function RemoteNvimSession:run()
  local co = coroutine.create(function()
    local job = nil
    while #self.pending_ssh_jobs ~= 0 do
      job = table.remove(self.pending_ssh_jobs, 1)
      coroutine.yield(job:run(coroutine.running()))
      if job.exit_code ~= 0 then
        vim.notify("Job " .. job.remote_cmd .. " failed!")
        break
      else
        vim.notify("Job " .. job.remote_cmd .. " succeeded!")
      end
    end
  end)
  coroutine.resume(co)
end

function RemoteNvimSession:verify_successful_connection()
  self:add_ssh_job("echo 'Test connection'"):run()

  if self.ssh_jobs[1]:wait_for_completion() == 0 then
    -- Connection was successfully; we can generate and save a workspace config for this server
    self:setup_workspace_config()
    return true
  end
  return false
end

function RemoteNvimSession:launch()
  if not self:verify_successful_connection() then
    vim.notify("Failed to connect to host '" .. self.ssh_host .. "'")
    return nil
  end
  self:add_setup_steps()
  self:run()
  self:launch_remote_neovim_server()
  self:launch_local_neovim_client()
end

function RemoteNvimSession:add_setup_steps()
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

  -- Any port forwarding would not work until these things are golden
  self.last_setup_job = self.ssh_jobs[#self.ssh_jobs]
end

function RemoteNvimSession:get_neovim_version()
  return "stable"
end

function RemoteNvimSession:launch_local_neovim_client()
  local neovim_client_not_started = true

  local function _launch_neovim_client()
    if neovim_client_not_started and self.remote_nvim_starting_and_forwarding_job ~= nil and self.remote_nvim_starting_and_forwarding_job.job_id ~= nil and self.remote_nvim_starting_and_forwarding_job:wait_for_completion(0) == -1 and self.remote_nvim_starting_and_forwarding_job:stdout() ~= nil then
      local cmd = { "nvim", "--server", "localhost:" .. self.free_port, "--remote-ui" }
      require("lazy.util").float_term(cmd, {
        interactive = true,
        on_exit_handler = function(_, exit_code)
          if exit_code ~= 0 then
            vim.notify("Local Neovim server " .. table.concat(cmd, " ") .. " failed")
          end

          vim.fn.jobstop(self.remote_nvim_starting_and_forwarding_job.job_id)
        end,
      })
      neovim_client_not_started = false
    else
      vim.defer_fn(_launch_neovim_client, 0)
    end
  end
  vim.defer_fn(_launch_neovim_client, 0)
end

function RemoteNvimSession:_get_remote_nvim_binary_path()
  return util.path_join(self.remote_nvim_home, "nvim-downloads", self:get_neovim_version(), "bin", "nvim")
end

function RemoteNvimSession:launch_remote_neovim_server()
  local port_forwarding_job_not_started = true

  local function _launch_remote_neovim_server()
    if port_forwarding_job_not_started and self.last_setup_job:has_completed() then
      if self.remote_nvim_starting_and_forwarding_job ~= nil and not self.remote_nvim_starting_and_forwarding_job:has_completed() then
        return
      else
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

        self:add_ssh_job(remote_nvim_server_cmd, ssh_options)
        self.remote_nvim_starting_and_forwarding_job = self.ssh_jobs[#self.ssh_jobs]

        -- Kill the remote forwarding job if we exit through Neovim
        vim.api.nvim_create_autocmd({ "VimLeave" }, {
          pattern = { "*" },
          callback = function()
            vim.fn.jobstop(self.remote_nvim_starting_and_forwarding_job.job_id)
          end
        })
        self:run()
      end
    else
      vim.defer_fn(_launch_remote_neovim_server, 0)
    end
  end
  vim.defer_fn(_launch_remote_neovim_server, 0)
end

return RemoteNvimSession
