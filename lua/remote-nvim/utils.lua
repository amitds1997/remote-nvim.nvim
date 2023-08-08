local M = {}

---Name of the plugin
M.PLUGIN_NAME = "remote-nvim.nvim"
---Minimum Neovim version for the plugin
M.MIN_NEOVIM_VERSION = "v0.8.0"
---Log level
M.LOG_LEVEL = vim.fn.getenv("REMOTE_NVIM_LOG_LEVEL")
if M.LOG_LEVEL == vim.NIL then
  M.LOG_LEVEL = "info"
end

---Is the current system a Windows system or not
M.is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win32unix") == 1

M.logger = require("plenary.log").new({
  plugin = M.PLUGIN_NAME,
  level = M.LOG_LEVEL,
  use_console = false,
  outfile = string.format("%s/%s.log", vim.api.nvim_call_function("stdpath", { "cache" }), M.PLUGIN_NAME),
})

---Find if provided binary exists or not
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

---Get the root path of the plugin
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

---Generate a random string of given length
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

---Get an ephemeral free port on the local machine
---@return string port A free ephemeral port available for TCP connections
function M.find_free_port()
  local socket = vim.loop.new_tcp()

  socket:bind("127.0.0.1", 0)
  local result = socket.getsockname(socket)
  socket:close()

  if not result then
    error("Failed to find a free port")
  end

  return tostring(result["port"])
end

---Generate an identifier for a host given name and connection options
---@param host string Host name to be connected to
---@param conn_options string Connection options required for connecting to host
---@return string host_identifier Unique identifier created by combining host and port information
function M.get_host_identifier(host, conn_options)
  local host_config_identifier = host
  if conn_options ~= nil then
    local port = conn_options:match("-p%s*(%d+)")
    if port ~= nil then
      host_config_identifier = host_config_identifier .. ":" .. port
    end
  end
  return host_config_identifier
end

---Split string into a table of strings using a separator.
---Credits: https://github.com/nvim-neo-tree/neo-tree.nvim/blob/main/lua/neo-tree/utils.lua#L776-L789
---@param inputString string The string to split.
---@param is_windows boolean Is the remote systems a windows machine
---@return table table A table of strings.
M.split = function(inputString, is_windows)
  local sep = is_windows and "\\" or "/"
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
      local arg_parts = M.split(arg, is_windows)
      vim.list_extend(all_parts, arg_parts)
    end
  end
  return table.concat(all_parts, path_separator)
end

---Get Neovim versions that satisfy the minimum neovim version constraint
M.get_neovim_versions = function()
  local res = require("plenary.curl").get("https://api.github.com/repos/neovim/neovim/releases", {
    headers = {
      accept = "application/vnd.github+json",
    },
  })

  local available_versions = { "stable" }
  ---@diagnostic disable-next-line: param-type-mismatch
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

---Run code in a coroutine
---@param fn function Function to run inside the coroutine
---@param err_fn? function Error handling function
M.run_code_in_coroutine = function(fn, err_fn)
  local co = coroutine.create(fn)
  local success, err = coroutine.resume(co)
  if not success then
    if err_fn ~= nil then
      err_fn(err)
    else
      error("Coroutine failed with error " .. err)
    end
  end
end

M.generate_equally_spaced_columns = function(token_arr, num)
  -- Create lists for the grouped elements
  local col_grouped_list = {}

  for i = 1, num do
    col_grouped_list[i] = {}
  end

  -- Fill the grouped lists
  for i, value in ipairs(token_arr) do
    local groupIndex = (i - 1) % num + 1
    table.insert(col_grouped_list[groupIndex], value)
  end

  --Calculate the size of each column
  local col_widths = {}
  for _, col in ipairs(col_grouped_list) do
    local max_width = 0
    for _, item in ipairs(col) do
      local item_width = #tostring(item)
      max_width = math.max(max_width, item_width)
    end
    table.insert(col_widths, max_width)
  end

  -- Generate formatted lines with proper spacing
  local formatted_lines = {}
  for i = 1, math.ceil(#token_arr / num) do
    local formatted_row = ""
    for j = 1, num do
      local index = (i - 1) * num + j
      if index <= #token_arr then
        local item_str = tostring(token_arr[index])
        local padding = col_widths[j] - #item_str
        formatted_row = formatted_row .. item_str .. string.rep(" ", padding) .. "    "
      else
        formatted_row = formatted_row .. string.rep(" ", col_widths[j] + 4)
      end
    end
    table.insert(formatted_lines, formatted_row)
  end

  return formatted_lines
end

return M
