---@alias provider_type "ssh"|"devpod"|"local"
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
---@field protected progress_viewer remote-nvim.ui.ProgressView Progress viewer for progress
---@field private _host_config remote-nvim.providers.WorkspaceConfig Host workspace configuration
---@field private _config_provider remote-nvim.ConfigProvider Host workspace configuration
---@field private logger plenary.logger Logger instance
---@field private _setup_running boolean Is the setup running?
---@field protected _neovim_launch_number number Active run number
---@field protected _cleanup_run_number number Active run number
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
---@field protected _remote_working_dir string? Working directory on the remote server
local Provider = require("remote-nvim.middleclass")("Provider")

local Executor = require("remote-nvim.providers.executor")
local provider_utils = require("remote-nvim.providers.utils")
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")
local utils = require("remote-nvim.utils")

---@class remote-nvim.providers.ProviderOpts
---@field host string Host name
---@field conn_opts table? Connection options
---@field progress_view remote-nvim.ui.ProgressView?
---@field unique_host_id string? Unique host ID
---@field provider_type provider_type Provider type
---@field devpod_opts remote-nvim.providers.devpod.DevpodOpts? Devpod options

---Create new provider instance
---@param opts remote-nvim.providers.ProviderOpts Provider options
function Provider:init(opts)
  assert(opts.host ~= nil, "Host must be provided")
  assert(opts.progress_view ~= nil, "Progress viewer cannot be nil")
  self.host = opts.host

  opts.conn_opts = opts.conn_opts or {}
  self.conn_opts = self:_cleanup_conn_options(table.concat(opts.conn_opts, " "))
  self.logger = utils.get_logger()
  self._config_provider = remote_nvim.session_provider:get_config_provider()

  -- These should be overriden in implementing classes
  self.unique_host_id = opts.unique_host_id or self.host
  self.provider_type = "local"
  self.executor = Executor()
  self.progress_viewer = opts.progress_view
  self._cleanup_run_number = 1
  self._neovim_launch_number = 1

  -- Remote configuration parameters
  opts.devpod_opts = opts.devpod_opts or {}
  self._remote_working_dir = opts.devpod_opts.working_dir

  ---@diagnostic disable-next-line: missing-fields
  self._host_config = {}
  self:_reset()
end

---@private
---Clean up connection options
---@param conn_opts string
---@return string cleaned_conn_opts
function Provider:_cleanup_conn_options(conn_opts)
  return conn_opts
end

---@private
---Setup workspace variables
function Provider:_setup_workspace_variables()
  if vim.tbl_isempty(self._config_provider:get_workspace_config(self.unique_host_id)) then
    self.logger.debug("Did not find any existing configuration. Creating one now..")
    self:run_command("echo 'Hello'", "Testing remote connection")
    self._config_provider:add_workspace_config(self.unique_host_id, {
      provider = self.provider_type,
      host = self.host,
      connection_options = self.conn_opts,
      remote_neovim_home = nil,
      config_copy = nil,
      client_auto_start = nil,
      workspace_id = utils.generate_random_string(10),
    })
  else
    self.logger.debug("Found an existing configuration. Re-using the same configuration..")
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

  -- Set remote neovim home path
  if self._host_config.remote_neovim_home == nil then
    self._host_config.remote_neovim_home = self:_get_remote_neovim_home()
    self._config_provider:update_workspace_config(self.unique_host_id, {
      remote_neovim_home = self._host_config.remote_neovim_home,
    })
  end

  -- Set up remaining workspace variables
  self._remote_workspace_id = self._host_config.workspace_id
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

  self:_add_session_info()
end

