local constants = require("remote-nvim.constants")
local utils = require("remote-nvim.utils")
local M = {}

local function verify_binary(binary_name)
  local succ, _ = pcall(utils.find_binary, binary_name)
  if not succ then
    vim.health.report_warn(("`%s` executable not found. Setup would not work."):format(binary_name))
  else
    vim.health.ok(("`%s` executable found."):format(binary_name))
  end
end

function M.check()
  vim.health.start(constants.PLUGIN_NAME)
  local required_binaries = {
    "curl",
    constants.config.ssh_config.ssh_binary,
    constants.config.ssh_config.scp_binary,
  }
  for _, bin_name in ipairs(required_binaries) do
    verify_binary(bin_name)
  end
end

return M
