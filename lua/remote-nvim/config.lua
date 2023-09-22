---@class remote-nvim.ConfigProvider: remote-nvim.Object
---@field private _config_path table Plenary path object representing configuration path
---@field private _config_data table<string, remote-nvim.providers.WorkspaceConfig> Configuration data
local ConfigProvider = require("remote-nvim.middleclass")("ConfigProvider")
local Path = require("plenary.path")

---Initialize config provider instance
function ConfigProvider:init()
  self._config_path =
    Path:new({ vim.fn.stdpath("data"), require("remote-nvim.constants").PLUGIN_NAME, "workspace.json" })
  self._config_path:touch({ mode = 493, parents = true }) -- Ensure that the path exists

  local config_data = self._config_path:read()
  if config_data == "" then
    ---@diagnostic disable-next-line: missing-fields
    self._config_data = {}
  else
    self._config_data = vim.json.decode(config_data)
  end
end

---Get configuration data by host or provider type
---@param host_id string? Host identifier
---@param provider_type string? Provider type for the configuration records
---@return table<string,remote-nvim.providers.WorkspaceConfig>|remote-nvim.providers.WorkspaceConfig wk_config Workspace configuration filtered by provided type
function ConfigProvider:get_workspace_config(host_id, provider_type)
  local workspace_config
  if provider_type then
    workspace_config = {}
    for ws_id, ws_config in pairs(self._config_data) do
      if ws_config.provider == provider_type then
        workspace_config[ws_id] = ws_config
      end
    end
  else
    workspace_config = self._config_data
  end

  if host_id then
    return workspace_config[host_id] or {}
  end

  return workspace_config
end

---Get all host identifiers
---@return string[] host_id_list List of host identifiers
function ConfigProvider:get_host_ids()
  return vim.tbl_keys(self._config_data)
end

---Add a workspace config record
---@param host_id string Host identifier
---@param ws_config remote-nvim.providers.WorkspaceConfig Workspace config to be added
---@return remote-nvim.providers.WorkspaceConfig wk_config Added host configuration
function ConfigProvider:add_workspace_config(host_id, ws_config)
  assert(ws_config ~= nil, "Workspace config cannot be nil")
  local wk_config = self:update_workspace_config(host_id, ws_config)
  assert(wk_config ~= nil, ("Added configuration for host %s should not be nil"):format(host_id))
  return wk_config
end

---Update workspace configuration given host identifier
---@param host_id string Host identifier for the configuration record
---@param ws_config remote-nvim.providers.WorkspaceConfig? Workspace configuration that should be merged with existing record
---@return remote-nvim.providers.WorkspaceConfig? wk_config nil, if record is deleted, else the updated workspace configuration
function ConfigProvider:update_workspace_config(host_id, ws_config)
  if ws_config then
    self._config_data[host_id] = vim.tbl_extend("force", self:get_workspace_config(host_id), ws_config)
  else
    self._config_data[host_id] = nil
  end
  self._config_path:write(vim.json.encode(self._config_data), "w")
  return self._config_data[host_id]
end

---Delete workspace configuration
---@param host_id string Host identifier for the configuration to be deleted
---@return nil
function ConfigProvider:remove_workspace_config(host_id)
  return self:update_workspace_config(host_id, nil)
end

return ConfigProvider
