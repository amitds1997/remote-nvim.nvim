local Provider = require("remote-nvim.providers.provider")
local SSHProvider = require("remote-nvim.providers.ssh.ssh_provider")

---@class remote-nvim.providers.devpod.DevpodProvider: remote-nvim.providers.ssh.SSHProvider
---@field super remote-nvim.providers.ssh.SSHProvider
---@field binary string Devpod binary name
---@field _up_default_opts string[] Default arguments for bringing up the workspace
---@field local_provider remote-nvim.providers.Provider
local DevpodProvider = SSHProvider:subclass("DevpodProvider")
local utils = require("remote-nvim.utils")

---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

---@param opts remote-nvim.providers.ProviderOpts Provider options
function DevpodProvider:init(opts)
  assert(opts.unique_host_id ~= nil, "Unique host ID cannot be nil")
  assert(opts.host ~= nil, "Host cannot be nil")
  assert(opts.devpod_opts ~= nil, "Devpod options should not be nil")
  assert(opts.devpod_opts.source ~= nil, "Source should not be nil")

  self.unique_host_id = opts.unique_host_id
  self.host = ("%s.devpod"):format(self.unique_host_id)
  self.source = opts.devpod_opts.source
  self.provider_type = opts.provider_type
  self.binary = remote_nvim.config.devpod.binary
  self.ssh_config_path = remote_nvim.config.devpod.ssh_config_path
  self.ssh_conn_opts = { "-F", self.ssh_config_path }
  self._remote_working_dir = opts.devpod_opts.working_dir

  DevpodProvider.super.init(self, {
    host = self.host,
    conn_opts = self.ssh_conn_opts,
    provider_type = self.provider_type,
    unique_host_id = self.unique_host_id,
    progress_view = opts.progress_view,
    devpod_opts = {
      source = self.source,
      working_dir = self._remote_working_dir,
    },
  })

  self._default_opts = {
    "--log-output=raw",
  }
  self._up_default_opts = {
    "--open-ide=false",
    "--configure-ssh=true",
    "--ide=none",
    ("--ssh-config=%s"):format(self.ssh_config_path),
  }
  self._up_default_opts = vim.list_extend(self._up_default_opts, self._default_opts)
  self.launch_opts = vim.list_extend(self._up_default_opts, opts.conn_opts or {})

  self.local_provider = Provider({
    host = "localhost",
    conn_opts = {},
    provider_type = "local",
    progress_view = opts.progress_view,
  })
end

function DevpodProvider:clean_up_remote_host()
  local cb = function()
    self:_run_code_in_coroutine(function()
      self.local_provider:run_command(
        ("%s delete %s %s"):format(self.binary, table.concat(self._default_opts, " "), self.unique_host_id),
        "Delete devpod workspace"
      )
    end, "Deleting devpod workspace")
  end

  DevpodProvider.super.clean_up_remote_host(self, cb)
end

function DevpodProvider:stop_neovim()
  local cb = function()
    self:_run_code_in_coroutine(function()
      self.local_provider:run_command(
        ("%s stop %s %s"):format(self.binary, table.concat(self._default_opts, " "), self.unique_host_id),
        "Stopping devpod workspace"
      )
    end, "Stopping devpod workspace")
  end

  DevpodProvider.super.stop_neovim(self, cb)
end

function DevpodProvider:launch_neovim()
  if not self:is_remote_server_running() then
    self:_run_code_in_coroutine(function()
      self:start_progress_view_run(("Launch Neovim (Run no. %s)"):format(self._neovim_launch_number))
      self._neovim_launch_number = self._neovim_launch_number + 1

      local launch_opts = vim.deepcopy(self.launch_opts)
      launch_opts = vim.list_extend(launch_opts, { self.source, ("--id %s"):format(self.unique_host_id) })
      local devpod_up_opts = table.concat(launch_opts, " ")
      -- Remove `-F <ssh-config-path>` from devpod launch opts since that is SSH syntax not devpod
      devpod_up_opts = utils.plain_substitute(devpod_up_opts, table.concat(self.ssh_conn_opts, " "), "")

      self.local_provider:run_command(
        ("%s up %s"):format(self.binary, devpod_up_opts),
        "Setting up devcontainer workspace"
      )
      ---@diagnostic disable-next-line: invisible
      self:_launch_neovim(false)
    end, "Launching devpod workspace")
  else
    vim.notify("Neovim server is already running. Not starting a new one")
  end
end

return DevpodProvider
