local util = require("remote-nvim.utils")
local RemoteHostWorkspaceConfig = require("remote-nvim.config")
local M = {}

local default_opts = {
  ssh_binary = "ssh",
  scp_binary = "scp",
  ssh_config_files = { "$HOME/.ssh/config" },
  ssh_prompts = {
    {
      match = "password:",
      type = "secret",
      input_prompt = "Enter password: ",
      value_type = "static",
      value = nil,
    },
    {
      match = "continue connecting (yes/no/[fingerprint])?",
      type = "plain",
      input_prompt = "Do you want to continue connection (yes/no)? ",
      value_type = "static",
      value = nil,
    }
  },
  install_script = nil,   -- default path is set during setup() call, if not provided
  remote_nvim_home = nil, -- default path is set during setup() call, if not provided
  local_neovim_config_path = nil,
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
  vim.api.nvim_set_keymap('n', ',p', ':Lazy reload remote-nvim.nvim<CR>', {})
end

M.setup = function(args)
  local opts = vim.tbl_deep_extend("force", default_opts, args or {}) or default_opts
  M.ssh_binary = util.find_binary(opts.ssh_binary)
  M.scp_binary = util.find_binary(opts.scp_binary)
  M.ssh_prompts = opts.ssh_prompts
  M.install_script = opts.install_script or util.path_join(util.get_package_root(), "scripts", "neovim_install.sh")
  M.remote_nvim_home = opts.remote_nvim_home or util.path_join("~", ".remote-nvim")
  M.local_neovim_config_path = opts.local_neovim_config_path or vim.fn.stdpath('config')
  M.remote_nvim_host_config = RemoteHostWorkspaceConfig:new()
  M.log_level = opts.log_level
  M.remote_sessions = {}

  require("remote-nvim.ssh").setup(opts)

  M.setup_commands()
  M.setup_keymaps()
end


return M
