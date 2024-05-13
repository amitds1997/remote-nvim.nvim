local devpod_utils = require("remote-nvim.providers.devpod.devpod_utils")
local remote_nvim = require("remote-nvim")

local function devcontainer_action()
  local devcontainer_root_path = devpod_utils.get_devcontainer_root()

  if not devcontainer_root_path then
    error("Not a devcontainer project. Cannot proceed.")
  end

  remote_nvim.session_provider
    :get_or_initialize_session({
      host = devcontainer_root_path,
      provider_type = "devpod",
      devpod_opts = {
        provider = "docker",
        source_opts = {
          type = "devcontainer",
          id = devcontainer_root_path,
        },
      },
      unique_host_id = devpod_utils.get_devcontainer_unique_host(devcontainer_root_path),
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
