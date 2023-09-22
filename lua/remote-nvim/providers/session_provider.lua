---@class remote-nvim.providers.SessionProvider: remote-nvim.Object
---@field private sessions table<string, remote-nvim.providers.Provider> Map of host and associated session
---@field private remote_workspaces_config remote-nvim.ConfigProvider
local SessionProvider = require("remote-nvim.middleclass")("SessionProvider")

---Initialize session provider
function SessionProvider:init()
  self.sessions = {}
  self.remote_workspaces_config = require("remote-nvim.config")()
end

---Get existing session or create a new session for a given host
---@param type provider_type Provider type
---@param host string
---@param conn_opts string|table Connection opts
---@return remote-nvim.providers.Provider session Session for the host
function SessionProvider:get_or_initialize_session(type, host, conn_opts)
  ---@type remote-nvim.providers.Provider
  local provider
  if type == "ssh" then
    provider = require("remote-nvim.providers.ssh.ssh_provider")(host, conn_opts)
  else
    error("Unknown provider type")
  end
  if self.sessions[provider.unique_host_id] == nil then
    self.sessions[provider.unique_host_id] = provider
  end
  return self.sessions[provider.unique_host_id]
end

---Get all active sessions
---@return table<string, remote-nvim.providers.Provider> sessions
function SessionProvider:get_active_sessions()
  return self.sessions
end

---Provides saved configurations for the given provider type
---@param provider_type string?
---@return table<string, string|table<string, string>>
function SessionProvider:get_saved_host_configs(provider_type)
  return self.remote_workspaces_config:get_workspace_config(nil, provider_type)
end

return SessionProvider
