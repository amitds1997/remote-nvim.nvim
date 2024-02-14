local constants = require("remote-nvim.constants")
local D = {}

---Handle plugin deprecations
---@param config remote-nvim.config.PluginConfig
---@return remote-nvim.config.PluginConfig up_to_date_config
function D.handle_deprecations(config)
  if config.neovim_user_config_path ~= nil then
    config.remote.copy_dirs.config = {
      base = config.neovim_user_config_path,
      dirs = "*",
    }
    vim.deprecate(
      "neovim_user_config_path to define neovim configuration path",
      "remote.copy_dirs.config in configuration setup",
      "v0.3.0",
      constants.PLUGIN_NAME,
      false
    )
  end

  config.local_client_config = config.local_client_config or {}
  if config.local_client_config.callback ~= nil then
    config.client_callback = config.local_client_config.callback
    vim.deprecate(
      "local_client_config.client_callback to define callback",
      "client_callback key in setup",
      "v0.3.0",
      constants.PLUGIN_NAME,
      false
    )
  end
  return config
end

return D
