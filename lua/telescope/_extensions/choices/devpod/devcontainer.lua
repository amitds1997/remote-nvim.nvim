---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

local function devcontainer_action(_)
  local devcontainer_root_path = require("remote-nvim.providers.devpod.devpod_helper").get_devcontainer_root()

  if not devcontainer_root_path then
    error("Not a devcontainer project. Cannot proceed.")
  end

  remote_nvim.session_provider
    :get_or_initialize_session({
      host = devcontainer_root_path,
      provider_type = "devpod",
      devpod_opts = {
        provider = "docker",
      },
    })
    :launch_neovim()
end

return {
  name = "Dev Containers: Launch current project in devcontainer",
  value = "devpod-launch-devcontainer",
  action = devcontainer_action,
  priority = 100,
  help = [[
## Description

Launch current project in a devcontainer.
]],
}
