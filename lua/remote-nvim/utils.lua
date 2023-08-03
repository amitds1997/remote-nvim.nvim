local M = {}

-- Name of the plugin
M.PLUGIN_NAME = "remote-nvim.nvim"
M.MIN_NEOVIM_VERSION = "v0.8.0"

---Is the current system a Windows system or not
M.is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win32unix") == 1

---@param binary string|string[] Name of the binary to search on the runtime path
---@return string binary Returns back the binary; error if not found
function M.find_binary(binary)
  if type(binary) == "string" and vim.fn.executable(binary) == 1 then
    return binary
  elseif type(binary) == "table" and vim.fn.executable(binary[1]) then
    return binary[1]
  end
  error("Binary " .. binary .. " not found.")
end

---@return string root_dir Returns the path to the plugin's root
function M.get_package_root()
  local root_dir
  for dir in vim.fs.parents(debug.getinfo(1).source:sub(2)) do
    if vim.fn.isdirectory(M.path_join(M.is_windows, dir, "lua", "remote-nvim")) == 1 then
      root_dir = dir
    end
  end
  return root_dir
end

---@param length integer Length of the string to be generated
---@return string random_string Random string of the given length
function M.generate_random_string(length)
  local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  math.randomseed(os.time()) -- Seed the random number generator with the current time
  local random_string = ""

  for _ = 1, length do
    local rand_index = math.random(1, #charset)
    random_string = random_string .. string.sub(charset, rand_index, rand_index)
  end

  return random_string
end

---@return integer|nil port A free ephemeral port available for TCP connections
function M.find_free_port()
  local socket = vim.loop.new_tcp()

  socket:bind("127.0.0.1", 0)
  local result = socket.getsockname(socket)
  socket:close()

  if not result then
    error("Failed to find a free port")
  end

  return result["port"]
end

---@param ssh_host string Host name to be connected to
---@param ssh_options string Connection options required for connecting to host
---@return string host_identifier Unique identifier created by combining host and port information
function M.get_host_identifier(ssh_host, ssh_options)
  local host_config_identifier = ssh_host
  if ssh_options ~= nil then
    local port = ssh_options:match("-p%s*(%d+)")
    if port ~= nil then
      host_config_identifier = host_config_identifier .. ":" .. port
    end
  end
  return host_config_identifier
end

---Split string into a table of strings using a separator.
---Credits: https://github.com/nvim-neo-tree/neo-tree.nvim/blob/main/lua/neo-tree/utils.lua#L776-L789
---@param inputString string The string to split.
---@param sep string The separator to use.
---@return table table A table of strings.
M.split = function(inputString, sep)
  local fields = {}

  local pattern = string.format("([^%s]+)", sep)
  local _ = string.gsub(inputString, pattern, function(c)
    fields[#fields + 1] = c
  end)

  return fields
end

---Joins arbitrary number of paths together.
---Credits: https://github.com/nvim-neo-tree/neo-tree.nvim/blob/main/lua/neo-tree/utils.lua#L817-L840
---@param is_windows boolean Are the paths on a Windows machine
---@param ... string The paths to join.
---@return string
M.path_join = function(is_windows, ...)
  local path_separator = is_windows and "\\" or "/"
  local args = { ... }
  if #args == 0 then
    return ""
  end

  local all_parts = {}
  if type(args[1]) == "string" and args[1]:sub(1, 1) == path_separator then
    all_parts[1] = ""
  end

  for _, arg in ipairs(args) do
    if arg == "" and #all_parts == 0 and not is_windows then
      all_parts = { "" }
    else
      local arg_parts = M.split(arg, path_separator)
      vim.list_extend(all_parts, arg_parts)
    end
  end
  return table.concat(all_parts, path_separator)
end

M.get_neovim_versions = function()
  local res = require("plenary.curl").get("https://api.github.com/repos/neovim/neovim/releases", {
    headers = {
      accept = "application/vnd.github+json",
    },
  })
  local available_versions = { "stable" }
  for _, version_info in ipairs(vim.fn.json_decode(res.body)) do
    local version = version_info["tag_name"]

    if version ~= "stable" and version ~= "nightly" then
      local major, minor, patch = version:match("v(%d+)%.(%d+)%.(%d+)")
      local target_major, target_minor, target_patch = M.MIN_NEOVIM_VERSION:match("v(%d+)%.(%d+)%.(%d+)")

      major = tonumber(major)
      minor = tonumber(minor)
      patch = tonumber(patch)

      target_major = tonumber(target_major)
      target_minor = tonumber(target_minor)
      target_patch = tonumber(target_patch)

      if
        major > target_major
        or (major == target_major and minor > target_minor)
        or (major == target_major and minor == target_minor and patch >= target_patch)
      then
        table.insert(available_versions, version)
      end
    end
  end
  table.insert(available_versions, "nightly")
  return available_versions
end

--- Get async input from the user
---@param choices string[] Options to be presented to the user
---@param input_opts table Input options, same as one given to @see vim.ui.select
---@param cb function Callback to call once choice has been made
M.get_user_selection = function(choices, input_opts, cb)
  local co = coroutine.running()
  vim.ui.select(choices, input_opts, function(choice)
    if choice == nil then
      return
    end
    cb(choice)
    if co then
      coroutine.resume(co)
    end
  end)
  if co then
    coroutine.yield()
  end
end

return M
