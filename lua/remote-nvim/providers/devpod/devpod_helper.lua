---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")
local devpod_binary = remote_nvim.config.devpod.binary

local M = {}

---@class remote-nvim.providers.devpod.DevpodOpts
---@field working_dir string? Working directory to set when launching the client
---@field provider string? Name of the devpod provider
---@field devpod_id? string

---Get correctly initialized devpod provider instance
---@param opts remote-nvim.providers.ProviderOpts Options to pass to the DevpodProvider
---@return remote-nvim.providers.devpod.DevpodProvider
function M.get_devpod_provider(opts)
  local DevpodProvider = require("remote-nvim.providers.devpod.devpod_provider")
  opts = opts or {}
  opts.conn_opts = opts.conn_opts or {}

  if opts.devpod_opts.provider then
    -- If the provider does not exist, let's create it
    local provider_output = vim.json.decode(vim.fn.system(("%s provider list --output json"):format(devpod_binary)))
    if not require("remote-nvim.utils").contains(vim.tbl_keys(provider_output), opts.devpod_opts.provider) then
      vim.fn.system(("%s provider add %s"):format(devpod_binary, opts.devpod_opts.provider))
    end

    table.insert(opts.conn_opts, ("--provider=%s"):format(opts.devpod_opts.provider))
  end

  if opts.devpod_opts.devpod_id then
    local id = string.lower(opts.devpod_opts.devpod_id)
    id = id:gsub("[^a-z0-9]+", "-"):sub(1, 48)
    table.insert(opts.conn_opts, ("--id %s"):format(id))
  end

  if remote_nvim.config.devpod.dotfiles then
    table.insert(opts.conn_opts, ("--dotfiles=%s"):format(remote_nvim.config.devpod.dotfiles))
  end

  if remote_nvim.config.devpod.gpg_agent_forwarding then
    table.insert(opts.conn_opts, "--gpg-agent-forwarding")
  end

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

return M