---@private
---Add session information to the progress viewer
function Provider:_add_session_info()
  local function add_config_info(key, value)
    self.progress_viewer:add_session_node({
      type = "config_node",
      key = key,
      value = value,
    })
  end

  local function add_local_info(key, value)
    self.progress_viewer:add_session_node({
      type = "local_node",
      key = key,
      value = value,
    })
  end

  local function add_remote_info(key, value)
    self.progress_viewer:add_session_node({
      type = "remote_node",
      key = key,
      value = value,
    })
  end

  add_config_info("Plugin log path ", remote_nvim.config.log.filepath)
  add_config_info("Unique host ID", self.unique_host_id)

  add_local_info("OS             ", utils.os_name())
  add_local_info("Neovim version ", utils.neovim_version())

  add_remote_info("OS              ", self._remote_os)
  add_remote_info("Neovim version  ", self._remote_neovim_version)
  add_remote_info("Connection type ", self.provider_type)
  add_remote_info("Host URI        ", self.host)
  add_remote_info("Connection opts ", (self.conn_opts == "" and "<no-extra-options>" or self.conn_opts))
  add_remote_info("Workspace path  ", self._remote_workspace_id_path)
  add_remote_info("Working dir.    ", self._remote_working_dir)
end

---@private
---Reset provider state
function Provider:_reset()
  self._setup_running = false
  self._remote_server_process_id = nil
  self._local_free_port = nil
end

---@protected
---@title string Title for the run
function Provider:start_progress_view_run(title)
  self.progress_viewer:start_run(title)
  self:show_progress_view_window()
end

---Show progress info window
function Provider:show_progress_view_window()
  for _, session in pairs(remote_nvim.session_provider:get_all_sessions()) do
    session:hide_progress_view_window()
  end
  self.progress_viewer:show()
end

---Hide progress info window
function Provider:hide_progress_view_window()
  self.progress_viewer:hide()
end

---Generate host identifer using host and port on host
---@return string host_id Unique identifier for the host
function Provider:get_unique_host_id()
  return self.unique_host_id
end

---@private
---Get OS running on the remote host
---@return string remote_os OS running on remote host
function Provider:_get_remote_os()
  if self._remote_os == nil then
    self:run_command("uname", "Determining OS on remote machine")
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
  end

  return self._remote_os
end

