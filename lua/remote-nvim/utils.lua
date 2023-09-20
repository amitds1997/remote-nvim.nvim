local M = {}
local constants = require("remote-nvim.constants")

---Is the current system a Windows system or not
M.is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win32unix") == 1

---Get logger
function M.get_logger()
  local remote_nvim = require("remote-nvim")

  return require("plenary.log").new({
    plugin = constants.PLUGIN_NAME,
    level = remote_nvim.config.log.level,
    use_console = false,
    outfile = remote_nvim.config.log.filepath,
  })
end

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
  return vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h")
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

---Split string into a table of strings using a separator.
---Credits: https://github.com/nvim-neo-tree/neo-tree.nvim/blob/main/lua/neo-tree/utils.lua#L776-L789
---@param inputString string The string to split.
---@param sep string Separator by which to split the string
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

---Convert list into equally spaced columns of given number ready to be printed
---@param token_arr string[] List containing the string tokens
---@param num number Number of columns to be created
---@return string[] spaced_arr Formatted list containing the formatted string tokens
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
