---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

local function image_action(_)
  local image = vim.fn.input("Image: ")
  if image == "" then
    return
  end
  remote_nvim.session_provider
    :get_or_initialize_session({
      host = image,
      provider_type = "devpod",
      devpod = {
        provider = "docker",
      },
    })
    :launch_neovim()
end

return {
  name = "Remote Docker: Launch docker image",
  value = "remote-docker-launch-image",
  action = image_action,
  priority = 75,
  help = [[
## Description

Create workspace from an available image. Can choose from existing images already available or can also specify a remote image that can be pulled and launched.
]],
}
