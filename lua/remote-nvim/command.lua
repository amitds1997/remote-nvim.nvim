local remote_nvim = require("remote-nvim")
local remote_nvim_ssh_provider = require("remote-nvim.providers.ssh.ssh_provider")

local M = {}

function M.RemoteStart(opts)
  local host_identifier = opts.args
  if host_identifier == "" then
    require("telescope").extensions["remote-nvim"].connect()
  else
    local workspace_config = remote_nvim.host_workspace_config:get_workspace_config_data(host_identifier)
    remote_nvim.sessions[host_identifier] = remote_nvim.sessions[host_identifier]
      or remote_nvim_ssh_provider:new(workspace_config.host, workspace_config.connection_options)
    remote_nvim.sessions[host_identifier]:set_up_remote()
  end
end

vim.api.nvim_create_user_command("RemoteStart", M.RemoteStart, {
  nargs = "?",
  desc = "Start Neovim on remote host",
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)
    if #args == 0 then
      return remote_nvim.host_workspace_config:get_all_host_ids()
    end
    return vim.fn.matchfuzzy(remote_nvim.host_workspace_config:get_all_host_ids(), args[1])
  end,
})

function M.RemoteLog()
  vim.api.nvim_cmd({
    cmd = "tabnew",
    args = { require("remote-nvim.utils").logger.outfile },
  }, {})
end

vim.api.nvim_create_user_command("RemoteLog", M.RemoteLog, {
  desc = "Open the remote-nvim.nvim log file",
})

function M.RemoteCleanup(opts)
  local host_identifier = opts.args
  local workspace_config = remote_nvim.host_workspace_config:get_workspace_config_data(host_identifier)

  remote_nvim.sessions[host_identifier] = remote_nvim.sessions[host_identifier]
    or remote_nvim_ssh_provider:new(workspace_config.host, workspace_config.connection_options)
  remote_nvim.sessions[host_identifier]:clean_up_remote_host()
  remote_nvim.sessions[host_identifier]:reset()
end

vim.api.nvim_create_user_command("RemoteCleanup", M.RemoteCleanup, {
  desc = "Clean up remote host",
  nargs = 1,
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)
    if #args == 0 then
      return remote_nvim.host_workspace_config:get_all_host_ids()
    end
    return vim.fn.matchfuzzy(remote_nvim.host_workspace_config:get_all_host_ids(), args[1])
  end,
})

vim.api.nvim_create_user_command("RemoteStop", function(opts)
  local active_server_host_identifier = opts.args
  remote_nvim.sessions[active_server_host_identifier]:reset()
end, {
  desc = "Stop running remote server",
  nargs = 1,
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)
    if #args == 0 then
      return vim.tbl_keys(remote_nvim.sessions)
    end
    return vim.fn.matchfuzzy(vim.tbl_keys(remote_nvim.sessions), args[1])
  end,
})

vim.api.nvim_create_user_command("RemoteConfigDel", function(opts)
  local unique_host_identifier = opts.args
  remote_nvim.host_workspace_config:delete_workspace(unique_host_identifier)
end, {
  desc = "Delete cached workspace record",
  nargs = 1,
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)
    if #args == 0 then
      return remote_nvim.host_workspace_config:get_all_host_ids()
    end
    return vim.fn.matchfuzzy(remote_nvim.host_workspace_config:get_all_host_ids(), args[1])
  end,
})

vim.api.nvim_create_user_command("RemoteCloseTUIs", function()
  for _, ui in pairs(vim.api.nvim_list_uis()) do
    if ui.chan and not ui.stdout_tty then
      vim.fn.chanclose(ui.chan)
    end
  end
end, {
  desc = "Close all TUIs associated with the current associated server",
  nargs = 0,
})

vim.api.nvim_create_user_command("RemoteSessionInfo", require("remote-nvim.views.info").RemoteInfo, {
  desc = "Get information about all running session(s)",
  nargs = 0,
})

return M
