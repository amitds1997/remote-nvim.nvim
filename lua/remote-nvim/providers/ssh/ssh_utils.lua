local M = {}

---Append TTY data to provided buffer
---@param data_bufr string[] Buffer in which data is to be appended
---@param tty_data string[] TTY data to be appended into the string
---@return string[] updated_bufr Updated buffer with the tty data appended
function M.append_tty_data_to_buffer(data_bufr, tty_data)
  for _, tty_datum in ipairs(tty_data) do
    local cleaned_datum = tty_datum:gsub("\r", "\n")
    table.insert(data_bufr, cleaned_datum)
  end
  return data_bufr
end

---Generate host identifer using host and port on host
---@param host string Host name to be connected to
---@param conn_opts string Connection options required for connecting to host
---@return string host_identifier Unique identifier created by combining host and port information
function M.get_host_identifier(host, conn_opts)
  local host_identifier = host
  if conn_opts ~= nil then
    local port = conn_opts:match("-p%s*(%d+)")
    if port ~= nil then
      host_identifier = host_identifier .. ":" .. port
    end
  end
  return host_identifier
end

---Clean up connection options
---@param host string Host name for which the connection strings are provided
---@param conn_opts string Connection options to be cleaned up
---@return string cleaned_conn_opts Cleaned up connection option
---@return number? count Count of replacements
function M.clean_up_conn_opts(host, conn_opts)
  return conn_opts
    :gsub("^%s*ssh%s*", "") -- Remove "ssh" prefix if it exists
    :gsub(host:gsub("([^%w])", "%%%1"), "") -- Remove hostname from connection string
    :gsub("%-N", "") -- "-N" restrics command execution so we do not do it
    :gsub("%s+", " ") -- Replace multiple whitespaces by a single one
    :gsub("^%s+", "") -- Remove leading whitespaces
    :gsub("%s+$", "") -- Remove trailing whitespaces
end

return M
