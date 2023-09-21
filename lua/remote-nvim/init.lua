local constants = require("remote-nvim.constants")
local utils = require("remote-nvim.utils")
local M = {}

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

---@class RemoteNeovimSSHPrompts
---@field match string Text that input should be matched against to identify need for stdin
---@field type prompt_type Is the input to be provided a secret?
---@field input_prompt? string What should be shown as input prompt when requesting user for input
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
  neovim_install_script_path = utils.path_join(
    utils.is_windows,
    vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h"),
    "scripts",
    "neovim_install.sh"
  ),
  remote_neovim_install_home = utils.path_join(utils.is_windows, "~", ".remote-nvim"),
  neovim_user_config_path = vim.fn.stdpath("config"),
  local_client_config = {
    callback = function(port, _)
      require("remote-nvim.ui").float_term(("nvim --server localhost:%s --remote-ui"):format(port), function(exit_code)
        if exit_code ~= 0 then
          vim.notify(("Local client failed with exit code %s"):format(exit_code), vim.log.levels.ERROR)
        end
      end)
    end,
  },
  log = {
    filepath = utils.path_join(utils.is_windows, vim.fn.stdpath("state"), ("%s.log"):format(constants.PLUGIN_NAME)),
    level = vim.log.levels.INFO,
    max_size = 1024 * 1024 * 2, -- 2MB
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
  M.config.ssh_config.ssh_binary = M.config.ssh_config.ssh_binary
  M.config.ssh_config.scp_binary = M.config.ssh_config.scp_binary
  M.session_provider = require("remote-nvim.providers.session_provider"):new()
  require("remote-nvim.command")

  utils.truncate_log()
end

return M
