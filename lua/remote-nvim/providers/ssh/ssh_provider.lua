local ProviderInterface = require("remote-nvim.providers.provider_interface")

---@class SSHProvider
local SSHProvider = {}
SSHProvider.__index = SSHProvider

setmetatable(SSHProvider, {
  __index = ProviderInterface,
  __call = function(cls, ...)
    return cls.new(...)
  end,
})

function SSHProvider:new()
  local instance = setmetatable({}, SSHProvider)
  -- Needs to handle correcting ssh_config_options passed down to it. SSHExecutor would not deal with it. Also, it
  -- should be a string and also not contain ssh prefix. And the host name.
  return instance
end

function SSHProvider:connect()
  return coroutine.create(function()
    -- Implement connecting to the remote system for SSH using coroutines
    -- You can use io.read or any other method to prompt the user for SSH credentials
    -- Use coroutine.resume(coroutine.running(), true) upon successful connection
    -- Use coroutine.resume(coroutine.running(), nil, error_message) upon failure
  end)
end

function SSHProvider:collectConnectionInput()
  return coroutine.create(function()
    -- Implement collecting connection input from the user using coroutines
    -- Use coroutine.resume(coroutine.running(), input_value) upon successful input collection
    -- Use coroutine.resume(coroutine.running(), nil, error_message) upon failure
  end)
end

function SSHProvider:setupRemoteSystem()
  return coroutine.create(function()
    -- Implement any setup actions for SSH after successful connection using coroutines
    -- Use coroutine.resume(coroutine.running(), true) upon successful setup
    -- Use coroutine.resume(coroutine.running(), nil, error_message) upon failure
  end)
end

function SSHProvider:closeConnection()
  return coroutine.create(function()
    -- Implement closing the SSH connection using coroutines
    -- Use coroutine.resume(coroutine.running(), true) upon successful connection closure
    -- Use coroutine.resume(coroutine.running(), nil, error_message) upon failure
  end)
end

function SSHProvider:upload(localPath, remotePath)
  return coroutine.create(function()
    -- Implement uploading a file from localPath to remotePath using coroutines
    -- Use coroutine.resume(coroutine.running(), true) upon successful upload
    -- Use coroutine.resume(coroutine.running(), nil, error_message) upon failure
  end)
end

function SSHProvider:download(remotePath, localPath)
  return coroutine.create(function()
    -- Implement downloading a file from remotePath to localPath using coroutines
    -- Use coroutine.resume(coroutine.running(), true) upon successful download
    -- Use coroutine.resume(coroutine.running(), nil, error_message) upon failure
  end)
end

function SSHProvider:executeCommand(command)
  return coroutine.create(function()
    -- Implement executing a command on the remote system using coroutines
    -- Use coroutine.resume(coroutine.running(), true) upon successful execution
    -- Use coroutine.resume(coroutine.running(), nil, error_message) upon failure
  end)
end

function SSHProvider:getUserInput(message)
  return coroutine.create(function()
    -- Implement prompting the user for input using coroutines
    -- Use coroutine.resume(coroutine.running(), user_input) upon successful input
    -- Use coroutine.resume(coroutine.running(), nil, error_message) upon failure
  end)
end

return SSHProvider
