---@class remote-nvim.providers.devpod.DevpodProvider: remote-nvim.providers.Provider
---@field super remote-nvim.providers.Provider
---@field binary string Devpod binary name
---@field ssh_provider remote-nvim.providers.ssh.SSHProvider? SSH Provider to work with the created SSH configuration
---@field _up_default_opts string[] Default arguments for bringing up the workspace
local DevpodProvider = require("remote-nvim.providers.provider"):subclass("DevpodProvider")
-- local Notifier = require("remote-nvim.providers.notifier")

local SSHProvider = require("remote-nvim.providers.ssh.ssh_provider")
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

---@param opts remote-nvim.providers.ProviderOpts Provider options
function DevpodProvider:init(opts)
  DevpodProvider.super:init({
    host = "localhost",
    conn_opts = {},
    provider_type = "local",
    log_viewer = opts.log_viewer,
  })

  self.unique_host_id = opts.unique_host_id or opts.host
  self.binary = remote_nvim.config.devpod.binary
  self.ssh_config_path = remote_nvim.config.devpod.ssh_config_path

  self._up_default_opts = {
    "--open-ide=false",
    "--configure-ssh=true",
    "--ide=none",
    "--log-output=raw",
    ("--ssh-config=%s"):format(self.ssh_config_path),
  }
  self.launch_opts = vim.list_extend(self._up_default_opts, opts.conn_opts or {})
  table.insert(self.launch_opts, opts.host)

  self.provider_type = opts.provider_type
  self.ssh_provider = nil
  self._remote_working_dir = opts.devpod_opts.working_dir
  -- self.notifier = Notifier({
  --   title = "Devpod",
  -- })
end

function DevpodProvider:is_remote_server_running()
  return self.ssh_provider and self.ssh_provider:is_remote_server_running()
end

function DevpodProvider:launch_neovim()
  if not self:is_remote_server_running() then
    self:_run_code_in_coroutine(function()
      self:run_command(
        ("%s up %s"):format(self.binary, table.concat(self.launch_opts, " ")),
        "Setting up devcontainer workspace"
      )
      -- self.notifier:notify("Devcontainer workspace created", vim.log.levels.INFO, true)
      local jout = self.executor:job_stdout()
      local ssh_host = vim.split(vim.split(jout[#jout], "'")[2], " ")[2]
      self.ssh_provider = SSHProvider({
        host = ssh_host,
        conn_opts = { "-F", self.ssh_config_path },
        log_viewer = self.log_viewer,
        unique_host_id = self.unique_host_id,
        provider_type = self.provider_type,
      })
      self.ssh_provider:_launch_neovim()
    end)
  else
    vim.notify("Neovim server is already running. Not starting a new one")
  end
end

function DevpodProvider:get_local_neovim_server_port()
  return self.ssh_provider:get_local_neovim_server_port()
end

return DevpodProvider
