local utils = require("remote-nvim.utils")
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

local M = {}

---@param workspace_data remote-nvim.providers.WorkspaceConfig
---@return remote-nvim.providers.devpod.DevpodOpts?  devpod_opts
function M.get_workspace_devpod_opts(workspace_data)
  local devpod_opts = {}
  if workspace_data.devpod_source_opts ~= nil then
    devpod_opts["source_opts"] = workspace_data.devpod_source_opts
  end
  return devpod_opts
end

---Get correctly initialized devpod provider options
---@param opts remote-nvim.providers.ProviderOpts Options to pass to the DevpodProvider
function M.get_devpod_provider_opts(opts)
  opts = opts or {}
  opts.conn_opts = opts.conn_opts or {}
  opts.devpod_opts = opts.devpod_opts or {}
  opts.devpod_opts.source = opts.devpod_opts.source or opts.host

  if opts.unique_host_id then
    local id = string.lower(opts.unique_host_id)
    opts.unique_host_id = id:gsub("[^a-z0-9]+", "-"):sub(1, 48)
    if opts.unique_host_id:sub(-1) == "-" then
      opts.unique_host_id = opts.unique_host_id:sub(1, -2)
    end
  end

  if remote_nvim.config.devpod.dotfiles ~= nil then
    if remote_nvim.config.devpod.dotfiles.path ~= nil then
      table.insert(opts.conn_opts, ("--dotfiles=%s"):format(remote_nvim.config.devpod.dotfiles.path))

      if remote_nvim.config.devpod.dotfiles.install_script ~= nil then
        table.insert(opts.conn_opts, ("--dotfiles-script=%s"):format(remote_nvim.config.devpod.dotfiles.install_script))
      end
    end
  end

  if remote_nvim.config.devpod.gpg_agent_forwarding then
    table.insert(opts.conn_opts, "--gpg-agent-forwarding")
  end

  if opts.devpod_opts.provider then
    table.insert(opts.conn_opts, ("--provider=%s"):format(opts.devpod_opts.provider))
  end

  return opts
end

---@return string|nil
function M.get_devcontainer_root()
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
        return get_nth_parent(path, #file_path):absolute()
      end
    elseif search_style == "recurse_up" then
      local path = Path:find_upwards(file_name)
      if path ~= "" then
        return get_nth_parent(path, #file_path):absolute()
      end
    end
  end
  return nil
end

---@param devc_root string Path to devcontainer directory containing path
function M.get_devcontainer_unique_host(devc_root)
  if devc_root:sub(-1) == "/" then
    devc_root = devc_root:sub(1, -2)
  end

  local unique_host_id = devc_root:sub(-48)
  local sep_idx = unique_host_id:find(utils.path_separator, nil, true)
  if sep_idx then
    unique_host_id = unique_host_id:sub(sep_idx + 1)
  end

  return unique_host_id
end

return M
