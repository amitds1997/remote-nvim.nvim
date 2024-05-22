local constants = require("remote-nvim.constants")
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")
local utils = require("remote-nvim.utils")
local M = {}

function M.check()
  local function check_binary_health(binary_info)
    local binary = binary_info["name"]
    if utils.find_binary(binary) then
      -- TODO: Switch to `vim.system()` when min Neovim version is >= 0.10
      local binary_version = vim.trim(vim.split(vim.fn.system(binary_info.version_cmd), "\n", { trimempty = true })[1])
      vim.health.ok(("%s: `%s`"):format(binary, binary_version))
    else
      local health_fn = binary_info.optional and vim.health.warn or vim.health.error
      health_fn(("`%s` is missing. %s"):format(binary, binary_info.warn_message))
    end
  end

  local binaries = {
    {
      name = "curl",
      version_cmd = "curl --version",
      warn_message = "Core functionalities will be broken",
      optional = false,
    },
    {
      name = "tar",
      version_cmd = "tar --version",
      warn_message = "Core functionalities will be broken",
      optional = true,
    },
    {
      name = remote_nvim.config.ssh_config.ssh_binary,
      version_cmd = ("%s -V"):format(remote_nvim.config.ssh_config.ssh_binary),
      warn_message = "Core functionalities will be broken",
      optional = false,
    },
    {
      name = remote_nvim.config.devpod.binary,
      version_cmd = ("%s version"):format(remote_nvim.config.devpod.binary),
      warn_message = "Docker/Devcontainer functionalities will be broken",
      optional = true,
    },
    {
      name = remote_nvim.config.devpod.docker_binary,
      version_cmd = ("%s --version=true"):format(remote_nvim.config.devpod.docker_binary),
      warn_message = "Docker/Devcontainer functionalities will be broken",
      optional = true,
    },
  }

  vim.health.start(constants.PLUGIN_NAME)
  for _, binary_info in ipairs(binaries) do
    check_binary_health(binary_info)
  end
end

return M
