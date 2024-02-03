local U = {}

---@param host string hostname
---@return string adjusted_string Lua pattern string
function U.adjust_hostname_to_pattern(host)
  local resp = host:gsub("%*", ".*"):gsub("%?", ".?")
  if host:find("[*?]") ~= nil then
    resp = resp:gsub("%.+", ".")
  end
  return resp
end

---@param host_name string Host name
function U.hostname_contains_wildcard(host_name)
  return host_name:find("[*?!]") ~= nil
end

---@param raw_line string? Line string
function U.process_line(raw_line)
  local directive, directive_value = nil, nil

  if raw_line ~= nil then
    -- Remove comments from the line
    local comment_idx = raw_line:find("#", 1, true)

    if comment_idx then
      raw_line = raw_line:sub(1, comment_idx - 1)
    end

    local line_parts = vim.split(raw_line, "%s+", { trimempty = true })

    if #line_parts > 1 then
      directive = line_parts[1]
      directive_value = table.concat(line_parts, " ", 2, #line_parts)
    end
  end

  return directive, directive_value
end

---@param host_name string Host to be checked
---@param host_name_pattern string List of hosts to be checked against
function U.matches_host_name_pattern(host_name, host_name_pattern)
  local start_index = 1
  if vim.startswith(host_name_pattern, "!") then
    start_index = 2
  end

  local search_host = U.adjust_hostname_to_pattern(string.sub(host_name_pattern, start_index))
  local is_match = host_name:match("^" .. U.adjust_hostname_to_pattern(search_host) .. "$") ~= nil
    or search_host:find(host_name) ~= nil

  -- If host_name starts with !, we reverse the condition of match
  if vim.startswith(host_name_pattern, "!") then
    is_match = not is_match
  end

  return is_match
end

return U
