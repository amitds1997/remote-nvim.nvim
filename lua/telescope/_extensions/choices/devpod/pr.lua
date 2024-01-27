---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

local function pr_action(_)
  local git_uri = vim.fn.input("Git URI: ")
  if git_uri == "" then
    return
  end
  git_uri = git_uri:gsub("/$", "")

  local pr_number = vim.fn.input("PR Number: ")
  if pr_number == "" then
    return
  end

  local uri_components = vim.split(git_uri, "/", { trimempty = true })

  remote_nvim.session_provider
    :get_or_initialize_session({
      host = ("%s@pull/%s/head"):format(git_uri, pr_number),
      provider_type = "devpod",
      devpod_opts = {
        provider = "docker",
        devpod_id = ("%s-pr-%s"):format(uri_components[#uri_components], pr_number),
      },
    })
    :launch_neovim()
end

return {
  name = "Dev Containers: Open remote PR",
  value = "devpod-remote-pr",
  action = pr_action,
  priority = 45,
  help = [[
## Description

Launch devcontainer project from remote PR.
]],
}
