---@alias provider_type "ssh"|"docker"|"local"
---@alias os_type "macOS"|"Windows"|"Linux"

---@class remote-nvim.providers.WorkspaceConfig
---@field provider provider_type? Which provider is responsible for managing this workspace
---@field workspace_id string? Unique ID for workspace
---@field os os_type? OS running on the remote host
---@field host string? Host name to whom the workspace belongs
---@field neovim_version string? Version of Neovim running on the remote
---@field connection_options string? Connection options needed to connect to the remote host
---@field remote_neovim_home string? Path on remote host where remote-neovim installs/configures things
---@field config_copy boolean? Flag indicating if the config should be copied or not
---@field client_auto_start boolean? Flag indicating if the client should be auto started or not

---@class remote-nvim.providers.Provider: remote-nvim.Object
---@field host string Host name
---@field conn_opts string Connection options
---@field provider_type provider_type Type of provider
---@field protected unique_host_id string Unique host identifier
---@field protected executor remote-nvim.providers.Executor Executor instance
---@field protected notifier remote-nvim.providers.Notifier Notification handler
---@field private _host_config remote-nvim.providers.WorkspaceConfig Host workspace configuration
---@field private _config_provider remote-nvim.ConfigProvider Host workspace configuration
---@field private logger plenary.logger Logger instance
---@field private _setup_running boolean Is the setup running?
---@field private _local_free_port string? Free port available on local machine
---@field private _local_neovim_install_script_path string Local path where Neovim installation script is stored
---@field private _remote_neovim_home string Directory where all remote neovim data would be stored on host
---@field private _remote_os string Remote host's OS
---@field private _remote_neovim_version string Neovim version on the remote host
---@field private _remote_is_windows boolean Flag indicating whether the remote system is windows
---@field private _remote_workspace_id string Workspace ID associated with remote neovim
---@field private _remote_workspaces_path  string Path to remote workspaces on remote host
---@field private _remote_scripts_path  string Path to scripts path on the remote host
---@field private _remote_workspace_id_path  string Path to the workspace associated with the remote host
---@field private _remote_xdg_config_path  string Get workspace specific XDG config path
---@field private _remote_xdg_data_path  string Get workspace specific XDG data path
---@field private _remote_xdg_state_path  string Get workspace specific XDG state path
---@field private _remote_xdg_cache_path  string Get workspace specific XDG cache path
---@field private _remote_neovim_config_path  string Get neovim configuration path on the remote host
---@field private _remote_neovim_install_script_path  string Get Neovim installation script path on the remote host
---@field private _remote_server_process_id  integer? Process ID of the remote server job
local Provider = require("remote-nvim.middleclass")("Provider")

local Executor = require("remote-nvim.providers.executor")
local Notifier = require("remote-nvim.providers.notifier")
local provider_utils = require("remote-nvim.providers.utils")
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")
local utils = require("remote-nvim.utils")

---Create new provider instance
---@param host string
---@param conn_opts string|table?
function Provider:init(host, conn_opts)
  assert(host ~= nil, "Host must be provided")
  self.host = host

  if type(conn_opts) == "table" then
    conn_opts = table.concat(conn_opts, " ")
  else
    conn_opts = conn_opts or ""
  end
  self.conn_opts = self:_cleanup_conn_options(conn_opts)
  self.logger = utils.get_logger()
  self._config_provider = remote_nvim.session_provider:get_config_provider()

  -- These should be overriden in implementing classes

  self.unique_host_id = self.host
  self.provider_type = "local"
  self.executor = Executor()
  self.notifier = Notifier({
    title = "Remote Nvim",
  })

  ---@diagnostic disable-next-line: missing-fields
  self._host_config = {}
  self:_reset()
end

---Clean up connection options
---@param conn_opts string
---@return string cleaned_conn_opts
function Provider:_cleanup_conn_options(conn_opts)
  return conn_opts
end

