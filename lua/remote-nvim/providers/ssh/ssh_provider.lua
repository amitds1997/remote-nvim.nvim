local ProviderInterface = require("remote-nvim.providers.provider_interface")
local RemoteNeovimConfig = require("remote-nvim")
local SSHExecutor = require("remote-nvim.providers.ssh.ssh_executor")
local SSHUtils = require("remote-nvim.providers.ssh.ssh_utils")
local utils = require("remote-nvim.utils")

---@alias os_type "macOS"|"Windows"|"Linux"

---@class NeovimSSHProvider
---@field remote_host string Remote host to connect to
---@field connection_options string Connection options needed to connect to remote host
---@field ssh_executor SSHRemoteExecutor Executor over which jobs will be executed
---@field remote_neovim_home string Remote path on which remote neovim will install things
---@field unique_host_identifier string Unique identifier for the host
---@field host_workspace_config WorkspaceConfig Workspace config for remote host
---@field local_nvim_install_script_path string Local path where Neovim installation script is stored
---@field local_nvim_user_config_path string Local path where Neovim configuration files are stored
---@field local_nvim_scripts_path string Local path where Remote Neovim scripts are stored
---@field remote_os os_type Remote host's OS
---@field is_remote_windows boolean Flag indicating whether the remote system is windows
local NeovimSSHProvider = {}
NeovimSSHProvider.__index = NeovimSSHProvider

setmetatable(NeovimSSHProvider, {
  __index = ProviderInterface,
  __call = function(cls, ...)
    return cls.new(...)
  end,
})

---@param host string Remote host name
---@param connection_options? string|table Connection options to connect with the host
function NeovimSSHProvider:new(host, connection_options)
  ---@type NeovimSSHProvider
  local instance = setmetatable({}, NeovimSSHProvider)

  assert(host ~= nil, "Host cannot be nil")
  instance.remote_host = host

  if connection_options ~= nil then
    if type(connection_options) == "table" then
      instance.connection_options = table.concat(connection_options, " ")
    else
      instance.connection_options = connection_options
    end
  else
    instance.connection_options = ""
  end
  instance.connection_options = SSHUtils.cleanUpConnOpts(instance.remote_host, instance.connection_options)
  instance.ssh_executor = SSHExecutor:new(instance.remote_host, instance.connection_options)

  -- Neovim configuration variables
  instance.remote_neovim_home = RemoteNeovimConfig.config.remote_neovim_install_home
  instance.unique_host_identifier = SSHUtils.getHostIdentifier(instance.remote_host, instance.connection_options)

  -- Workspace configuration variables
  instance.host_workspace_config = nil
  instance.local_nvim_install_script_path = RemoteNeovimConfig.config.neovim_install_script_path
  instance.local_nvim_user_config_path = RemoteNeovimConfig.config.neovim_user_config_path
  instance.local_nvim_scripts_path = utils.path_join(utils.is_windows, utils.get_package_root(), "scripts")

  -- State management variables
  instance.remote_os = nil
  instance.is_remote_windows = nil

  return instance
end

