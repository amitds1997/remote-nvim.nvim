---@alias provider_type "ssh"|"docker"

---@class Provider: Object
---@field host string Host name
---@field conn_opts string Connection options
---@field provider_type provider_type Type of provider
---@field _local_neovim_install_script_path string Local path where Neovim installation script is stored
---@field _remote_neovim_home string Directory where all remote neovim data would be stored on host
---@field _remote_os os_type Remote host's OS
---@field _remote_neovim_version string Neovim version on the remote host
---@field _remote_is_windows boolean Flag indicating whether the remote system is windows
---@field _remote_workspace_id string Workspace ID associated with remote neovim
---@field _remote_workspaces_path  string Path to remote workspaces on remote host
---@field _remote_scripts_path  string Path to scripts path on the remote host
---@field _remote_workspace_id_path  string Path to the workspace associated with the remote host
---@field _remote_xdg_config_path  string Get workspace specific XDG config path
---@field _remote_xdg_data_path  string Get workspace specific XDG data path
---@field _remote_xdg_state_path  string Get workspace specific XDG state path
---@field _remote_xdg_cache_path  string Get workspace specific XDG cache path
---@field _remote_neovim_config_path  string Get neovim configuration path on the remote host
---@field _remote_neovim_install_script_path  string Get Neovim installation script path on the remote host
local Provider = require("remote-nvim.providers.middleclass")("Provider")

local Executor = require("remote-nvim.providers.executor")
local Notifier = require("remote-nvim.providers.notifier")
local remote_nvim = require("remote-nvim")

---Create new provider instance
---@param host string
---@param conn_opts? string|table
function Provider:initialize(host, conn_opts)
  assert(host ~= nil, "Host must be provided")
  self.host = host

  if type(conn_opts) == "table" then
    conn_opts = table.concat(conn_opts, " ")
  else
    conn_opts = conn_opts or ""
  end
  self.conn_opts = self:_cleanup_conn_options(conn_opts)

  -- These should be overriden in implementing classes
  self.unique_host_id = nil
  self.provider_type = nil
  self.executor = Executor()
  self.notifier = Notifier({
    title = "Remote Nvim",
  })

  -- Call these functions after initialization
  -- self:_setup_workspace_variables()

  self.workspace_config = {}
end

---Clean up connection options
---@param conn_opts string
---@return string cleaned_conn_opts
function Provider:_cleanup_conn_options(conn_opts)
  return conn_opts
end

---Setup workspace variables
function Provider:_setup_workspace_variables()
  local utils = require("remote-nvim.utils")

  if not remote_nvim.host_workspace_config:host_record_exists(self.unique_host_id) then
    remote_nvim.host_workspace_config:add_host_config(self.unique_host_id, {
      provider = self.provider_type,
      host = self.host,
      connection_options = self.conn_opts,
      remote_neovim_home = remote_nvim.config.remote_neovim_install_home,
      config_copy = nil,
      client_auto_start = nil,
      workspace_id = require("remote-nvim.utils").generate_random_string(10),
    })
  end
  self.workspace_config = remote_nvim.host_workspace_config:get_workspace_config(self.unique_host_id)

  -- Gather remote neovim version, if not setup
  if self.workspace_config.neovim_version == nil then
    remote_nvim.host_workspace_config:update_host_record(
      self.unique_host_id,
      "neovim_version",
      self:get_remote_neovim_version_preference()
    )
  end

  -- Gather remote OS information
  if self.workspace_config.os == nil then
    remote_nvim.host_workspace_config:update_host_record(self.unique_host_id, "os", self:get_remote_os())
  end

  -- Set variables from the fetched configuration
  self._remote_os = self.workspace_config.os
  self._remote_is_windows = self._remote_os == "Windows" and true or false
  self._remote_neovim_version = self.workspace_config.neovim_version
  self._remote_workspace_id = self.workspace_config.workspace_id

  -- Set up remaining workspace variables
  self._remote_neovim_home = self.workspace_config.remote_neovim_home
  self._remote_workspaces_path = utils.path_join(self._remote_is_windows, self._remote_neovim_home, "workspaces")
  self._remote_scripts_path = utils.path_join(self._remote_is_windows, self._remote_neovim_home, "scripts")
  self._remote_neovim_install_script_path = utils.path_join(
    self._remote_is_windows,
    self._remote_scripts_path,
    vim.fn.fnamemodify(remote_nvim.config.neovim_install_script_path, ":t")
  )
  self._remote_workspace_id_path =
    utils.path_join(self._remote_is_windows, self._remote_workspaces_path, self._remote_workspace_id)

  local xdg_variables = {
    config = ".config",
    cache = ".cache",
    share = utils.path_join(self._remote_is_windows, ".local", "share"),
    state = utils.path_join(self._remote_is_windows, ".local", "state"),
  }
  for xdg_name, path in pairs(xdg_variables) do
    self["_remote_xdg_" .. xdg_name .. "_path"] =
      utils.path_join(self._remote_is_windows, self._remote_workspace_id_path, path)
  end
  self._remote_neovim_config_path = utils.path_join(self._remote_is_windows, self._remote_xdg_config_path, "nvim")
