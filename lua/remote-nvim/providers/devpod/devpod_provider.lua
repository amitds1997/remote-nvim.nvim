local Provider = require("remote-nvim.providers.provider")
local SSHProvider = require("remote-nvim.providers.ssh.ssh_provider")

---@class remote-nvim.providers.DevpodSourceOpts
---@field name string? Name of the source
---@field id string Source specific ID
---@field type "container"|"devcontainer"|"repo"|"branch"|"pr"|"commit"|"existing"|"container"|"image" Type of devpod source

---@class remote-nvim.providers.devpod.DevpodOpts
---@field source string? What is the source for the current workspace
---@field working_dir string? Working directory to set when launching the client
---@field provider string? Name of the devpod provider
---@field source_opts remote-nvim.providers.DevpodSourceOpts Any type-specific details might be stored in this

---@class remote-nvim.providers.devpod.DevpodProvider: remote-nvim.providers.ssh.SSHProvider
---@field super remote-nvim.providers.ssh.SSHProvider
---@field binary string Devpod binary name
---@field _up_default_opts string[] Default arguments for bringing up the workspace
---@field local_provider remote-nvim.providers.Provider
---@field private _devpod_workspace_active boolean Is devpod workspace active
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
  assert(
    vim.fn.executable(remote_nvim.config.devpod.binary) == 1,
    ("Devpod binary '%s' not found"):format(remote_nvim.config.devpod.binary)
  )
  assert(opts.devpod_opts.source_opts ~= nil, "Source options should not be nil")

  self.unique_host_id = opts.unique_host_id
  self.host = ("%s.devpod"):format(self.unique_host_id)
  self.source = opts.devpod_opts.source
  self.provider_type = opts.provider_type
  self.binary = remote_nvim.config.devpod.binary
  self.ssh_config_path = remote_nvim.config.devpod.ssh_config_path
  self.ssh_conn_opts = {}
  self._remote_working_dir = opts.devpod_opts.working_dir
  self._devpod_provider = opts.devpod_opts.provider
  self._devpod_source_opts = opts.devpod_opts.source_opts

  self._default_opts = {
    "--log-output=raw",
  }
  self._up_default_opts = {
    "--open-ide=false",
    "--configure-ssh=true",
    "--ide=none",
  }
  if self._devpod_source_opts.type ~= "existing" then
    table.insert(self._up_default_opts, ("--ssh-config=%s"):format(self.ssh_config_path))
    self.ssh_conn_opts = vim.list_extend(self.ssh_conn_opts, { "-F", self.ssh_config_path })
  end

  DevpodProvider.super.init(self, {
    host = self.host,
    conn_opts = self.ssh_conn_opts,
    provider_type = self.provider_type,
    unique_host_id = self.unique_host_id,
    progress_view = opts.progress_view,
    devpod_opts = {
      source = self.source,
      working_dir = self._remote_working_dir,
      source_opts = self._devpod_source_opts,
    },
  })

  self._up_default_opts = vim.list_extend(self._up_default_opts, self._default_opts)
  self.launch_opts = vim.list_extend(self._up_default_opts, opts.conn_opts or {})

  self.local_provider = Provider({
    host = "localhost",
    conn_opts = {},
    provider_type = "local",
    progress_view = opts.progress_view,
  })
end

function DevpodProvider:_setup_workspace_variables()
  DevpodProvider.super._setup_workspace_variables(self)
  if self._host_config.devpod_source_opts == nil then
    self._host_config.devpod_source_opts = self._devpod_source_opts
    self._config_provider:update_workspace_config(self.unique_host_id, {
      devpod_source_opts = self._devpod_source_opts,
    })
  end
end

function DevpodProvider:clean_up_remote_host()
  self:_run_code_in_coroutine(function()
    self:start_progress_view_run(("Remote cleanup (Run no. %s)"):format(self._neovim_launch_number))
    self._neovim_launch_number = self._neovim_launch_number + 1

    DevpodProvider.super._cleanup_remote_host(self)

    local choice = self:get_selection({ "Yes", "No" }, {
      prompt = "Do you also want to delete the devpod workspace?",
    })

    if choice == "Yes" then
      self.local_provider:run_command(
        ("%s delete %s %s"):format(self.binary, table.concat(self._default_opts, " "), self.unique_host_id),
        "Delete devpod workspace"
      )
    end
  end, "Cleaning up devpod workspace")
end

function DevpodProvider:stop_neovim()
  local cb = function()
    if self._devpod_workspace_active then
      self:_run_code_in_coroutine(function()
        self.local_provider:run_command(
          ("%s stop %s %s"):format(self.binary, table.concat(self._default_opts, " "), self.unique_host_id),
          "Stopping devpod workspace"
        )
      end, "Stopping devpod workspace")
      self._devpod_workspace_active = false
    end
  end

  DevpodProvider.super.stop_neovim(self, cb)
end

function DevpodProvider:_stop_devpod_workspace()
  if self._devpod_workspace_active then
    vim.fn.system(("%s stop %s %s"):format(self.binary, table.concat(self._default_opts, " "), self.unique_host_id))
    self._devpod_workspace_active = false
  end
end

function DevpodProvider:_launch_devpod_workspace()
  if not self._devpod_workspace_active then
    local launch_opts = vim.deepcopy(self.launch_opts)
    launch_opts = vim.list_extend(launch_opts, { self.source, ("--id %s"):format(self.unique_host_id) })
    local devpod_up_opts = table.concat(launch_opts, " ")
    -- Remove `-F <ssh-config-path>` from devpod launch opts since that is SSH syntax not devpod
    devpod_up_opts = utils.plain_substitute(devpod_up_opts, table.concat(self.ssh_conn_opts, " "), "")

    self:_handle_provider_setup()
    self.local_provider:run_command(
      ("%s up %s"):format(self.binary, devpod_up_opts),
      "Setting up devcontainer workspace"
    )
    self._devpod_workspace_active = true
  end
end

function DevpodProvider:_handle_provider_setup()
  if self._devpod_provider then
    self.local_provider:run_command(
      ("%s provider list --output json"):format(remote_nvim.config.devpod.binary),
      ("Checking if the %s provider is present"):format(self._devpod_provider),
      nil,
      nil,
      false,
      false
    )
    local stdout = self.local_provider.executor:job_stdout()
    local provider_list_output = vim.json.decode(vim.tbl_isempty(stdout) and "{}" or table.concat(stdout, "\n"))

    -- If the provider does not exist, let's create it
    if not vim.tbl_contains(vim.tbl_keys(provider_list_output), self._devpod_provider) then
      self.local_provider:run_command(
        ("%s provider add %s"):format(remote_nvim.config.devpod.binary, self._devpod_provider),
        ("Adding %s provider to DevPod"):format(self._devpod_provider)
      )
    end
  end
end

function DevpodProvider:launch_neovim()
  self:_run_code_in_coroutine(function()
    if not self:is_remote_server_running() then
      self:start_progress_view_run(("Launch Neovim (Run no. %s)"):format(self._neovim_launch_number))
      self._neovim_launch_number = self._neovim_launch_number + 1

      self:_launch_devpod_workspace()
      vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
        callback = function()
          self:_stop_devpod_workspace()
        end,
      })
    end
    self:_launch_neovim(false)
  end, "Launching devpod workspace")
end

return DevpodProvider