---@private
---Get the OS of the remote SSH host
---@return os_type os_name Name of the OS running on remote host
function NeovimSSHProvider:determineRemoteOS()
  self.ssh_executor:runCommand("uname")
  local stdout_lines = self.ssh_executor:getStdout()
  local remote_os = stdout_lines[#stdout_lines]

  if remote_os == "Linux" then
    self.remote_os = "Linux"
  elseif remote_os == "Darwin" then
    self.remote_os = "macOS"
  end

  -- Time to ask this question to the user
  if self.remote_os == nil then
    local os_options = {
      "Linux",
      "macOS",
      "Windows",
    }
    utils.get_user_selection(os_options, {
      prompt = "Select your remote host's OS: ",
      format_item = function(item)
        return "Remote host is running " .. item
      end,
    }, function(choice)
      self.remote_os = choice
    end)
  end

  self.is_remote_windows = self.remote_os == "Windows" and true or false
  return self.remote_os
end

---@private
function NeovimSSHProvider:determineRemoteNeovimVersion()
  -- Time to ask user which Neovim version they want to deploy
  if self.remote_neovim_version == nil then
    -- Get all versions that are greater than minimum neovim version requirements
    local valid_neovim_versions = utils.get_neovim_versions()

    -- Get client version
    local api_info = vim.version()
    local client_version = "v" .. table.concat({ api_info.major, api_info.minor, api_info.patch }, ".")

    utils.get_user_selection(valid_neovim_versions, {
      prompt = "What Neovim version should be installed on remote host?",
      format_item = function(ver)
        if ver == client_version then
          return "Install Neovim " .. ver .. " (Your client version)"
        end
        return "Install Neovim " .. ver
      end,
    }, function(choice)
      self.remote_neovim_version = choice
    end)
  end
  return self.remote_neovim_version
end

---@private
function NeovimSSHProvider:setUpWorkspaceConfig()
  if not RemoteNeovimConfig.host_workspace_config:host_record_exists(self.unique_host_identifier) then
    local remote_os = self:determineRemoteOS()
    local neovim_version = self:determineRemoteNeovimVersion()
    RemoteNeovimConfig.host_workspace_config:add_host_config(self.unique_host_identifier, {
      provider = "ssh",
      connection_options = self.connection_options,
      remote_neovim_home = self.remote_neovim_home,
      os = remote_os,
      neovim_version = neovim_version,
      workspace_id = utils.generate_random_string(10),
    })
  end
  self.host_workspace_config =
    RemoteNeovimConfig.host_workspace_config:get_workspace_config(self.unique_host_identifier)

  -- Set OS and Neovim versions to recorded versions
  self.remote_os = self.host_workspace_config.os
  self.remote_neovim_version = self.host_workspace_config.neovim_version

  local install_script_path_components = utils.split(self.local_nvim_install_script_path, utils.is_windows)

  -- Setup workspace configurations
  self.workspace_id = self.host_workspace_config.workspace_id
  self.connection_options = self.connection_options or self.host_workspace_config.connection_options
  self.remote_neovim_home = self.host_workspace_config.remote_neovim_home
  self.remote_workspaces_path = utils.path_join(self.is_remote_windows, self.remote_neovim_home, "workspaces")
  self.remote_scripts_path = utils.path_join(self.is_remote_windows, self.remote_neovim_home, "scripts")
  self.remote_workspace_id_path =
    utils.path_join(self.is_remote_windows, self.remote_workspaces_path, self.workspace_id)
  self.remote_xdg_config_path = utils.path_join(self.is_remote_windows, self.remote_workspace_id_path, ".config")
  self.remote_neovim_config_path = utils.path_join(self.is_remote_windows, self.remote_xdg_config_path, "nvim")
  self.remote_neovim_install_script_path = utils.path_join(
    self.is_remote_windows,
    self.remote_scripts_path,
    install_script_path_components[#install_script_path_components]
  )
end

function NeovimSSHProvider:testConnection()
  self.ssh_executor:runCommand('echo "OK"')
  if self.ssh_executor.exit_code ~= 0 then
    error("Could not connect to the remote host: " .. self.unique_host_identifier)
  end
end

function NeovimSSHProvider:copyOverNeovimConfig()
  local should_copy_over_config = false
  utils.get_user_selection({ "Yes", "No" }, {
    prompt = "Copy Neovim config at " .. self.local_nvim_user_config_path .. " ?",
  }, function(choice)
    should_copy_over_config = choice == "Yes" and true or false
  end)

  if should_copy_over_config then
    self.ssh_executor:upload(self.local_nvim_user_config_path, self.remote_neovim_config_path)
  end
end

function NeovimSSHProvider:setupRemote()
  local thread = coroutine.create(function()
    self:testConnection()
    self:setUpWorkspaceConfig()

    -- Create neovim directories on the remote server
    self.ssh_executor:runCommand("mkdir -p " .. self.remote_workspaces_path)
    self.ssh_executor:runCommand("mkdir -p " .. self.remote_scripts_path)

    -- We now copy over all scripts that we have onto the remote server
    self.ssh_executor:upload(self.local_nvim_scripts_path, self.remote_neovim_home)
    self.ssh_executor:upload(self.local_nvim_install_script_path, self.remote_scripts_path)

    -- Make the installation script executable and run it to install the specified version of Neovim
    self.ssh_executor:runCommand("chmod +x " .. self.remote_neovim_install_script_path)
    self.ssh_executor:runCommand(
      self.remote_neovim_install_script_path
        .. " -v "
        .. self.remote_neovim_version
        .. " -d "
        .. self.remote_neovim_home
    )

    -- Time to copy over Neovim configuration (if needed)
    self.ssh_executor:runCommand("mkdir -p " .. self.remote_xdg_config_path)
    self:copyOverNeovimConfig()
  end)

  local success, err = coroutine.resume(thread)
  if not success then
    print("Coroutine failed because " .. err)
  end
  return self
end

return NeovimSSHProvider
