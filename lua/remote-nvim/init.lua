local RemoteHostWorkspaceConfig = require("remote-nvim.config")
local util = require("remote-nvim.utils")
local M = {}

M.version = "0.0.1" -- x-release-please-version

---@class RemoteNeovimConfig
---@field ssh_config RemoteNeovimSSHConfig
---@field neovim_install_script_path string Local path where neovim installation script is stored
---@field remote_neovim_install_home string Where should remote neovim install and save configurations on the remote server
---@field neovim_user_config_path string Local path where the neovim configuration to be copied over to the remote
--server is stored. This is assumed to be a directory and entire directory would be copied over
---@field local_client_config LocalClientConfig Configuration for the local client

---@alias prompt_type "plain"|"secret"
---@alias prompt_value_type "static"|"dynamic"

---@class LocalClientConfig
---@field callback function<string, WorkspaceConfig> Function that would be called upon to start a Neovim client if not nil
---@field default_client_config FloatWindowOpts Configuration to be applied to the default client that would be launched
--if callback is nil

---@class RemoteNeovimSSHPrompts
---@field match string Text that input should be matched against to identify need for stdin
---@field type prompt_type Is the input to be provided a secret?
---@field input_prompt string What should be shown as input prompt when requesting user for input
---@field value_type prompt_value_type Is the prompt value going to remain same throughout a session, if yes, it can be cached
---@field value string Default value to fill in for the prompt, if any

---@class RemoteNeovimSSHConfig
---@field ssh_binary string Name of binary on runtime path for ssh
---@field scp_binary string Name of binary on runtime path for scp
---@field ssh_config_file_paths string[] Location of SSH configuration files that you want the plugin to consider
---@field ssh_prompts RemoteNeovimSSHPrompts[] List of SSH prompts that should be considered for input

---@type RemoteNeovimConfig
M.default_opts = {
  ssh_config = {
    ssh_binary = "ssh",
    scp_binary = "scp",
    ssh_config_file_paths = { "$HOME/.ssh/config" },
    ssh_prompts = {
      {
        match = "password:",
        type = "secret",
        input_prompt = "Enter password: ",
        value_type = "static",
        value = "",
      },
      {
        match = "continue connecting (yes/no/[fingerprint])?",
        type = "plain",
        input_prompt = "Do you want to continue connection (yes/no)? ",
        value_type = "static",
        value = "",
      },
    },
  },
  neovim_install_script_path = util.path_join(util.is_windows, util.get_package_root(), "scripts", "neovim_install.sh"),
  remote_neovim_install_home = util.path_join(util.is_windows, "~", ".remote-nvim"),
  neovim_user_config_path = vim.fn.stdpath("config"),
  local_client_config = {
    callback = nil,
    default_client_config = {
      col_percent = 0.9,
      row_percent = 0.9,
      win_opts = {
        winblend = 5,
      },
      border_opts = {
        topleft = "╭",
        topright = "╮",
        top = "─",
        left = "│",
        right = "│",
        botleft = "╰",
        botright = "╯",
        bot = "─",
      },
    },
  },
}

---Setup for the plugin
---@param opts RemoteNeovimConfig User configuration parameters for the plugin
---@return nil
M.setup = function(opts)
  if vim.fn.has("nvim-0.8.0") ~= 1 then
    return vim.notify("remote-nvim.nvim requires Neovim >= 0.8.0", vim.log.levels.ERROR, { title = "remote-nvim.nvim" })
  end
  M.config = vim.tbl_deep_extend("force", M.default_opts, opts or {})
  M.config.ssh_config.ssh_binary = util.find_binary(M.config.ssh_config.ssh_binary)
  M.config.ssh_config.scp_binary = util.find_binary(M.config.ssh_config.scp_binary)

  M.host_workspace_config = RemoteHostWorkspaceConfig:new()
  ---@type table<string,NeovimSSHProvider>
  M.sessions = {}

  require("remote-nvim.command")
end

return M