end

function Provider:reset() end

---Generate host identifer using host and port on host
---@return string host_id Unique identifier for the host
function Provider:get_unique_host_id()
  error("Not implemented")
end

function Provider:get_remote_os()
  if self._remote_os == nil then
    self:run_command("uname", "Get remote OS")
    local cmd_out_lines = self.executor:job_stdout()
    local os = cmd_out_lines[#cmd_out_lines]

    if os == "Linux" then
      self._remote_os = os
    elseif os == "Darwin" then
      self._remote_os = "macOS"
    else
      local os_choices = {
        "Linux",
        "macOS",
        "Windows",
      }
      self._remote_os = self:get_selection(os_choices, {
        prompt = ("Choose remote OS (found OS '%s'): "):format(os),
        format_item = function(item)
          return ("Remote host is running %s"):format(item)
        end,
      })
    end

    self.notifier:notify(("OS is %s"):format(self._remote_os), vim.log.levels.INFO, true)
  end

  return self._remote_os
end

---Get selection choice
---@param choices string[]
---@param selection_opts table
---@return string selected_choice Selected choice
function Provider:get_selection(choices, selection_opts)
  local choice = require("remote-nvim.providers.utils").get_selection(choices, selection_opts)

  -- If the choice fails, we cannot move further so we stop the coroutine executing
  if choice == nil then
    self.notifier:notify("No selection made. Setup cancelled", vim.log.levels.WARN, true)
    local co = coroutine.running()
    if co then
      return coroutine.yield()
    else
      error("Choice is necessary to proceed.")
    end
  else
    return choice
  end
end

function Provider:verify_connection_to_host() end

function Provider:get_remote_neovim_version_preference()
  if self._remote_neovim_version == nil then
    local valid_neovim_versions = require("remote-nvim.providers.utils").get_neovim_versions()

    -- Get client version
    local api_info = vim.version()
    local client_version = "v" .. table.concat({ api_info.major, api_info.minor, api_info.patch }, ".")

    self._remote_neovim_version = self:get_selection(valid_neovim_versions, {
      prompt = "What Neovim version should be installed on remote host?",
      format_item = function(ver)
        if ver == client_version then
          return "Install Neovim " .. ver .. " (Your client version)"
        end
        return "Install Neovim " .. ver
      end,
    })
  end

  return self._remote_neovim_version
end

function Provider:get_neovim_config_upload_preference()
  if self.workspace_config.config_copy == nil then
    local choice = self:get_selection({ "Yes", "No", "Yes (always)", "No (never)" }, {
      prompt = ("Copy config at '%s' to remote host? "):format(remote_nvim.config.neovim_user_config_path),
    })

    -- Handle choices
    if choice == "Yes (always)" then
      self.workspace_config.config_copy = true
      remote_nvim.host_workspace_config:update_host_record(
        self.unique_host_id,
        "config_copy",
        self.workspace_config.config_copy
      )
    elseif choice == "No (never)" then
      self.workspace_config.config_copy = false
      remote_nvim.host_workspace_config:update_host_record(
        self.unique_host_id,
        "config_copy",
        self.workspace_config.config_copy
      )
    else
      self.workspace_config.config_copy = (choice == "Yes" and true) or false
    end
  end

  return self.workspace_config.config_copy
end

function Provider:launch_neovim() end

function Provider:clean_up_remote_host() end

---Run command over executor
---@param command string
---@param desc string Description of the command running
function Provider:run_command(command, desc)
  self.notifier:notify(("'%s' running..."):format(desc))
  self.executor:run_command(command)

  -- Handle errors
  if self.executor:last_job_status() ~= 0 then
    self.notifier:notify(("'%s' failed."):format(desc), vim.log.levels.ERROR, true)
    error(("'%s' failed"):format(desc))
  else
    self.notifier:notify(("'%s' succeeded."):format(desc), vim.log.levels.INFO)
  end
end

return Provider
