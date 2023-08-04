local function RemoteNvimLaunch()
  require("telescope").extensions["remote-nvim"].connect()
end
vim.api.nvim_create_user_command("RemoteNvimLaunch", RemoteNvimLaunch, {
  desc = "Launch remote Neovim workspace",
})

local function RemoteNvimLog()
  local logger = require("remote-nvim.utils").logger
  vim.api.nvim_cmd({
    cmd = "tabnew",
    args = { logger.outfile },
  }, {})
end

vim.api.nvim_create_user_command("RemoteNvimLog", RemoteNvimLog, {
  desc = "Open the remote-nvim.nvim log file in a new tab",
})

return {
  RemoteNvimLaunch = RemoteNvimLaunch,
  RemoteNvimLog = RemoteNvimLog,
}
