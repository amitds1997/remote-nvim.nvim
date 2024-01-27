local contains = require("remote-nvim.utils").contains
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

local M = {}

function M.RemoteStart(opts)
  local host_identifier = opts.args
  if host_identifier == "" then
    require("telescope").extensions["remote-nvim"].connect()
  else
    ---@type remote-nvim.providers.WorkspaceConfig
    local workspace_config =
      remote_nvim.session_provider:get_config_provider():get_workspace_config(vim.trim(host_identifier))
    if vim.tbl_isempty(workspace_config) then
      vim.notify("Unknown host identifier. Run :RemoteStart to connect to a new host", vim.log.levels.ERROR)
    else
      remote_nvim.session_provider
        :get_or_initialize_session({
          host = workspace_config.host,
          provider_type = workspace_config.provider,
          conn_opts = { workspace_config.connection_options },
        })
        :launch_neovim()
    end
  end
end

vim.api.nvim_create_user_command("RemoteStart", M.RemoteStart, {
  nargs = "?",
  desc = "Start Neovim on remote machine",
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)
    local valid_hosts = vim.tbl_keys(remote_nvim.session_provider:get_config_provider():get_workspace_config())
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
  desc = "Open Remote Neovim logs",
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
        :get_or_initialize_session({
          host = workspace_config.host,
          provider_type = workspace_config.provider,
          conn_opts = { workspace_config.connection_options },
        })
        :clean_up_remote_host()
    end
  end
end

vim.api.nvim_create_user_command("RemoteInfo", function(opts)
  local host_ids = vim.split(vim.trim(opts.args), "%s+")
  local sessions = remote_nvim.session_provider:get_all_sessions()

  if #vim.tbl_keys(sessions) == 0 then
    vim.notify("No active sessions found. Please start remote session(s) with :RemoteStart first", vim.log.levels.WARN)
    return
  elseif #host_ids > 1 then
    vim.notify("Please pass only one host at a time", vim.log.levels.WARN)
    return
  elseif #host_ids == 1 and vim.trim(host_ids[1]) ~= "" then
    local session = sessions[host_ids[1]]

    if session == nil then
      vim.notify(("No active remote session to %s found"):format(host_ids[1]), vim.log.levels.WARN)
    else
      session:show_progress_view_window()
    end
  else
    vim.ui.select(vim.tbl_keys(sessions), {
      prompt = "Choose remote neovim session",
    }, function(choice)
      if choice == nil then
        vim.notify("No session selected")
      else
        sessions[choice]:show_progress_view_window()
      end
    end)
  end
end, {
  desc = "View Remote Neovim launched session's information",
  nargs = "?",
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)

    -- Filter out those sessions whose port forwarding jobs are not running
    local active_sessions = remote_nvim.session_provider:get_all_sessions()
    local running_sessions = vim.tbl_keys(active_sessions)

    if #args == 0 then
      return running_sessions
    end
    local host_ids = vim.fn.filter(running_sessions, function(_, item)
      return not vim.tbl_contains(args, item)
    end)
    local completion_word = table.remove(args, #args)

    -- If we have not provided any input, then the last word is the last completion
    if vim.tbl_contains(running_sessions, completion_word) then
      return host_ids
    end
    return vim.fn.matchfuzzy(running_sessions, completion_word)
  end,
})

vim.api.nvim_create_user_command("RemoteCleanup", M.RemoteCleanup, {
  desc = "Clean up Remote Neovim created resources from remote machine",
  nargs = 1,
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)
    local valid_hosts = vim.tbl_keys(remote_nvim.session_provider:get_config_provider():get_workspace_config())
    if #args == 0 then
      return valid_hosts
    end
    local host_ids = vim.fn.filter(valid_hosts, function(_, item)
      return not vim.tbl_contains(args, item)
    end)
    local completion_word = table.remove(args, #args)

    -- If we have not provided any input, then the last word is the last completion
    if vim.tbl_contains(valid_hosts, completion_word) then
      return host_ids
    end
    return vim.fn.matchfuzzy(host_ids, completion_word)
  end,
})

vim.api.nvim_create_user_command("RemoteStop", function(opts)
  local host_ids = vim.split(vim.trim(opts.args), "%s+")
  local sessions = remote_nvim.session_provider:get_all_sessions()
  local running_sessions = {}
  for host_id, session in pairs(sessions) do
    if session:is_remote_server_running() then
      table.insert(running_sessions, host_id)
    end
  end

  if #host_ids == 1 and vim.trim(host_ids[1]) ~= "" then
    local session = sessions[host_ids[1]]

    if session == nil or not session:is_remote_server_running() then
      vim.notify(("No active remote session to '%s' found"):format(host_ids[1]), vim.log.levels.WARN)
    else
      session:stop_neovim()
      session:hide_progress_view_window()
    end
  elseif #host_ids > 1 then
    vim.notify("Please pass only one host at a time", vim.log.levels.WARN)
    return
  elseif (#vim.tbl_keys(sessions) == 0) or #running_sessions == 0 then
    vim.notify("No active sessions found. Please start remote session(s) with :RemoteStart first", vim.log.levels.WARN)
    return
  else
    vim.ui.select(running_sessions, {
      prompt = "Choose active session that needs to be closed",
    }, function(choice)
      if choice == nil then
        vim.notify("No session selected")
      else
        sessions[choice]:stop_neovim()
        sessions[choice]:hide_progress_view_window()
      end
    end)
  end
end, {
  desc = "Stop running Remote Neovim launched Neovim server",
  nargs = "?",
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)

    -- Filter out those sessions whose port forwarding jobs are not running
    local running_sessions = {}
    local sessions = remote_nvim.session_provider:get_all_sessions()
    for host_id, session in pairs(sessions) do
      if session:is_remote_server_running() then
        table.insert(running_sessions, host_id)
      end
    end

    if #args == 0 then
      return running_sessions
    end
    local host_ids = vim.fn.filter(running_sessions, function(_, item)
      return not vim.tbl_contains(args, item)
    end)
    local completion_word = table.remove(args, #args)

    -- If we have not provided any input, then the last word is the last completion
    if vim.tbl_contains(running_sessions, completion_word) then
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
  desc = "Delete Remote Neovim workspace record",
  nargs = "+",
  complete = function(_, line)
    local args = vim.split(vim.trim(line), "%s+")
    table.remove(args, 1)
    local hosts = vim.tbl_keys(remote_nvim.session_provider:get_config_provider():get_workspace_config())
    if #args == 0 then
      return hosts
    end
    local host_ids = vim.fn.filter(hosts, function(_, item)
      return not vim.tbl_contains(args, item)
    end)
    local completion_word = table.remove(args, #args)

    -- If we have not provided any input, then the last word is the last completion
    if vim.tbl_contains(hosts, completion_word) then
      return host_ids
    end
    return vim.fn.matchfuzzy(host_ids, completion_word)
  end,
})

vim.api.nvim_create_user_command("RemoteSessionInfo", require("remote-nvim.views.info").RemoteInfo, {
  desc = "Get information about all running session(s) DEPRECATED",
  nargs = 0,
})

return M
