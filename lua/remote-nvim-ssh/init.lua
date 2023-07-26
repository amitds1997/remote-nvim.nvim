local util = require "remote-nvim-ssh.utils"
local M = {}

local default_opts = {
  ssh_binary = "ssh",
  ssh_config_files = { "$HOME/.ssh/config" },
  ssh_prompts = {
    {
      match = "password:",
      type = "secret",
      input_prompt = "Enter password: "
    }
  }
}

M.setup_commands = function()
  vim.api.nvim_create_user_command("RemoteNvimConnect", function()
    if M.ssh_binary == nil then
      error("OpenSSH client not found. Cannot proceed further.")
    end
    require("telescope").extensions["remote-nvim-ssh"].connect()
  end, {})
end

M.setup_keymaps = function()
  vim.api.nvim_set_keymap('n', ',p', ':Lazy reload remote-nvim-ssh.nvim<CR>', {})
end

M.setup = function(args)
  local opts = vim.tbl_deep_extend("force", default_opts, args or {}) or default_opts
  M.ssh_binary = util.find_binary(opts.ssh_binary)
  M.ssh_prompts = opts.ssh_prompts

  require("remote-nvim-ssh.ssh").setup(opts)

  M.setup_commands()
  M.setup_keymaps()
end


return M
