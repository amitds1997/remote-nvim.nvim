---@class remote-nvim.providers.ssh.SSHProvider: remote-nvim.providers.Provider
---@field super remote-nvim.providers.Provider
local SSHProvider = require("remote-nvim.providers.provider"):subclass("SSHProvider")

local Notifier = require("remote-nvim.providers.notifier")
local SSHExecutor = require("remote-nvim.providers.ssh.ssh_executor")

---Initialize SSH provider instance
---@param host string
---@param conn_opts string|table?
function SSHProvider:init(host, conn_opts)
  SSHProvider.super:init(host, conn_opts)

  self.conn_opts = self:_cleanup_conn_options(self.conn_opts)
  self.executor = SSHExecutor(self.host, self.conn_opts)
  self.unique_host_id = self:_get_unique_host_id()
  self.provider_type = "ssh"
  self.notifier = Notifier({
    title = ("Remote Nvim: %s"):format(self.unique_host_id),
  })
end

---Generate host identifer using host and port on host
---@return string host_id Unique identifier created by combining host and port information
function SSHProvider:_get_unique_host_id()
  local port = self.conn_opts:match("-p%s*(%d+)")
  return port ~= nil and ("%s:%s"):format(self.host, port) or self.host
end

---Cleanup SSH options
---@param conn_opts string
---@return string cleaned_conn_opts Cleaned up SSH options
function SSHProvider:_cleanup_conn_options(conn_opts)
  local filtered_conn_opts = vim.tbl_filter(function(elem)
    -- We filter following keywords and patterns
    -- Any empty string, "-N" and hostname as a keyword in the connection options
    return elem ~= self.host and elem ~= "-N" and elem ~= ""
  end, vim.split(conn_opts, "%s", { trimempty = true }))

  -- If the connection options begin with "ssh", remove "ssh"
  if #filtered_conn_opts > 0 and filtered_conn_opts[1] == require("remote-nvim").config.ssh_config.ssh_binary then
    table.remove(filtered_conn_opts, 1)
  end

  return table.concat(filtered_conn_opts, " ")
end

return SSHProvider
