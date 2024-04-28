local O = {}
local Path = require("plenary.path")
local scandir = require("plenary.scandir")
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

local function get_or_create_path()
  local offline_path = Path:new(remote_nvim.config.offline_mode.cache_dir)
  if not offline_path:exists() then
    offline_path:mkdir({ parents = true, exists_ok = true }) -- Ensure that the path exists
  end

  return offline_path:absolute()
end

---@param os os_type Name of the OS
---@param release_type neovim_install_method Release type to fetch
function O.get_available_neovim_version_files(os, release_type)
  local version_path = get_or_create_path()
  local os_lower = string.lower(os)

  local available_version_files = scandir.scan_dir(version_path, {
    hidden = false,
    add_dirs = false,
    respect_gitignore = false,
    depth = 1,
    search_pattern = function(name)
      if release_type == "source" then
        return string.find(name, "-source", nil, true) ~= nil
      elseif release_type == "binary" then
        return string.find(name, os_lower, nil, true) ~= nil and not vim.endswith(name, ".sha256sum")
      end
    end,
    silent = true,
  })

  local available_version_map = {}
  for _, version_file in ipairs(available_version_files) do
    local res = string.match(version_file, "nvim%-(v[%d%.]+).*")
      or string.match(version_file, "nvim%-(stable).*")
      or string.match(version_file, "nvim%-(nightly)-.*")

    if
      res ~= nil
      and (require("plenary.path"):new({ ("%s.sha256sum"):format(version_file) }):exists() or release_type == "source")
    then
      available_version_map[res] = version_file
    end
  end

  return available_version_map
end

return O
