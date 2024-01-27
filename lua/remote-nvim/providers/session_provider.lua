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
---@param opts remote-nvim.providers.ProviderOpts
---@return remote-nvim.providers.Provider session Session for the host
function SessionProvider:get_or_initialize_session(opts)
  ---@type remote-nvim.providers.Provider
  local provider

  opts.conn_opts = opts.conn_opts or {}
  opts.devpod_opts = opts.devpod_opts or {}
  opts.progress_view = require("remote-nvim.ui.progressview")()

  if opts.provider_type == "ssh" then
    provider = require("remote-nvim.providers.ssh.ssh_provider")(opts)
  elseif opts.provider_type == "devpod" then
    provider = require("remote-nvim.providers.devpod.devpod_helper").get_devpod_provider(opts)
  else
    error("Unknown provider type")
  end

  local host_id = provider:get_unique_host_id()
  if self.sessions[host_id] == nil then
    self.sessions[host_id] = provider
  end

  return self.sessions[host_id]
end

function SessionProvider:get_session(host_id)
  return self.sessions[host_id]
end

---Get all sessions
---@return table<string, remote-nvim.providers.Provider> sessions
function SessionProvider:get_all_sessions()
  return self.sessions
end

---Get config provider
---@return remote-nvim.ConfigProvider
function SessionProvider:get_config_provider()
  return self.remote_workspaces_config
end

---Provides saved configurations for the given provider type
---@param provider_type provider_type?
---@return table<string, remote-nvim.providers.WorkspaceConfig>
function SessionProvider:get_saved_host_configs(provider_type)
  return self.remote_workspaces_config:get_workspace_config(nil, provider_type)
end

return SessionProvider
