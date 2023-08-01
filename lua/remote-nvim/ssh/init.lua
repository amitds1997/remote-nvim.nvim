local config_parse = require("remote-nvim.ssh.parse")

local M = {}
local hosts, ssh_configs

M.list_hosts = function()
  return hosts
end

M.reload = function()
  hosts = config_parse.parse_ssh_configs(ssh_configs)
end

M.setup = function(opts)
  ssh_configs = opts.ssh_config_files
  hosts = config_parse.parse_ssh_configs(ssh_configs)
end

return M
