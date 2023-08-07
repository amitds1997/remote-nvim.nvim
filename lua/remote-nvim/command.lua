local remote_nvim = require("remote-nvim")
local remote_nvim_ssh_provider = require("remote-nvim.providers.ssh.ssh_provider")

local parse = function(cmd, args)
  local parts = vim.split(vim.trim(args), "%s+")
  if parts[1]:find(cmd) then
    table.remove(parts, 1)
  end
  if args:sub(-1) == " " then
    parts[#parts + 1] = ""
  end
  return table.remove(parts, 1) or "", parts
end

local function RemoteStart()
  require("telescope").extensions["remote-nvim"].connect()
end
vim.api.nvim_create_user_command("RemoteStart", RemoteStart, {
  desc = "Start Neovim on remote host",
})

local function RemoteLog()
  local logger = require("remote-nvim.utils").logger
  vim.api.nvim_cmd({
    cmd = "tabnew",
    args = { logger.outfile },
  }, {})
end

vim.api.nvim_create_user_command("RemoteLog", RemoteLog, {
  desc = "Open the remote-nvim.nvim log file in a new tab",
})

vim.api.nvim_create_user_command("RemoteCleanup", function(opts)
  local host_identifier = opts.args
  local workspace_config = remote_nvim.host_workspace_config:get_workspace_config_data(host_identifier)

  remote_nvim.sessions[host_identifier] = remote_nvim.sessions[host_identifier]
    or remote_nvim_ssh_provider:new(workspace_config.host, workspace_config.connection_options)
  remote_nvim.sessions[host_identifier]:clean_up_remote_host()
  -- TODO: Also call close session command because the server folders do not exist any more
end, {
  desc = "Clean up remote host",
  nargs = 1,
  complete = function(_, line)
    local prefix, _ = parse("RemoteNvimClean", line)
    return vim.fn.matchfuzzy(remote_nvim.host_workspace_config:get_all_host_ids(), prefix)
  end,
})

return {
  RemoteStart = RemoteStart,
  RemoteLog = RemoteLog,
}