---Setup workspace variables
function Provider:_setup_workspace_variables()
  if vim.tbl_isempty(self._config_provider:get_workspace_config(self.unique_host_id)) then
    self._config_provider:add_workspace_config(self.unique_host_id, {
      provider = self.provider_type,
      host = self.host,
      connection_options = self.conn_opts,
      remote_neovim_home = remote_nvim.config.remote_neovim_install_home,
      config_copy = nil,
      client_auto_start = nil,
      workspace_id = utils.generate_random_string(10),
    })
  end
  self._host_config = self._config_provider:get_workspace_config(self.unique_host_id)

  -- Gather remote OS information
  if self._host_config.os == nil then
    self._host_config.os = self:_get_remote_os()
    self._config_provider:update_workspace_config(self.unique_host_id, {
      os = self._host_config.os,
    })
  end

  -- Gather remote neovim version, if not setup
  if self._host_config.neovim_version == nil then
    self._host_config.neovim_version = self:_get_remote_neovim_version_preference()
    self._config_provider:update_workspace_config(self.unique_host_id, {
      neovim_version = self._host_config.neovim_version,
    })
  end

  -- Set variables from the fetched configuration

  self._remote_os = self._host_config.os
  self._remote_is_windows = self._remote_os == "Windows" and true or false
  self._remote_neovim_version = self._host_config.neovim_version
  self._remote_workspace_id = self._host_config.workspace_id

  -- Set up remaining workspace variables

  self._remote_neovim_home = self._host_config.remote_neovim_home
  self._remote_workspaces_path = utils.path_join(self._remote_is_windows, self._remote_neovim_home, "workspaces")
  self._remote_scripts_path = utils.path_join(self._remote_is_windows, self._remote_neovim_home, "scripts")
  self._remote_neovim_install_script_path = utils.path_join(
    self._remote_is_windows,
    self._remote_scripts_path,
    vim.fn.fnamemodify(remote_nvim.config.neovim_install_script_path, ":t")
  )
  self._remote_workspace_id_path =
    utils.path_join(self._remote_is_windows, self._remote_workspaces_path, self._remote_workspace_id)

  local xdg_variables = {
    config = ".config",
    cache = ".cache",
    data = utils.path_join(self._remote_is_windows, ".local", "share"),
    state = utils.path_join(self._remote_is_windows, ".local", "state"),
  }
  for xdg_name, path in pairs(xdg_variables) do
    self["_remote_xdg_" .. xdg_name .. "_path"] =
      utils.path_join(self._remote_is_windows, self._remote_workspace_id_path, path)
  end
  self._remote_neovim_config_path = utils.path_join(self._remote_is_windows, self._remote_xdg_config_path, "nvim")
end

---@private
---Reset provider state
function Provider:_reset()
  self._setup_running = false
  self._remote_server_process_id = nil
  self._local_free_port = nil
end

---@protected
---Generate host identifer using host and port on host
---@return string host_id Unique identifier for the host
function Provider:get_unique_host_id()
  error("Not implemented")
end

