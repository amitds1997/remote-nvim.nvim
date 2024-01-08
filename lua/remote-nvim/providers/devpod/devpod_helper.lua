---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")
local devpod_binary = remote_nvim.config.devpod.binary

---Get correctly initialized devpod provider instance
---@param launch_opts table Options to pass to the DevpodProvider
---@param working_dir string? Working directory to set when launching the client
---@param provider string? Name of the devpod provider
---@return remote-nvim.providers.devpod.DevpodProvider
local function get_devpod_provider(launch_opts, working_dir, provider)
  local DevpodProvider = require("remote-nvim.providers.devpod.devpod_provider")

  if provider then
    -- If the provider does not exist, let's create it
    local provider_output = vim.json.decode(vim.fn.system(("%s provider list --output json"):format(devpod_binary)))
    if not require("remote-nvim.utils").contains(vim.tbl_keys(provider_output), provider) then
      vim.fn.system(("%s provider add %s"):format(devpod_binary, provider))
    end

    table.insert(launch_opts, ("--provider=%s"):format(provider))
  end

  if remote_nvim.config.devpod.dotfiles then
    table.insert(launch_opts, ("--dotfiles=%s"):format(remote_nvim.config.devpod.dotfiles))
  end

  if remote_nvim.config.devpod.gpg_agent_forwarding then
    table.insert(launch_opts, "--gpg-agent-forwarding")
  end

  local opts = { launch_opts = launch_opts }
  if working_dir then
    opts.working_dir = working_dir
  end

  return DevpodProvider(nil, opts)
end

return {
  launch_devcontainer = function(path)
    return get_devpod_provider({ path }, nil, "docker")
  end,
  launch_image = function(image)
    return get_devpod_provider({ image }, nil, "docker")
  end,
  launch_container = function(container_id)
    local source = ("container:%s"):format(container_id)
    local name, working_dir = unpack(
      vim.split(
        vim.fn.system(
          ("docker inspect --type container %s -f '{{ .Name }} {{ .Config.WorkingDir }}'"):format(container_id)
        ),
        "%s+"
      )
    )
    name = name:gsub("^/", "")
    return get_devpod_provider({ name, "--source", source }, working_dir, "docker")
  end,
  launch_devpod_workspace = function(workspace)
    return get_devpod_provider({ workspace })
  end,
  is_devcontainer_dir = function()
    local utils = require("remote-nvim.utils")
    local search_style = remote_nvim.config.devpod.search_style
    local Path = require("plenary.path"):new(".")
    local possible_files = { { ".devcontainer.json" }, { ".devcontainer", "devcontainer.json" } }

    local function get_nth_parent(path, len)
      for _ = 1, len do
        path = path:parent()
      end
      return path
    end

    for _, file_path in ipairs(possible_files) do
      local file_name = utils.path_join(utils.is_windows, unpack(file_path))
      if search_style == "current_dir_only" then
        local path = Path:joinpath(file_name)
        if path:exists() then
          return true, get_nth_parent(path, #file_path):absolute()
        end
      elseif search_style == "recurse_up" then
        local path = Path:find_upwards(file_name)
        if path ~= "" then
          return true, get_nth_parent(path, #file_path):absolute()
        end
      end
    end
    return false, nil
  end,
}
