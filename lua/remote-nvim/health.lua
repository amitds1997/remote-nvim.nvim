local constants = require("remote-nvim.constants")
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")
local utils = require("remote-nvim.utils")
local M = {}

local function verify_binary(binary_name)
  local succ, _ = pcall(utils.find_binary, binary_name)
  if not succ then
    vim.health.warn(("`%s` executable not found. Functionalities might be broken."):format(binary_name))
  else
    vim.health.ok(("`%s` executable found."):format(binary_name))
  end
end

function M.check()
  vim.health.start(constants.PLUGIN_NAME)
  local required_binaries = {
    "curl",
    remote_nvim.config.ssh_config.ssh_binary,
    remote_nvim.config.ssh_config.scp_binary,
    remote_nvim.config.devpod.binary,
  }
  for _, bin_name in ipairs(required_binaries) do
    verify_binary(bin_name)
  end
end

return M
