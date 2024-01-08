---@class remote-nvim.providers.devpod.DevpodProvider: remote-nvim.providers.Provider
---@field super remote-nvim.providers.Provider
---@field binary string Devpod binary name
---@field ssh_provider remote-nvim.providers.ssh.SSHProvider? SSH Provider to work with the created SSH configuration
---@field _up_default_opts string[] Default arguments for bringing up the workspace
local DevpodProvider = require("remote-nvim.providers.provider"):subclass("DevpodProvider")
local Notifier = require("remote-nvim.providers.notifier")

local SSHProvider = require("remote-nvim.providers.ssh.ssh_provider")
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

function DevpodProvider:init(_, opts)
  DevpodProvider.super:init("localhost")

  self.binary = remote_nvim.config.devpod.binary
  self.ssh_config_path = remote_nvim.config.devpod.ssh_config_path

  self._up_default_opts = {
    "--open-ide=false",
    "--configure-ssh=true",
    "--ide=none",
    "--log-output=raw",
    ("--ssh-config=%s"):format(self.ssh_config_path),
  }
  self.launch_opts = vim.list_extend(self._up_default_opts, opts.launch_opts or {})
  self.provider_type = "devpod"
  self.ssh_provider = nil
  self._remote_working_dir = opts.working_dir
  self.notifier = Notifier({
    title = "Devpod",
  })
end

function DevpodProvider:launch_neovim()
  self:_run_code_in_coroutine(function()
    self:run_command(
      ("%s up %s"):format(self.binary, table.concat(self.launch_opts, " ")),
      "Setting up devcontainer workspace"
    )
    self.notifier:notify("Devcontainer workspace created", vim.log.levels.INFO, true)
    local jout = self.executor:job_stdout()
    local ssh_host = vim.split(vim.split(jout[#jout], "'")[2], " ")[2]
    self.ssh_provider = SSHProvider(ssh_host, { "-F", self.ssh_config_path })
    self.ssh_provider._remote_working_dir = self._remote_working_dir
    self.ssh_provider:_launch_neovim()
  end)
end

return DevpodProvider
