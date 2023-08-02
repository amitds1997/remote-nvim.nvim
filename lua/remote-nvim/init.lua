local RemoteHostWorkspaceConfig = require("remote-nvim.config")
local util = require("remote-nvim.utils")
local M = {}

---@class RemoteNeovimConfig
---@field ssh_config RemoteNeovimSSHConfig
---@field neovim_install_script_path string Local path where neovim installation script is stored
---@field remote_neovim_install_home string Where should remote neovim install and save configurations on the remote server
---@field neovim_user_config_path string Local path where the neovim configuration to be copied over to the remote
--server is stored. This is assumed to be a directory and entire directory would be copied over
---@field log_level log_level

---@alias log_level "trace"|"debug"|"info"|"error"|"fatal"
---@alias prompt_type "plain"|"secret"
---@alias prompt_value_type "static"|"dynamic"

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
local default_opts = {
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
  log_level = "info",
}

M.setup_commands = function()
  vim.api.nvim_create_user_command("RemoteNvimLaunch", function()
    if M.ssh_binary == nil then
      error("OpenSSH client not found. Cannot proceed further.")
    end
    require("telescope").extensions["remote-nvim"].connect()
  end, {})
end

M.setup_keymaps = function()
  vim.api.nvim_set_keymap("n", ",p", ":Lazy reload remote-nvim.nvim<CR>", {})
end

M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", default_opts, args or {}) or default_opts
  M.config.ssh_config.ssh_binary = util.find_binary(M.config.ssh_config.ssh_binary)
  M.config.ssh_config.scp_binary = util.find_binary(M.config.ssh_config.scp_binary)

  M.remote_neovim_host_config = RemoteHostWorkspaceConfig:new()
  M.sessions = {}

  -- require("remote-nvim.ssh").setup(M.config)

  M.setup_commands()
  M.setup_keymaps()
end

return M
