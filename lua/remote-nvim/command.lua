---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

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
    ---@type remote-nvim.providers.WorkspaceConfig
    local workspace_config = remote_nvim.session_provider:get_config_provider():get_workspace_config(host_identifier)
    if vim.tbl_isempty(workspace_config) then
      vim.notify("Unknown host identifier. Run :RemoteStart to connect to a new host", vim.log.levels.ERROR)
    else
      remote_nvim.session_provider
        :get_or_initialize_session("ssh", workspace_config.host, workspace_config.connection_options)
        :launch_neovim()
    end
  end
end

vim.api.nvim_create_user_command("RemoteStart", M.RemoteStart, {
  nargs = "?",
  desc = "Start Neovim on remote host",
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)
    local valid_hosts =
      vim.tbl_keys(remote_nvim.session_provider:get_config_provider():get_workspace_config(nil, "ssh"))
    if #args == 0 then
      return valid_hosts
    end
    return vim.fn.matchfuzzy(valid_hosts, args[1])
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
    ---@type remote-nvim.providers.WorkspaceConfig
    local workspace_config = remote_nvim.session_provider:get_config_provider():get_workspace_config(host_id)

    if vim.tbl_isempty(workspace_config) then
      vim.notify("Unknown host identifier. Run :RemoteStart to connect to a new host", vim.log.levels.ERROR)
    else
      remote_nvim.session_provider
        :get_or_initialize_session("ssh", workspace_config.host, workspace_config.connection_options)
        :clean_up_remote_host()
    end
  end
end

vim.api.nvim_create_user_command("RemoteCleanup", M.RemoteCleanup, {
  desc = "Clean up remote host",
  nargs = 1,
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)
    local valid_hosts =
      vim.tbl_keys(remote_nvim.session_provider:get_config_provider():get_workspace_config(nil, "ssh"))
    if #args == 0 then
      return valid_hosts
    end
    local host_ids = vim.fn.filter(valid_hosts, function(_, item)
      return not contains(args, item)
    end)
    local completion_word = table.remove(args, #args)

    -- If we have not provided any input, then the last word is the last completion
    if contains(valid_hosts, completion_word) then
      return host_ids
    end
    return vim.fn.matchfuzzy(host_ids, completion_word)
  end,
})

vim.api.nvim_create_user_command("RemoteStop", function(opts)
  local host_ids = vim.split(vim.trim(opts.args), "%s+")
  local workspace_configs = remote_nvim.session_provider:get_config_provider():get_workspace_config()
  for _, host_id in ipairs(host_ids) do
    local workspace_config = workspace_configs[host_id]
    remote_nvim.session_provider
      :get_or_initialize_session("ssh", workspace_config.host, workspace_config.connection_options)
      :stop_neovim()
  end
end, {
  desc = "Stop running remote server",
  nargs = "+",
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)

    -- Filter out those sessions whose port forwarding jobs are not running
    local running_sessions = {}
    local active_sessions = remote_nvim.session_provider:get_active_sessions()
    for host_id, session in pairs(active_sessions) do
      if session:is_remote_server_running() then
        table.insert(running_sessions, host_id)
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
    remote_nvim.session_provider:get_config_provider():remove_workspace_config(host_id)
  end
  vim.notify("Workspace configuration(s) deleted")
end, {
  desc = "Delete cached workspace record",
  nargs = "+",
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)
    local hosts = vim.tbl_keys(remote_nvim.session_provider:get_config_provider():get_workspace_config())
    if #args == 0 then
      return hosts
    end
    local host_ids = vim.fn.filter(hosts, function(_, item)
      return not contains(args, item)
    end)
    local completion_word = table.remove(args, #args)

    -- If we have not provided any input, then the last word is the last completion
    if contains(hosts, completion_word) then
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