---@private
---Get user's home directory on the remote host
---@return string home_path User's home directory path
function Provider:_get_remote_neovim_home()
  if self._remote_neovim_home == nil then
    self:run_command("echo $HOME", "Determining remote user's home directory")
    local cmd_out_lines = self.executor:job_stdout()
    self._remote_neovim_home = utils.path_join(self._remote_is_windows, cmd_out_lines[#cmd_out_lines], ".remote-nvim")
  end

  return self._remote_neovim_home
end

---@protected
---Get selection choice
---@param choices string[]
---@param selection_opts table
---@return string selected_choice Selected choice
function Provider:get_selection(choices, selection_opts)
  local section_node = vim.schedule(function()
    return self.progress_viewer:add_progress_node({
      type = "section_node",
      text = ("Choice: %s"):format(selection_opts.prompt),
    })
  end)
  local choice = provider_utils.get_selection(choices, selection_opts)

  -- If the choice fails, we cannot move further so we stop the coroutine executing
  if choice == nil then
    if self._setup_running then
      self._setup_running = false
    end
    self.progress_viewer:add_progress_node({
      type = "stdout_node",
      status = "failed",
      set_parent_status = not self:is_remote_server_running(),
      text = "No selection made.",
    }, section_node)
    self.progress_viewer:update_status("failed", false, section_node)
    local co = coroutine.running()
    if co then
      return coroutine.yield(nil)
    else
      error("Choice is necessary to proceed.")
    end
  else
    self.progress_viewer:add_progress_node({
      type = "stdout_node",
      text = ("Choice selected: %s"):format(choice),
    }, section_node)
    self.progress_viewer:update_status("success", false, section_node)
    return choice
  end
end

---@private
---Get neovim version to be run on the remote host
---@return string neovim_version Version running on the remote host
function Provider:_get_remote_neovim_version_preference()
  if self._remote_neovim_version == nil then
    local valid_neovim_versions = provider_utils.get_valid_neovim_versions()
    local version_map = {}
    local possible_choices = {}
    for _, version in ipairs(valid_neovim_versions) do
      version_map[version.tag] = version.commit

      if version.tag ~= "stable" then
        table.insert(possible_choices, version.tag)
      end
    end

    -- Get client version
    local client_version = "v" .. utils.neovim_version()

    self._remote_neovim_version = self:get_selection(possible_choices, {
      prompt = "Which Neovim version should be installed on remote?",
      format_item = function(version)
        local choice_str = (version ~= "nightly" and ("Neovim %s "):format(version)) or "Nightly version "

        if version_map["stable"] == version_map[version] then
          choice_str = choice_str .. "(stable release) "
        end

        if (version == client_version) or (vim.endswith(client_version, "dev") and version == "nightly") then
          choice_str = choice_str .. "(locally installed)"
        end

        return choice_str
      end,
    })
  end

  return self._remote_neovim_version
end

---@return string? free_port Port used on local to connect with Neovim server
function Provider:get_local_neovim_server_port()
  return self._local_free_port
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
    self:run_command(table.concat(mkdirs_cmds, " && "), "Creating custom neovim directories on remote")

    -- Copy things required on remote
    self:upload(
      vim.fn.fnamemodify(remote_nvim.default_opts.neovim_install_script_path, ":h"),
      self._remote_neovim_home,
      "Copying plugin scripts onto remote"
    )

    ---If we have custom scripts specified, copy them over
    if remote_nvim.default_opts.neovim_install_script_path ~= remote_nvim.config.neovim_install_script_path then
      self:upload(
        remote_nvim.config.neovim_install_script_path,
        self._remote_scripts_path,
        "Copying custom install scripts specified by user"
      )
    end

    -- Set correct permissions and install Neovim
    local install_neovim_cmd = ([[chmod +x %s && %s -v %s -d %s]]):format(
      self._remote_neovim_install_script_path,
      self._remote_neovim_install_script_path,
      self._remote_neovim_version,
      self._remote_neovim_home
    )
    self:run_command(install_neovim_cmd, "Installing Neovim (if required)")

    -- Upload user neovim config, if necessary
    if self:_get_neovim_config_upload_preference() then
      self:upload(
        remote_nvim.config.neovim_user_config_path,
        self._remote_xdg_config_path,
        "Copying your Neovim configuration files onto remote"
      )
    end

    self._setup_running = false
  else
    vim.notify("Another instance of setup is already running. Wait for it to complete", vim.log.levels.WARN)
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
    self:run_command(free_port_on_remote_cmd, "Searching for free port on the remote machine")
    local remote_free_port_output = self.executor:job_stdout()
    local remote_free_port = remote_free_port_output[#remote_free_port_output]
    self.logger.fmt_debug("[%s][%s] Remote free port: %s", self.provider_type, self.unique_host_id, remote_free_port)

    self._local_free_port = provider_utils.find_free_port()
    self.logger.fmt_debug(
      "[%s][%s] Local free port: %s",
      self.provider_type,
      self.unique_host_id,
      self._local_free_port
    )

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

    -- If we have a specified working directory, we launch there
    if self._remote_working_dir then
      remote_server_launch_cmd = ("%s --cmd ':cd %s'"):format(remote_server_launch_cmd, self._remote_working_dir)
    end

    self:_run_code_in_coroutine(function()
      self:run_command(
        remote_server_launch_cmd,
        "Launching Neovim server on the remote machine",
        port_forward_opts,
        function(node)
          return function(exit_code)
            self.progress_viewer:update_status(exit_code == 0 and "success" or "failed", true, node)
            if exit_code == 0 then
              self:hide_progress_view_window()
            else
              self:show_progress_view_window()
            end
            self:_reset()
          end
        end
      )
      vim.notify("Remote server stopped", vim.log.levels.INFO)
    end, "Launching Remote Neovim server")
    self._remote_server_process_id = self.executor:last_job_id()
    if self:is_remote_server_running() then
      self.progress_viewer:add_session_node({
        type = "info_node",
        value = ("Remote server available at localhost:%s"):format(self._local_free_port),
      })
    end
  end
end

---@protected
---Run code in a coroutine
---@param fn function Function to run inside the coroutine
---@param desc string Description of operation being performed
function Provider:_run_code_in_coroutine(fn, desc)
  local co = coroutine.create(function()
    xpcall(fn, function(err)
      self.logger.error(debug.traceback(coroutine.running(), ("'%s' failed"):format(desc)), err)
      vim.notify("An error occurred. Check logs using :RemoteLog", vim.log.levels.ERROR)
    end)
  end)
  local success, res_or_err = coroutine.resume(co)
  if not success then
    self.logger.error(debug.traceback(co, ("'%s' failed"):format(desc)), res_or_err)
    vim.notify("An error occurred. Check logs using :RemoteLog", vim.log.levels.ERROR)
  end
end

---@private
---Wait until the server is ready
function Provider:_wait_for_server_to_be_ready()
  local cmd = ("nvim --server localhost:%s --remote-send ':echo<CR>'"):format(self._local_free_port)
  local timeout = 20000 -- Wait for max 20 seconds for server to get ready

  local timer = utils.uv.new_timer()
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
    vim.notify(("Server did not come up on local in %s ms. Try again :("):format(timeout), vim.log.levels.ERROR)
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
  ---@type remote-nvim.providers.WorkspaceConfig
  local workspace_config = self._config_provider:get_workspace_config(self.unique_host_id)
  local should_start_client = workspace_config.client_auto_start

  if should_start_client == nil then
    local choice = self:get_selection({ "Yes", "No", "Yes (always)", "No (never)" }, {
      prompt = "Launch local Neovim client?",
    })

    -- Handle choices
    if choice == "Yes (always)" then
      should_start_client = true
      self._host_config.client_auto_start = should_start_client
      self._config_provider:update_workspace_config(self.unique_host_id, {
        client_auto_start = should_start_client,
      })
    elseif choice == "No (never)" then
      should_start_client = false
      self._host_config.client_auto_start = should_start_client
      self._config_provider:update_workspace_config(self.unique_host_id, {
        client_auto_start = should_start_client,
      })
    else
      should_start_client = (choice == "Yes" and true) or false
    end
  end

  return should_start_client
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
    self:show_progress_view_window()
    self.progress_viewer:switch_to_pane("session_info", true)
  end
end

---@protected
---@param start_run boolean? Should a new run be started
function Provider:_launch_neovim(start_run)
  start_run = start_run or false
  if not self:is_remote_server_running() then
    self.logger.fmt_debug(("[%s][%s] Starting remote neovim launch"):format(self.provider_type, self.unique_host_id))
    if start_run then
      self:start_progress_view_run(("Launch Neovim (Run no. %s)"):format(self._neovim_launch_number))
      self._neovim_launch_number = self._neovim_launch_number + 1
    end
    self:_setup_workspace_variables()
    self:_setup_remote()
    self:_launch_remote_neovim_server()
    self:_launch_local_neovim_client()
    self.logger.fmt_debug(("[%s][%s] Completed remote neovim launch"):format(self.provider_type, self.unique_host_id))
  else
    self:_launch_local_neovim_client()
    self:show_progress_view_window()
    self.progress_viewer:switch_to_pane("session_info", true)
  end
end

---Launch Neovim
function Provider:launch_neovim()
  self:_run_code_in_coroutine(function()
    self:_launch_neovim()
  end, "Setting up Neovim on remote host")
end

---Stop running Neovim instance (if any)
function Provider:stop_neovim()
  if self:is_remote_server_running() then
    vim.system(
      { "nvim", "--server", ("localhost:%s"):format(self._local_free_port), "--remote-send", ":qall!<CR>" },
      { text = true },
      function(res)
        if res.code == 0 then
          vim.schedule(function()
            self:hide_progress_view_window()
          end)
          self:_reset()
        end
      end
    )
  end
end

---@protected
function Provider:_clean_up_remote_host()
  self:start_progress_view_run(("Remote cleanup (Run number %s)"):format(self._cleanup_run_number))
  self._cleanup_run_number = self._cleanup_run_number + 1
  self:_setup_workspace_variables()
  local deletion_choices = {
    "Delete neovim workspace (Choose if multiple people use the same user account)",
    "Delete remote neovim from remote host (Nuke it!)",
  }

  local cleanup_choice = self:get_selection(deletion_choices, {
    prompt = "Choose what should be cleaned up?",
  })

  -- Stop neovim first to avoid interference from running plugins and services
  self:stop_neovim()

  local exit_cb = function(node)
    return function(exit_code)
      self.progress_viewer:update_status(exit_code == 0 and "success" or "failed", true, node)
      if exit_code == 0 then
        self:hide_progress_view_window()
      else
        self:show_progress_view_window()
      end
      self:_reset()
    end
  end

  if cleanup_choice == deletion_choices[1] then
    self:run_command(
      ("rm -rf %s"):format(self._remote_workspace_id_path),
      ("Deleting workspace %s from remote machine"):format(self._remote_workspace_id_path),
      nil,
      exit_cb
    )
  elseif cleanup_choice == deletion_choices[2] then
    self:run_command(
      ("rm -rf %s"):format(self._remote_neovim_home),
      "Delete remote neovim created directories from remote machine",
      nil,
      exit_cb
    )
  end
  vim.notify(("Cleanup on remote host '%s' completed"):format(self.host), vim.log.levels.INFO)

  self._config_provider:remove_workspace_config(self.unique_host_id)
  self:hide_progress_view_window()
end

---Cleanup remote host
function Provider:clean_up_remote_host()
  self:_run_code_in_coroutine(function()
    self:_clean_up_remote_host()
  end, ("Cleaning up '%s' host"):format(self.host))
end

---@private
---Handle job completion
---@param desc string Description of the job
---@return integer exit_code Exit code of the job being handled
function Provider:_handle_job_completion(desc)
  local exit_code = self.executor:last_job_status()
  if exit_code ~= 0 then
    self.progress_viewer:update_status("failed", true)
    if self._setup_running then
      self._setup_running = false
    end
    local co = coroutine.running()
    if co then
      self.logger.error(
        debug.traceback(co, ("'%s' failed."):format(desc)),
        ("\n\nFAILED JOB OUTPUT (SO FAR)\n%s"):format(table.concat(self.executor:job_stdout(), "\n"))
      )
      coroutine.yield(exit_code)
    else
      error(("'%s' failed"):format(desc))
    end
  else
    self.progress_viewer:update_status("success")
  end
  return exit_code
end

---@protected
---Run command over executor
---@param command string
---@param desc string Description of the command running
---@param extra_opts string? Extra options to pass to the underlying command
---@param exit_cb function? Exit callback to execute
function Provider:run_command(command, desc, extra_opts, exit_cb)
  self.logger.fmt_debug("[%s][%s] Running %s", self.provider_type, self.unique_host_id, command)
  local section_node = self.progress_viewer:add_progress_node({
    text = desc,
    type = "section_node",
  })
  self.progress_viewer:add_progress_node({
    text = command,
    type = "command_node",
  }, section_node)
  -- Allow correct update of active job in ProgressView
  if exit_cb ~= nil then
    exit_cb = exit_cb(section_node)
  end
  self.executor:run_command(command, {
    additional_conn_opts = extra_opts,
    exit_cb = exit_cb,
    stdout_cb = self:_add_stdout_to_progress_view_window(section_node),
  })
  self:_handle_job_completion(desc)
end

---@private
---Add stdout information to progress viewer
---@param node NuiTree.Node Section node on which the output nodes would be attached
function Provider:_add_stdout_to_progress_view_window(node)
  return function(stdout_chunk)
    if stdout_chunk and stdout_chunk ~= "" then
      for _, chunk in ipairs(vim.split(stdout_chunk, "\n", { plain = true, trimempty = true })) do
        self.progress_viewer:add_progress_node({
          type = "stdout_node",
          text = chunk,
        }, node)
      end
    end
  end
end

---@protected
---Upload data from local to remote host
---@param local_path string Local path
---@param remote_path string Path on the remote
---@param desc string Description of the command running
function Provider:upload(local_path, remote_path, desc)
  self.logger.fmt_debug(
    "[%s][%s] Uploading %s to %s on remote",
    self.provider_type,
    self.unique_host_id,
    local_path,
    remote_path
  )
  if not require("plenary.path"):new({ local_path }):exists() then
    error(("Local path '%s' does not exist"):format(local_path))
  end
  local section_node = self.progress_viewer:add_progress_node({
    text = desc,
    type = "section_node",
  })
  self.executor:upload(local_path, remote_path, {
    stdout_cb = self:_add_stdout_to_progress_view_window(section_node),
  })
  self:_handle_job_completion(desc)
end

return Provider
