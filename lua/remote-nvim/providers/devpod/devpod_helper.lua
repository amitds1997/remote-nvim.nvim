local nio = require("nio")
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")
local devpod_binary = remote_nvim.config.devpod.binary

local M = {}

---@class remote-nvim.providers.devpod.DevpodOpts
---@field source string? What is the source for the current workspace
---@field working_dir string? Working directory to set when launching the client
---@field provider string? Name of the devpod provider

---Get correctly initialized devpod provider instance
---@param opts remote-nvim.providers.ProviderOpts Options to pass to the DevpodProvider
---@return remote-nvim.providers.devpod.DevpodProvider
function M.get_devpod_provider(opts)
  local DevpodProvider = require("remote-nvim.providers.devpod.devpod_provider")
  opts = opts or {}
  opts.conn_opts = opts.conn_opts or {}
  opts.devpod_opts = opts.devpod_opts or {}

  if opts.devpod_opts.provider then
    local provider_list = nio.process.run({
      cmd = devpod_binary,
      args = { "provider", "list", "--output", "json" },
    })
    local provider_output = vim.json.decode(provider_list and provider_list.stdout.read() or "{}")
    -- If the provider does not exist, let's create it
    if not vim.tbl_contains(vim.tbl_keys(provider_output), opts.devpod_opts.provider) then
      nio.process.run({
        cmd = devpod_binary,
        args = { "provider", "add", opts.devpod_opts.provider },
      })
    end

    table.insert(opts.conn_opts, ("--provider=%s"):format(opts.devpod_opts.provider))
  end

  if opts.unique_host_id then
    local id = string.lower(opts.unique_host_id)
    opts.unique_host_id = id:gsub("[^a-z0-9]+", "-"):sub(1, 48)
  end

  if remote_nvim.config.devpod.dotfiles then
    table.insert(opts.conn_opts, ("--dotfiles=%s"):format(remote_nvim.config.devpod.dotfiles))
  end

  if remote_nvim.config.devpod.gpg_agent_forwarding then
    table.insert(opts.conn_opts, "--gpg-agent-forwarding")
  end

  opts.devpod_opts.source = opts.devpod_opts.source or opts.host

  return DevpodProvider(opts)
end

---@return string|nil
function M.get_devcontainer_root()
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
function M.launch_devcontainer(devc_root)
  local unique_host_id = devc_root:sub(-48)
  local sep_idx = unique_host_id:find(require("remote-nvim.utils").path_separator, nil, true)
  if sep_idx then
    unique_host_id = unique_host_id:sub(sep_idx + 1)
  end

  remote_nvim.session_provider
    :get_or_initialize_session({
      host = devc_root,
      provider_type = "devpod",
      devpod_opts = {
        provider = "docker",
      },
      unique_host_id = unique_host_id,
    })
    :launch_neovim()
end

return M
