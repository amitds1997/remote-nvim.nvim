local devpod_helper = require("remote-nvim.providers.devpod.devpod_helper")

local function devcontainer_action()
  local devcontainer_root_path = devpod_helper.get_devcontainer_root()

  if not devcontainer_root_path then
    error("Not a devcontainer project. Cannot proceed.")
  end
  devpod_helper.launch_devcontainer(devcontainer_root_path)
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
