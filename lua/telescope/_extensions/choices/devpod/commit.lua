---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

local function commit_action(_)
  local git_uri = vim.fn.input("Git URI: ")
  if git_uri == "" then
    return
  end
  git_uri = git_uri:gsub("/$", "")

  local commit = vim.fn.input("Commit: ")
  if commit == "" then
    return
  end

  local uri_components = vim.split(git_uri, "/", { trimempty = true })

  remote_nvim.session_provider
    :get_or_initialize_session({
      host = ("%s@sha256:%s"):format(git_uri, commit),
      provider_type = "devpod",
      devpod_opts = {
        provider = "docker",
        devpod_id = ("%s-%s"):format(uri_components[#uri_components], commit),
      },
    })
    :launch_neovim()
end

return {
  name = "Dev Containers: Open remote commit",
  value = "devpod-remote-commit",
  action = commit_action,
  priority = 50,
  help = [[
## Description

Launch devcontainer project from remote SHA commit.
]],
}
