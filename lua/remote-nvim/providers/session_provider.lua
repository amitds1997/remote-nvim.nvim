---@class SessionProvider: Object
local SessionProvider = require("remote-nvim.providers.middleclass")("SessionProvider")

function SessionProvider:initialize() end

function SessionProvider:get_or_initialize_session() end

function SessionProvider:get_active_sessions() end

function SessionProvider:get_saved_host_configs() end

return SessionProvider
