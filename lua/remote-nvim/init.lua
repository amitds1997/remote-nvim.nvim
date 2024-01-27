---@class remote-nvim.RemoteNeovim
---@field default_opts remote-nvim.config.PluginConfig Default plugin configuration
---@field config remote-nvim.config.PluginConfig Plugin configuration
---@field session_provider remote-nvim.providers.SessionProvider Session provider for each unique host
---@field setup fun(opts: remote-nvim.config.PluginConfig) Setup the plugin
local M = {}

local constants = require("remote-nvim.constants")
local utils = require("remote-nvim.utils")

---@alias prompt_type "plain"|"secret"
---@alias prompt_value_type "static"|"dynamic"
---@alias devcontainer_cfg_search_style "current_dir_only"|"recurse_up"|"none"
---@alias container_list_opts "running_only"|"all"

---@class remote-nvim.config.PluginConfig.SSHConfig.SSHPrompt
---@field match string Text that input should be matched against to identify need for stdin
---@field type prompt_type Is the input to be provided a secret?
---@field input_prompt string? What should be shown as input prompt when requesting user for input
---@field value_type prompt_value_type Is the prompt value going to remain same throughout a session, if yes, it can be cached
---@field value string Default value to fill in for the prompt, if any

---@class remote-nvim.config.PluginConfig.DevpodConfig
---@field binary string Name of binary on runtime path for dev container
---@field docker_binary string Name of the binary to use for docker containers
---@field ssh_config_path string Configuration path where devpod SSH configurations would be stored
---@field search_style devcontainer_cfg_search_style Where to search for devcontainer configuration
---@field dotfiles string? Path/URI to dotfiles to use in the container
---@field gpg_agent_forwarding boolean Should forward the local GPG Agent into workspace
---@field container_list container_list_opts Show only running or all containers in container list

---@class remote-nvim.config.PluginConfig.SSHConfig
---@field ssh_binary string Name of binary on runtime path for ssh
---@field scp_binary string Name of binary on runtime path for scp
---@field ssh_config_file_paths string[] Location of SSH configuration files that you want the plugin to consider
---@field ssh_prompts remote-nvim.config.PluginConfig.SSHConfig.SSHPrompt[] List of SSH prompts that should be considered for input

---@class remote-nvim.config.RemoteConfig.LocalClientConfig
---@field callback function<string, remote-nvim.providers.WorkspaceConfig> Function that would be called upon to start a Neovim client if not nil

---@class remote-nvim.config.PluginConfig.LogConfig
---@field filepath string Location of log file
---@field level string Logging level
---@field max_size integer Max file size, after which it will be truncated

---@class remote-nvim.config.PluginConfig.ProgressViewConfig
---@field type "popup"|"split" Type of holder to launch
---@field relative nui_layout_option_relative_type|nui_layout_option_relative? How should split/popup be placed
---@field position  number|string|nui_layout_option_position|nui_split_option_position? Where should the holder be placed
---@field size number|string|nui_layout_option_size|nui_split_option_size? What should be the size of the holder
---@field border _nui_popup_border_style_builtin|nui_popup_border_options? What kind of border should be applied to the popup
---@field anchor nui_layout_option_anchor? What to anchor the popup with
---@field zindex number? What should be the z-index for the popup

---@class remote-nvim.config.PluginConfig
---@field devpod remote-nvim.config.PluginConfig.DevpodConfig Devcontainer configuration
---@field ssh_config remote-nvim.config.PluginConfig.SSHConfig SSH configuration
---@field neovim_install_script_path string Local path where neovim installation script is stored
---@field neovim_user_config_path string Local path where the neovim configuration to be copied over to the remote
--server is stored. This is assumed to be a directory and entire directory would be copied over
---@field progress_view remote-nvim.config.PluginConfig.ProgressViewConfig Progress view configuration
---@field local_client_config remote-nvim.config.RemoteConfig.LocalClientConfig Configuration for the local client
---@field log remote-nvim.config.PluginConfig.LogConfig Plugin logging options

M.default_opts = {
  devpod = {
    binary = "devpod",
    docker_binary = "docker",
    ssh_config_path = utils.path_join(utils.is_windows, vim.fn.stdpath("data"), constants.PLUGIN_NAME, "ssh_config"),
    search_style = "current_dir_only",
    dotfiles = nil,
    gpg_agent_forwarding = false,
    container_list = "running_only",
  },
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
  progress_view = {
    type = "popup",
  },
  ---@diagnostic disable-next-line:assign-type-mismatch
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
    ---@diagnostic disable-next-line:param-type-mismatch
    filepath = utils.path_join(utils.is_windows, vim.fn.stdpath("state"), ("%s.log"):format(constants.PLUGIN_NAME)),
    level = "info",
    max_size = 1024 * 1024 * 2, -- 2MB
  },
}

---Setup for the plugin
---@param opts remote-nvim.config.PluginConfig User provided plugin configuration
---@return nil
M.setup = function(opts)
  local min_neovim_version = require("remote-nvim.constants").MIN_NEOVIM_VERSION:sub(2)
  if not vim.fn.has(("nvim-%s"):format(min_neovim_version)) then
    vim.notify_once(
      ("remote-nvim.nvim requires Neovim >= %s"):format(min_neovim_version),
      vim.log.levels.ERROR,
      { title = "remote-nvim.nvim" }
    )
  end
  M.config = vim.tbl_deep_extend("force", M.default_opts, opts or {})
  M.session_provider = require("remote-nvim.providers.session_provider")()
  require("remote-nvim.command")
  require("remote-nvim.colors").setup()

  utils.truncate_log()
end

return M
