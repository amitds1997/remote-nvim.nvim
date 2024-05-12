---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")
local ps = require("remote-nvim.utils").plain_substitute

local function image_action(_)
  local image = vim.fn.input("Image: ")
  if image == "" then
    return
  end
  remote_nvim.session_provider
    :get_or_initialize_session({
      host = image,
      provider_type = "devpod",
      unique_host_id = ps(image, ":", "-"),
      devpod_opts = {
        provider = "docker",
        source_opts = {
          type = "image",
          id = image,
        },
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
