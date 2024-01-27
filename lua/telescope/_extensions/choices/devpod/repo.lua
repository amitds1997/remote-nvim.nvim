---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

local function repo_action(_)
  local git_uri = vim.fn.input("Git URI: ")
  if git_uri == "" then
    return
  end
  git_uri = git_uri:gsub("/$", "")

  local uri_components = vim.split(git_uri, "/", { trimempty = true })

  remote_nvim.session_provider
    :get_or_initialize_session({
      host = git_uri,
      provider_type = "devpod",
      devpod_opts = {
        provider = "docker",
        devpod_id = ("%s-remote"):format(uri_components[#uri_components]),
      },
    })
    :launch_neovim()
end

return {
  name = "Dev Containers: Open remote repo",
  value = "devpod-remote-repo",
  action = repo_action,
  priority = 60,
  help = [[
## Description

Launch devcontainer project from remote repository. Would be launched on the default branch. If you wish to alter the branch, use 'Dev Containers: Open remote branch'.
]],
}
