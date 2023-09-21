local remote_nvim = require("remote-nvim")
local remote_nvim_ssh_provider = require("remote-nvim.providers.ssh.ssh_provider")

local M = {}

-- Define a function to check if an element exists in a list
local function contains(list, element)
  for _, value in ipairs(list) do
    if value == element then
      return true
    end
  end
  return false
end

function M.RemoteStart(opts)
  local host_identifier = opts.args
  if host_identifier == "" then
    require("telescope").extensions["remote-nvim"].connect()
  else
    local workspace_config = remote_nvim.session_provider.remote_workspaces_config:get_workspace_config(host_identifier)
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
      return remote_nvim.session_provider.remote_workspaces_config:get_all_host_ids()
    end
    return vim.fn.matchfuzzy(remote_nvim.session_provider.remote_workspaces_config:get_all_host_ids(), args[1])
  end,
})

function M.RemoteLog()
  vim.api.nvim_cmd({
    cmd = "tabnew",
    args = { remote_nvim.config.log.filepath },
  }, {})
end

vim.api.nvim_create_user_command("RemoteLog", M.RemoteLog, {
  desc = "Open the remote-nvim.nvim log file",
})

function M.RemoteCleanup(opts)
  local host_ids = vim.split(vim.trim(opts.args), "%s+")
  if #host_ids > 1 then
    error("Please pass only one parameter at a time")
  end
  for _, host_id in ipairs(host_ids) do
    local workspace_config = remote_nvim.session_provider.remote_workspaces_config:get_workspace_config(host_id)

    remote_nvim.sessions[host_id] = remote_nvim.sessions[host_id]
      or remote_nvim_ssh_provider:new(workspace_config.host, workspace_config.connection_options)
    remote_nvim.sessions[host_id]:clean_up_remote_host()
    remote_nvim.sessions[host_id]:reset()
  end
end

vim.api.nvim_create_user_command("RemoteCleanup", M.RemoteCleanup, {
  desc = "Clean up remote host",
  nargs = 1,
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)
    if #args == 0 then
      return remote_nvim.session_provider.remote_workspaces_config:get_all_host_ids()
    end
    local host_ids = vim.fn.filter(
      remote_nvim.session_provider.remote_workspaces_config:get_all_host_ids(),
      function(_, item)
        return not contains(args, item)
      end
    )
    local completion_word = table.remove(args, #args)

    -- If we have not provided any input, then the last word is the last completion
    if contains(remote_nvim.session_provider.remote_workspaces_config:get_all_host_ids(), completion_word) then
      return host_ids
    end
    return vim.fn.matchfuzzy(host_ids, completion_word)
  end,
})

vim.api.nvim_create_user_command("RemoteStop", function(opts)
  local host_ids = vim.split(vim.trim(opts.args), "%s+")
  for _, host_id in ipairs(host_ids) do
    remote_nvim.sessions[host_id]:reset()
  end
end, {
  desc = "Stop running remote server",
  nargs = "+",
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)

    -- Filter out those sessions whose port forwarding jobs are not running
    local running_sessions = {}
    for session, session_provider in pairs(remote_nvim.sessions) do
      if session_provider.remote_port_forwarding_job_id ~= nil then
        table.insert(running_sessions, session)
      end
    end

    if #args == 0 then
      return running_sessions
    end
    local host_ids = vim.fn.filter(running_sessions, function(_, item)
      return not contains(args, item)
    end)
    local completion_word = table.remove(args, #args)

    -- If we have not provided any input, then the last word is the last completion
    if contains(running_sessions, completion_word) then
      return host_ids
    end
    return vim.fn.matchfuzzy(running_sessions, completion_word)
  end,
})

vim.api.nvim_create_user_command("RemoteConfigDel", function(opts)
  local host_identifiers = vim.split(vim.trim(opts.args), "%s+")
  for _, host_id in ipairs(host_identifiers) do
    remote_nvim.session_provider.remote_workspaces_config:delete_workspace(host_id)
  end
end, {
  desc = "Delete cached workspace record",
  nargs = "+",
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)
    if #args == 0 then
      return remote_nvim.session_provider.remote_workspaces_config:get_all_host_ids()
    end
    local host_ids = vim.fn.filter(
      remote_nvim.session_provider.remote_workspaces_config:get_all_host_ids(),
      function(_, item)
        return not contains(args, item)
      end
    )
    local completion_word = table.remove(args, #args)

    -- If we have not provided any input, then the last word is the last completion
    if contains(remote_nvim.session_provider.remote_workspaces_config:get_all_host_ids(), completion_word) then
      return host_ids
    end
    return vim.fn.matchfuzzy(host_ids, completion_word)
  end,
})

vim.api.nvim_create_user_command("RemoteSessionInfo", require("remote-nvim.views.info").RemoteInfo, {
  desc = "Get information about all running session(s)",
  nargs = 0,
})

return M
