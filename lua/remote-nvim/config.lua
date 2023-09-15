local utils = require("remote-nvim.utils")

---Create workspace config path if not exists already
local function get_or_create_workspace_config_path()
  --- Create plugin data directory if not exists
  local plugin_data_dir = utils.path_join(utils.is_windows, vim.fn.stdpath("data"), utils.PLUGIN_NAME)
  if not vim.loop.fs_stat(plugin_data_dir) then
    local success, err = vim.loop.fs_mkdir(plugin_data_dir, 493) -- 493 is the permission mode for directories (0755 in octal)
    if not success then
      print("Failed to create directory:", err)
    end
  end

  local workspace_config_path = utils.path_join(utils.is_windows, plugin_data_dir, "workspace.json")
  local file = io.open(workspace_config_path, "a")
  if file then
    file:close()
  end
  return workspace_config_path
end

---@alias provider "ssh"
---@alias os_type "macOS"|"Windows"|"Linux"

---@class WorkspaceConfig Workspace config for a remote host
---@field provider provider Which provider is responsible for managing this workspace
---@field workspace_id string Unique ID for workspace
---@field os os_type OS running on the remote host
---@field host string Host name to whom the workspace belongs
---@field neovim_version string Version of Neovim running on the remote
---@field connection_options string Connection options needed to connect to the remote host
---@field remote_neovim_home string Path on remote host where remote-neovim installs/configures things
---@field config_copy? boolean Flag indicating if the config should be copied or not
---@field client_auto_start? boolean Flag indicating if the client should be auto started or not

---@class NeovimWorkspaceConfig Handles saving workspace information for each remote host
---@field workspace_config_path string Path where the workspace config will be stored as JSON
---@field data table<string, WorkspaceConfig> Object holding the configuration data that is synced with the file
local NeovimRemoteWorkspaceConfig = {}
NeovimRemoteWorkspaceConfig.__index = NeovimRemoteWorkspaceConfig

function NeovimRemoteWorkspaceConfig.new()
  local self = setmetatable({}, NeovimRemoteWorkspaceConfig)
  self.workspace_config_path = get_or_create_workspace_config_path()
  self.data = self:read_file() or {}
  return self
end

function NeovimRemoteWorkspaceConfig:read_file()
  local file = io.open(self.workspace_config_path, "r")
  if file then
    local content = file:read("*all")
    file:close()
    if content and content ~= "" then
      return vim.fn.json_decode(content)
    end
  end
  return nil
end

function NeovimRemoteWorkspaceConfig:write_file()
  local file = io.open(self.workspace_config_path, "w")
  if file then
    local content = vim.fn.json_encode(self.data)
    file:write(content)
    file:close()
    return true
  end
  return false
end

---Get workspace configuration for host identifier
---@param host_id string Host identifier
---@return WorkspaceConfig workspace_config Workspace config for the identifier
function NeovimRemoteWorkspaceConfig:get_workspace_config(host_id)
  if not self.data[host_id] then
    ---@diagnostic disable-next-line: missing-fields
    self.data[host_id] = {}
  end

  return self.data[host_id]
end

function NeovimRemoteWorkspaceConfig:delete_workspace(host_id)
  if self.data[host_id] then
    self.data[host_id] = nil
    self:write_file()
    return true
  end
  return false
end

function NeovimRemoteWorkspaceConfig:host_record_exists(host_id)
  return self.data[host_id] ~= nil
end

function NeovimRemoteWorkspaceConfig:get_all_host_ids()
  local host_ids = {}
  for host_id in pairs(self.data) do
    table.insert(host_ids, host_id)
  end
  return host_ids
end

---Update a key value pair for an existing host config
---@param host_id string Host identifier
---@param key string Key to update in the record
---@param value any Value to be updated with
---@return boolean status Status of the update
function NeovimRemoteWorkspaceConfig:update_host_record(host_id, key, value)
  if not self.data[host_id] then
    error("Host ID does not exist. Use NeovimWorkspaceConfig:add_host_config() to add new host config")
  end
  self.data[host_id][key] = value
  self:write_file()
  return true
end

---Add new host workspace configuration to the config
---@param host_id string Host identifier for the remote host
---@param workspace_config WorkspaceConfig Workspace configuration for the host
function NeovimRemoteWorkspaceConfig:add_host_config(host_id, workspace_config)
  if not self.data[host_id] then
    self.data[host_id] = workspace_config
    self:write_file()
    return true
  end
  return false
end

return NeovimRemoteWorkspaceConfig
