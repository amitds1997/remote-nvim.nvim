---@class SessionProvider: Object
local SessionProvider = require("remote-nvim.middleclass")("SessionProvider")

function SessionProvider:initialize()
  self.sessions = {}
  self.remote_workspaces_config = require("remote-nvim.config"):new()
end

function SessionProvider:get_or_initialize_session(type, host, conn_opts)
  ---@type Provider
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

function SessionProvider:get_active_sessions()
  return self.sessions
end

---Provides saved configurations for the given provider type
---@param provider_type? string
function SessionProvider:get_saved_host_configs(provider_type)
  return self.remote_workspaces_config:get_workspace_config(nil, provider_type)
end

return SessionProvider
