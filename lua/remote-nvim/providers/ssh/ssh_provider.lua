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
  local host_expression = self.host:gsub("([^%w])", "%%%1")
  return vim.trim(
    conn_opts
      :gsub("^%s*ssh%s*", "") -- Remove "ssh" prefix if it exists
      :gsub("%s+", " ") -- Replace multiple whitespaces by a single one
      :gsub(host_expression .. " ", " ") -- Remove hostname from connection string
      :gsub("%-N", "") -- "-N" restrics command execution so we do not do it
  )
end

return SSHProvider