---@private
---Get OS running on the remote host
---@return string remote_os OS running on remote host
function Provider:_get_remote_os()
  if self._remote_os == nil then
    self:run_command("uname", "Get remote OS")
    local cmd_out_lines = self.executor:job_stdout()
    local os = cmd_out_lines[#cmd_out_lines]

    if os == "Linux" then
      self._remote_os = os
    elseif os == "Darwin" then
      self._remote_os = "macOS"
    else
      local os_choices = {
        "Linux",
        "macOS",
        "Windows",
      }
      self._remote_os = self:get_selection(os_choices, {
        prompt = ("Choose remote OS (found OS '%s'): "):format(os),
        format_item = function(item)
          return ("Remote host is running %s"):format(item)
        end,
      })
    end

    self.notifier:notify(("OS is %s"):format(self._remote_os), vim.log.levels.INFO, true)
  end

  return self._remote_os
end

---@protected
---Get selection choice
---@param choices string[]
---@param selection_opts table
---@return string selected_choice Selected choice
function Provider:get_selection(choices, selection_opts)
  local choice = provider_utils.get_selection(choices, selection_opts)

  -- If the choice fails, we cannot move further so we stop the coroutine executing
  if choice == nil then
    self.notifier:notify("No selection made", vim.log.levels.WARN, true)
    local co = coroutine.running()
    if co then
      return coroutine.yield()
    else
      error("Choice is necessary to proceed.")
    end
  else
    return choice
  end
end

---@private
---Verify we are able to connect to the remote host
function Provider:_verify_connection_to_host()
  self:run_command("echo 'OK'", "Check host connection")
  self.notifier:notify("Successfully connected to remote host", vim.log.levels.INFO, true)
end

---@private
---Get neovim version to be run on the remote host
---@return string neovim_version Version running on the remote host
function Provider:_get_remote_neovim_version_preference()
  if self._remote_neovim_version == nil then
    local valid_neovim_versions = provider_utils.get_neovim_versions()

    -- Get client version
    local api_info = vim.version()
    local client_version = "v" .. table.concat({ api_info.major, api_info.minor, api_info.patch }, ".")

    self._remote_neovim_version = self:get_selection(valid_neovim_versions, {
      prompt = "What Neovim version should be installed on remote host?",
      format_item = function(ver)
        if ver == client_version then
          return "Install Neovim " .. ver .. " (Your client version)"
        end
        return "Install Neovim " .. ver
      end,
    })
  end

  return self._remote_neovim_version
end

---@private
---Get user preference about copying the local neovim config to remote
---@return boolean preference Should the config be copied over
function Provider:_get_neovim_config_upload_preference()
  if self._host_config.config_copy == nil then
    local choice = self:get_selection({ "Yes", "No", "Yes (always)", "No (never)" }, {
      prompt = ("Copy config at '%s' to remote host? "):format(remote_nvim.config.neovim_user_config_path),
    })

    -- Handle choices
    if choice == "Yes (always)" then
      self._host_config.config_copy = true
      self._config_provider:update_workspace_config(self.unique_host_id, {
        config_copy = self._host_config.config_copy,
      })
    elseif choice == "No (never)" then
      self._host_config.config_copy = false
      self._config_provider:update_workspace_config(self.unique_host_id, {
        config_copy = self._host_config.config_copy,
      })
    else
      self._host_config.config_copy = (choice == "Yes" and true) or false
    end
  end

  return self._host_config.config_copy
end

---Verify if the server is already running or not
---@return boolean
function Provider:is_remote_server_running()
  return self._remote_server_process_id ~= nil and (vim.fn.jobwait({ self._remote_server_process_id }, 0)[1] == -1)
end

---@private
---Get remote neovim binary path
---@return string binary_path remote neovim binary path
function Provider:_remote_neovim_binary_path()
  return utils.path_join(
    self._remote_is_windows,
    self._remote_neovim_home,
    "nvim-downloads",
    self._remote_neovim_version,
    "bin",
    "nvim"
  )
end

---@private
---Setup remote
function Provider:_setup_remote()
  if not self._setup_running then
    self:_verify_connection_to_host()

    if not self:is_remote_server_running() then
      self._setup_running = true

      -- Create necessary directories
      local necessary_dirs = {
        self._remote_workspaces_path,
        self._remote_scripts_path,
        self._remote_xdg_config_path,
        self._remote_xdg_cache_path,
        self._remote_xdg_state_path,
        self._remote_xdg_data_path,
      }
      local mkdirs_cmds = {}
      for _, dir in ipairs(necessary_dirs) do
        table.insert(mkdirs_cmds, ("mkdir -p %s"):format(dir))
      end
      self:run_command(table.concat(mkdirs_cmds, " && "), "Create necessary directories")

      -- Copy things required on remote
      self:upload(
        vim.fn.fnamemodify(remote_nvim.default_opts.neovim_install_script_path, ":h"),
        self._remote_neovim_home,
        "Copy necessary files"
      )

      ---If we have custom scripts specified, copy them over
      if remote_nvim.default_opts.neovim_install_script_path ~= remote_nvim.config.neovim_install_script_path then
        self:upload(
          remote_nvim.config.neovim_install_script_path,
          self._remote_scripts_path,
          "Copy user-specified files"
        )
      end

      -- Set correct permissions and install Neovim
      local install_neovim_cmd = ([[chmod +x %s && %s -v %s -d %s]]):format(
        self._remote_neovim_install_script_path,
        self._remote_neovim_install_script_path,
        self._remote_neovim_version,
        self._remote_neovim_home
      )
      self:run_command(install_neovim_cmd, "Install Neovim if not exists")

      -- Upload user neovim config, if necessary
      if self:_get_neovim_config_upload_preference() then
        self:upload(remote_nvim.config.neovim_user_config_path, self._remote_xdg_config_path, "Copy user neovim config")
      end

      self._setup_running = false
    end
  else
    self.notifier:notify_once(
      "Another instance of setup is already running. Wait for it to complete.",
      vim.log.levels.WARN
    )
  end
end

---@private
---Launch remote neovim server
function Provider:_launch_remote_neovim_server()
  if not self:is_remote_server_running() then
    -- Find free port on remote
    local free_port_on_remote_cmd = ("%s -l %s"):format(
      self:_remote_neovim_binary_path(),
      utils.path_join(self._remote_is_windows, self._remote_scripts_path, "free_port_finder.lua")
    )
    self:run_command(free_port_on_remote_cmd, "Find free port on remote")
    local remote_free_port_output = self.executor:job_stdout()
    local remote_free_port = remote_free_port_output[#remote_free_port_output]

    self._local_free_port = provider_utils.find_free_port()

    -- Launch Neovim server and port forward
    local port_forward_opts = ([[-t -L %s:localhost:%s]]):format(self._local_free_port, remote_free_port)
    local remote_server_launch_cmd = ([[XDG_CONFIG_HOME=%s XDG_DATA_HOME=%s XDG_STATE_HOME=%s XDG_CACHE_HOME=%s %s --listen 0.0.0.0:%s --headless]]):format(
      self._remote_xdg_config_path,
      self._remote_xdg_data_path,
      self._remote_xdg_state_path,
      self._remote_xdg_cache_path,
      self:_remote_neovim_binary_path(),
      remote_free_port
    )
    self:_run_code_in_coroutine(function()
      self:run_command(remote_server_launch_cmd, "Launch remote server", port_forward_opts, function()
        self:_reset()
      end)
      self.notifier:notify("Remote server stopped", vim.log.levels.INFO, true)
    end)
    self._remote_server_process_id = self.executor:last_job_id()
    self.notifier:notify("Remote server launched", vim.log.levels.INFO, true)
  end
end

---@private
---Run code in a coroutine
---@param fn function Function to run inside the coroutine
function Provider:_run_code_in_coroutine(fn)
  local co = coroutine.create(function()
    local success, res_or_err = pcall(fn)
    if not success then
      self.logger.error(res_or_err)
      self.notifier:notify("An error occurred. Check logs using :RemoteLog", vim.log.levels.ERROR, true)
    end
  end)
  local success, res_or_err = coroutine.resume(co)
  if not success then
    self.notifier:notify(res_or_err, vim.log.levels.ERROR, true)
  end
end

---@private
---Wait until the server is ready
function Provider:_wait_for_server_to_be_ready()
  local cmd = ("nvim --server localhost:%s --remote-send ':echo<CR>'"):format(self._local_free_port)
  local timeout = 20000 -- Wait for max 20 seconds for server to get ready

  local timer = vim.loop.new_timer()
  assert(timer ~= nil, "Timer object should not be nil")

  local co = coroutine.running()
  local function probe_server_readiness()
    -- This is synchronous but that's fine because the command we are running should immediately return
    local res = vim.fn.system(cmd)
    if res == "" then
      timer:stop()
      timer:close()
      if co ~= nil and coroutine.status(co) == "suspended" then
        coroutine.resume(co)
      end
    else
      vim.defer_fn(probe_server_readiness, 2000)
      if co ~= nil and coroutine.status(co) == "running" then
        coroutine.yield(co)
      end
    end
  end

  -- Start the timer
  timer:start(timeout, 0, function()
    self.notifier:notify(
      ("Server did not come up on local in %s ms. Try again :("):format(timeout),
      vim.log.levels.ERROR,
      true
    )
    timer:stop()
    timer:close()
    error(("Server did not come up on local in %s ms. Try again :("):format(timeout))
  end)
  probe_server_readiness()
end

---@private
---Get preference if the local client should be launched or not
---@return boolean preference Should we launch local client?
function Provider:_get_local_client_start_preference()
  if self._host_config.client_auto_start == nil then
    local choice = self:get_selection({ "Yes", "No", "Yes (always)", "No (never)" }, {
      prompt = "Start local client?",
    })

    -- Handle choices
    if choice == "Yes (always)" then
      self._host_config.client_auto_start = true
      self._config_provider:update_workspace_config(self.unique_host_id, {
        client_auto_start = self._host_config.client_auto_start,
      })
    elseif choice == "No (never)" then
      self._host_config.client_auto_start = false
      self._config_provider:update_workspace_config(self.unique_host_id, {
        client_auto_start = self._host_config.client_auto_start,
      })
    else
      self._host_config.client_auto_start = (choice == "Yes" and true) or false
    end
  end

  return self._host_config.client_auto_start
end

---@private
---Launch local neovim client
function Provider:_launch_local_neovim_client()
  if self:_get_local_client_start_preference() then
    self:_wait_for_server_to_be_ready()

    remote_nvim.config.local_client_config.callback(
      self._local_free_port,
      self._config_provider:get_workspace_config(self.unique_host_id)
    )
  else
    self.notifier:notify("Run :RemoteSessionInfo to find local client command", vim.log.levels.INFO, true)
  end
end

---Launch Neovim
function Provider:launch_neovim()
  self:_run_code_in_coroutine(function()
    self:_setup_workspace_variables()
    self:_setup_remote()
    self:_launch_remote_neovim_server()
    self:_launch_local_neovim_client()
  end)
end

---Stop running Neovim instance (if any)
function Provider:stop_neovim()
  if self:is_remote_server_running() then
    local cmd = ("nvim --server localhost:%s --remote-send ':q<CR>'"):format(self._local_free_port)
    vim.fn.system(cmd)
  end
  self:_reset()
end

---Cleanup remote host
function Provider:clean_up_remote_host()
  self:_run_code_in_coroutine(function()
    self:_verify_connection_to_host()
    local deletion_choices = {
      "Delete neovim workspace (Choose if multiple people use the same user account)",
      "Delete remote neovim from remote host (Nuke it!)",
    }

    local cleanup_choice = self:get_selection(deletion_choices, {
      prompt = "Choose what should be cleaned up?",
    })

    -- Stop neovim first to avoid interference from running plugins and services
    self:stop_neovim()

    if cleanup_choice == deletion_choices[1] then
      self:run_command(
        ("rm -rf %s"):format(self._remote_workspace_id_path),
        "Delete remote nvim workspace from remote host"
      )
    elseif cleanup_choice == deletion_choices[2] then
      self:run_command(("rm -rf %s"):format(self._remote_neovim_home), "Delete remote nvim from remote host")
    end
    self.notifier:notify("Cleanup on remote host completed", vim.log.levels.INFO, true)

    self._config_provider:remove_workspace_config(self.unique_host_id)
  end)
end

---@private
---Handle job completion
---@param desc string Description of the job
function Provider:_handle_job_completion(desc)
  local exit_code = self.executor:last_job_status()
  if exit_code ~= 0 then
    self.notifier:notify(("'%s' failed."):format(desc), vim.log.levels.ERROR, true)
    local co = coroutine.running()
    if co then
      self.logger.error(debug.traceback(co, ("'%s' failed."):format(desc)))
      coroutine.yield()
    else
      error(("'%s' failed"):format(desc))
    end
  else
    self.notifier:notify(("'%s' succeeded."):format(desc), vim.log.levels.INFO)
  end
end

---@protected
---Run command over executor
---@param command string
---@param desc string Description of the command running
function Provider:run_command(command, desc, ...)
  self.logger.fmt_debug("%s: Running %s", self.provider_type, command)
  self.notifier:notify(("'%s' running..."):format(desc))
  self.executor:run_command(command, ...)
  self:_handle_job_completion(desc)
end

---@protected
---Upload data from local to remote host
---@param local_path string Local path
---@param remote_path string Path on the remote
---@param desc string Description of the command running
function Provider:upload(local_path, remote_path, desc)
  self.logger.fmt_debug("%s: Uploading %s to %s on remote", self.provider_type, local_path, remote_path)
  self.notifier:notify(("'%s' upload running..."):format(desc))
  self.executor:upload(local_path, remote_path)
  self:_handle_job_completion(desc)
end

return Provider
