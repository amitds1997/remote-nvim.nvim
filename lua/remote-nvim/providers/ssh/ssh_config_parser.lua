local M = {}

---Parse SSH config file and return parsed config as table
---@param ssh_config_path string File path of the ssh_config
---@param parsed_config table Already parsed config table
---@return table parsed_config Parsed configuration from the file
local function parse_config_file(ssh_config_path, parsed_config)
  local config_path = vim.fn.expand(ssh_config_path)
  parsed_config = parsed_config or {}
  if parsed_config[config_path] then
    return {}
  end
  -- We set it before because the function would fail for invalid config files
  -- and we do not want it to compute further for cyclic imports
  parsed_config[config_path] = true

  -- Start parsing the ssh_config file
  local config = {}
  local current_host = nil

  for line in io.lines(config_path) do
    -- Remove leading whitespaces
    line = line:match("^%s*(.-)%s*$")

    -- Skip comments and empty lines
    if not line:match("^#") and line ~= "" then
      -- Match "Include" directive
      local included_ssh_config = line:match("^Include%s+(.+)")
      if included_ssh_config then
        included_ssh_config = parse_config_file(included_ssh_config, parsed_config)
        for host, options in pairs(included_ssh_config) do
          config[host] = config[host] or {}
          for directive, option in pairs(options) do
            config[host][directive] = option
          end
        end
      else
        -- Match "Host" directive
        local host = line:match("^Host%s(.+)")
        if host then
          current_host = host
          config[current_host] = config[current_host] or {}
          config[current_host]["Config"] = config_path
          config[current_host]["Host"] = host
        else
          -- Match other directives and their options
          local directive, option = line:match("^(%S+)%s+(.+)")
          if directive and option then
            -- Remove double quotes if present
            option = option:gsub('^"(.+)"$', "%1")
            config[current_host][directive] = option
          end
        end
      end
    end
  end
  return config
end

---Parse multiple ssh_config files and generate host configurations (Ignoring wild card entries)
---@param ssh_config_files string[] Path of all the ssh_config files to be considered
---@return table ssh_config Parsed hosts as configuration table
function M.parse_ssh_configs(ssh_config_files)
  local parsed_ssh_config = {}

  for _, ssh_config_file in ipairs(ssh_config_files) do
    parsed_ssh_config = vim.tbl_extend("keep", parsed_ssh_config, parse_config_file(ssh_config_file, {}))
  end

  -- We filter out any regular expression based configurations
  local filtered_ssh_config = {}
  for key, value in pairs(parsed_ssh_config) do
    if key:find("[*?]") == nil then
      filtered_ssh_config[key] = value
    end
  end
  return filtered_ssh_config
end

return M
