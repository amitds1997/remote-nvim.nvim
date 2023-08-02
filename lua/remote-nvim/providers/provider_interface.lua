local ProviderInterface = {}

function ProviderInterface:connect()
  error("connect must be implemented in the provider.")
end

function ProviderInterface:collectConnectionInput()
  error("collectConnectionInput must be implemented in the provider.")
end

function ProviderInterface:setupRemoteSystem()
  error("setupRemoteSystem must be implemented in the provider.")
end

function ProviderInterface:closeConnection()
  error("closeConnection must be implemented in the provider.")
end

function ProviderInterface:upload(localPath, remotePath)
  error("upload must be implemented in the provider.")
end

function ProviderInterface:download(remotePath, localPath)
  error("download must be implemented in the provider.")
end

function ProviderInterface:executeCommand(command)
  error("executeCommand must be implemented in the provider.")
end

function ProviderInterface:getUserInput(message)
  error("getUserInput must be implemented in the provider.")
end

return ProviderInterface
