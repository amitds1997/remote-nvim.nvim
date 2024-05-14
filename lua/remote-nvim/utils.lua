local M = {}
local constants = require("remote-nvim.constants")
M.uv = vim.fn.has("nvim-0.10") and vim.uv or vim.loop
---@type plenary.logger
M.logger = nil

---Is the current system a Windows system or not
M.is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win32unix") == 1
M.path_separator = M.is_windows and "\\" or "/"

function M.get_plugin_version()
  local commit_id = "N/A"
  if
    vim.fn.executable("git") == 1
    and #vim.fs.find(".git", { path = M.get_plugin_root(), type = "directory", limit = 1 }) == 1
  then
    commit_id = vim.split(vim.fn.system("git rev-parse HEAD"), "\n")[1]
  end
  return ("%s (%s)"):format(constants.PLUGIN_VERSION, commit_id)
end

---Get logger
---@return plenary.logger logger Logger instance
function M.get_logger()
  local remote_nvim = require("remote-nvim")

  return M.logger ~= nil and M.logger
    or require("plenary.log").new({
      plugin = constants.PLUGIN_NAME,
      level = remote_nvim.config.log.level,
      use_console = false,
      outfile = remote_nvim.config.log.filepath,
      fmt_msg = function(_, mode_name, src_path, src_line, msg)
        local nameupper = mode_name:upper()
        local lineinfo = vim.fn.fnamemodify(src_path, ":.") .. ":" .. src_line
        return string.format("%-6s%s %s: %s\n", nameupper, os.date(), lineinfo, msg)
      end,
    })
end

---Find if provided binary exists or not
---@param binary string|string[] Name of the binary to search on the runtime path
---@return boolean exists Does the binary exist on the path
function M.find_binary(binary)
  binary = type(binary) == "string" and { binary } or binary
  if vim.fn.executable(binary[1]) == 1 then
    return true
  end
  return false
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
function M.split(inputString, sep)
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
function M.path_join(is_windows, ...)
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
function M.generate_equally_spaced_columns(token_arr, num)
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

---Truncate the plugin log file
function M.truncate_log()
  local remote_nvim = require("remote-nvim")
  local stat = M.uv.fs_stat(remote_nvim.config.log.filepath)
  if stat and stat.size > remote_nvim.config.log.max_size then
    io.open(remote_nvim.config.log.filepath, "w+"):close()
  end
end

---Get OS name of the system
---@return string os_name Name of the OS
function M.os_name()
  local os_name = M.uv.os_uname().sysname

  if os_name == "Darwin" then
    return "macOS"
  end
  return os_name
end

---Get local client's neovim version
---@return string version Local client Neovim version
function M.neovim_version()
  local neovim_version = vim.version()
  local neovim_version_str = ("%d.%d.%d"):format(neovim_version.major, neovim_version.minor, neovim_version.patch)
  if neovim_version.prerelease then
    neovim_version_str = ("%s-%s"):format(neovim_version_str, neovim_version.prerelease)
  end
  return neovim_version_str
end

function M.get_plugin_root()
  return vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h")
end

---Find common parent directory for all passed paths
---@param paths string[] Paths which would be used to calculate common ancestor
---@return string?, string[] paths Common ancestor directory; paths relative to parent directory
function M.find_common_parent(paths)
  if #paths == 0 then
    return "", {}
  end
  local input_paths = {}
  for _, input_path in ipairs(paths) do
    table.insert(input_paths, vim.split(input_path, M.path_separator, { plain = true }))
  end

  if #input_paths == 1 then
    local only_path = input_paths[1]
    return table.concat(only_path, M.path_separator, 1, #only_path - 1), { only_path[#only_path] }
  end

  -- We start with the assumption that entire path match
  local end_index = #input_paths[1]
  local anscestor_path = vim.deepcopy(input_paths[1])

  -- We trim it down to the min matching index
  for _, path in ipairs(vim.list_slice(input_paths, 2)) do
    local idx = 1
    while idx <= #path do
      if idx > end_index or anscestor_path[idx] ~= path[idx] then
        break
      end
      idx = idx + 1
    end
    end_index = math.min(end_index, idx - 1)
  end

  local parent_dir = table.concat(input_paths[1], M.path_separator, 1, end_index)
  local sub_dirs = {}
  for _, path in ipairs(input_paths) do
    table.insert(sub_dirs, table.concat(path, M.path_separator, end_index + 1))
  end

  return parent_dir, sub_dirs
end

---Substitute substring in one string with another
---@param str string String in which substituion should happen
---@param sub_str string String to be substituted
---@param repl string Replacement string
---@param times number? How many times must the repetitions be applied
---@return string res_str String to return
function M.plain_substitute(str, sub_str, repl, times)
  local strMagic = "([%^%$%(%)%%%.%[%]%*%+%-%?])"
  local replaced_str = string.gsub(str:gsub(strMagic, "%%%1"), sub_str:gsub(strMagic, "%%%1"), repl, times or 1)
  return replaced_str
end

---Run cmd async
---@param cmd string Command to run
---@param args string[] Arguments to pass to the command
---@param cb function<string[]>? Callback function
---@return Job cmd_job Job executing the command async
function M.run_cmd(cmd, args, cb)
  local job = require("plenary.job"):new({
    command = cmd,
    args = args,
    enabled_recording = true,
    on_exit = function(self, code)
      if code ~= 0 then
        error(table.concat(self:stderr_result(), "\n"))
      end
      if cb ~= nil then
        cb(self:result())
      end
    end,
  })

  job:start()
  return job
end

return M
