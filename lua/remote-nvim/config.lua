local ConfigProvider = require("remote-nvim.middleclass")("ConfigProvider")
local Path = require("plenary.path")

function ConfigProvider:initialize()
  self._config_path = Path:new({ vim.fn.stdpath("data"), require("remote-nvim.utils").PLUGIN_NAME, "workspace.json" })
  self._config_path:touch({ mode = 493, parents = true }) -- Ensure that the path exists

  local config_data = self._config_path:read()
  if config_data == "" then
    self._config_data = {}
  else
    self._config_data = vim.json.decode(config_data)
  end
end

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

function ConfigProvider:get_host_ids()
  return vim.tbl_keys(self._config_data)
end

function ConfigProvider:add_workspace_config(host_id, ws_config)
  assert(ws_config ~= nil, "Workspace config cannot be nil")
  return self:update_workspace_config(host_id, ws_config)
end

function ConfigProvider:update_workspace_config(host_id, ws_config)
  if ws_config then
    self._config_data[host_id] = vim.tbl_extend("force", self:get_workspace_config(host_id), ws_config)
  else
    self._config_data[host_id] = nil
  end
  self._config_path:write(vim.json.encode(self._config_data), "w")
  return self._config_data[host_id]
end

function ConfigProvider:remove_workspace_config(host_id)
  self:update_workspace_config(host_id, nil)
end

return ConfigProvider
