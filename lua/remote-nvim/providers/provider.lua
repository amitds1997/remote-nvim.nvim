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
local provider_utils = require("remote-nvim.providers.utils")
local remote_nvim = require("remote-nvim")
local utils = require("remote-nvim.utils")

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

  self.workspace_config = {}
  self:reset()
end

---Clean up connection options
---@param conn_opts string
---@return string cleaned_conn_opts
function Provider:_cleanup_conn_options(conn_opts)
  return conn_opts
end

---Setup workspace variables
function Provider:_setup_workspace_variables()
  if not remote_nvim.host_workspace_config:host_record_exists(self.unique_host_id) then
    remote_nvim.host_workspace_config:add_host_config(self.unique_host_id, {
      provider = self.provider_type,
      host = self.host,
      connection_options = self.conn_opts,
      remote_neovim_home = remote_nvim.config.remote_neovim_install_home,
      config_copy = nil,
      client_auto_start = nil,
      workspace_id = utils.generate_random_string(10),
    })
  end
  self.workspace_config = remote_nvim.host_workspace_config:get_workspace_config(self.unique_host_id)

  -- Gather remote OS information
  if self.workspace_config.os == nil then
    remote_nvim.host_workspace_config:update_host_record(self.unique_host_id, "os", self:get_remote_os())
  end

  -- Gather remote neovim version, if not setup
  if self.workspace_config.neovim_version == nil then
    remote_nvim.host_workspace_config:update_host_record(
      self.unique_host_id,
      "neovim_version",
      self:get_remote_neovim_version_preference()
    )
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
    data = utils.path_join(self._remote_is_windows, ".local", "share"),
    state = utils.path_join(self._remote_is_windows, ".local", "state"),
  }
  for xdg_name, path in pairs(xdg_variables) do
    self["_remote_xdg_" .. xdg_name .. "_path"] =
      utils.path_join(self._remote_is_windows, self._remote_workspace_id_path, path)
  end
  self._remote_neovim_config_path = utils.path_join(self._remote_is_windows, self._remote_xdg_config_path, "nvim")
end

function Provider:reset()
  self._setup_running = false
  self._remote_server_process_id = nil
  self._local_free_port = nil
end

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
  local choice = provider_utils.get_selection(choices, selection_opts)

  -- If the choice fails, we cannot move further so we stop the coroutine executing
  if choice == nil then
    self.notifier:notify("No selection made", vim.log.levels.WARN, true)
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

function Provider:verify_connection_to_host()
  self:run_command("echo 'OK'", "Check host connection")
  self.notifier:notify("Successfully connected to remote host", vim.log.levels.INFO, true)
end

function Provider:get_remote_neovim_version_preference()
  if self._remote_neovim_version == nil then
    local valid_neovim_versions = provider_utils.get_neovim_versions()

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

function Provider:_remote_server_already_running()
  return self._remote_server_process_id ~= nil and (vim.fn.jobwait({ self._remote_server_process_id }, 0)[1] == -1)
end

function Provider:_remote_neovim_binary_path()
  return utils.path_join(
    self._remote_is_windows,
    self._remote_neovim_home,
    "nvim-downloads",
    self._remote_neovim_version,
    "bin",
    "nvim"
  )
end

function Provider:clean_up_remote_host()
  provider_utils.run_code_in_coroutine(function()
    self:verify_connection_to_host()
    local deletion_choices = {
      "Delete neovim workspace (Choose if multiple people use the same user account)",
      "Delete remote neovim from remote host (Nuke it!)",
    }

    local cleanup_choice = self:get_selection(deletion_choices, {
      prompt = "Choose what should be cleaned up?",
    })
    if cleanup_choice == deletion_choices[1] then
      self:run_command(
        ("rm -rf %s"):format(self._remote_workspace_id_path),
        "Delete remote nvim workspace from remote host"
      )
    elseif cleanup_choice == deletion_choices[2] then
      self:run_command(("rm -rf %s"):format(self._remote_neovim_home), "Delete remote nvim from remote host")
    end

    self.notifier:notify("Cleanup on remote host completed")
  end)

  remote_nvim.host_workspace_config:delete_workspace(self.unique_host_id)
end

function Provider:_handle_job_completion(desc)
  if self.executor:last_job_status() ~= 0 then
    self.notifier:notify(("'%s' failed."):format(desc), vim.log.levels.ERROR, true)
    error(("'%s' failed"):format(desc))
  else
    self.notifier:notify(("'%s' succeeded."):format(desc), vim.log.levels.INFO)
  end
end

---Run command over executor
---@param command string
---@param desc string Description of the command running
function Provider:run_command(command, desc, ...)
  self.notifier:notify(("'%s' running..."):format(desc))
  self.executor:run_command(command, ...)
  self:_handle_job_completion(desc)
end

function Provider:upload(local_path, remote_path, desc)
  self.notifier:notify(("'%s' upload running..."):format(desc))
  self.executor:upload(local_path, remote_path)
  self:_handle_job_completion(desc)
end

return Provider
