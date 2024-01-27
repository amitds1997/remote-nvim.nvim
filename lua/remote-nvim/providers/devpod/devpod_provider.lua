---@class remote-nvim.providers.devpod.DevpodProvider: remote-nvim.providers.Provider
---@field super remote-nvim.providers.Provider
---@field binary string Devpod binary name
---@field ssh_provider remote-nvim.providers.ssh.SSHProvider? SSH Provider to work with the created SSH configuration
---@field _up_default_opts string[] Default arguments for bringing up the workspace
local DevpodProvider = require("remote-nvim.providers.provider"):subclass("DevpodProvider")
local utils = require("remote-nvim.utils")
-- local Notifier = require("remote-nvim.providers.notifier")

local SSHProvider = require("remote-nvim.providers.ssh.ssh_provider")
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

---@param opts remote-nvim.providers.ProviderOpts Provider options
function DevpodProvider:init(opts)
  DevpodProvider.super.init(self, {
    host = "localhost",
    conn_opts = {},
    provider_type = "local",
    progress_view = opts.progress_view,
  })

  self.host = utils.plain_substitute(opts.host, ".devpod", "")
  self.unique_host_id = opts.unique_host_id or opts.host
  self.binary = remote_nvim.config.devpod.binary
  self.ssh_config_path = remote_nvim.config.devpod.ssh_config_path

  self._default_opts = {
    "--log-output=raw",
    self.host,
  }
  self._up_default_opts = {
    "--open-ide=false",
    "--configure-ssh=true",
    "--ide=none",
    ("--ssh-config=%s"):format(self.ssh_config_path),
  }
  self._up_default_opts = vim.list_extend(self._up_default_opts, self._default_opts)
  self.launch_opts = vim.list_extend(self._up_default_opts, opts.conn_opts or {})

  self.provider_type = opts.provider_type
  self.ssh_provider = nil
  self._remote_working_dir = opts.devpod_opts.working_dir
end

function DevpodProvider:is_remote_server_running()
  return self.ssh_provider and self.ssh_provider:is_remote_server_running()
end

function DevpodProvider:clean_up_remote_host()
  self:_run_code_in_coroutine(function()
    self.ssh_provider:_clean_up_remote_host()
    self:run_command(
      ("%s delete %s"):format(self.binary, table.concat(self._default_opts, " ")),
      "Delete devpod workspace"
    )
  end, ("Cleaning up '%s' devpod workspace"):format(self.host))
end

function DevpodProvider:stop_neovim()
  self:_run_code_in_coroutine(function()
    self.ssh_provider:stop_neovim()
    self:run_command(
      ("%s stop %s"):format(self.binary, table.concat(self._default_opts, " ")),
      "Stopping devpod workspace"
    )
  end, "Stopping Neovim server")
end

function DevpodProvider:launch_neovim()
  if not self:is_remote_server_running() then
    self:_run_code_in_coroutine(function()
      self:start_progress_view_run(("Launch Neovim (Run no. %s)"):format(self._neovim_launch_number))
      self._neovim_launch_number = self._neovim_launch_number + 1

      local ssh_conn_opts = { "-F", self.ssh_config_path }
      local devpod_up_opts = table.concat(self.launch_opts, " ")
      -- Remove `-F <ssh-config-path>` from devpod launch opts since that is SSH syntax not devpod
      devpod_up_opts = utils.plain_substitute(devpod_up_opts, table.concat(ssh_conn_opts, " "), "")

      self:run_command(("%s up %s"):format(self.binary, devpod_up_opts), "Setting up devcontainer workspace")
      local jout = self.executor:job_stdout()
      local ssh_host = vim.split(vim.split(jout[#jout], "'")[2], " ")[2]
      self.ssh_provider = SSHProvider({
        host = ssh_host,
        conn_opts = ssh_conn_opts,
        progress_view = self.progress_viewer,
        unique_host_id = self.unique_host_id,
        provider_type = self.provider_type,
      })
      ---@diagnostic disable-next-line: invisible
      self.ssh_provider:_launch_neovim(false)
    end, "Launching devpod workspace")
  else
    vim.notify("Neovim server is already running. Not starting a new one")
  end
end

function DevpodProvider:get_local_neovim_server_port()
  return self.ssh_provider:get_local_neovim_server_port()
end

return DevpodProvider
