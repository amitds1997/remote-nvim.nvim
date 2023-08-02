---@class ExecutorInterface

---@type ExecutorInterface
local ExecutorInterface = {}

function ExecutorInterface:uploadFile(localPath, remotePath)
  error("uploadFile must be implemented in the executor.")
end

function ExecutorInterface:downloadFile(remotePath, localPath)
  error("downloadFile must be implemented in the executor.")
end

function ExecutorInterface:executeCommand(command)
  error("executeCommand must be implemented in the executor.")
end

function ExecutorInterface:captureStdout()
  error("captureStdout must be implemented in the executor.")
end

function ExecutorInterface:captureStderr()
  error("captureStderr must be implemented in the executor.")
end

function ExecutorInterface:resetState()
  error("resetState must be implemented in the executor.")
end

function ExecutorInterface:onCompletion(callback)
  error("onCompletion must be implemented in the executor.")
end

function ExecutorInterface:onPreExecution(callback)
  error("onPreExecution must be implemented in the executor.")
end

function ExecutorInterface:getStatus()
  error("getStatus must be implemented in the executor.")
end

function ExecutorInterface:isSuccessful()
  error("isSuccessful must be implemented in the executor.")
end

function ExecutorInterface:isCompleted()
  error("isCompleted must be implemented in the executor.")
end

function ExecutorInterface:cancel()
  error("cancel must be implemented in the executor.")
end

function ExecutorInterface:monitorProgress(callback)
  error("monitorProgress must be implemented in the executor.")
end

function ExecutorInterface:handleError(callback)
  error("handleError must be implemented in the executor.")
end

function ExecutorInterface:setTimeout(timeout)
  error("setTimeout must be implemented in the executor.")
end

function ExecutorInterface:getState()
  error("getState must be implemented in the executor.")
end

function ExecutorInterface:provideInput(input)
  error("provideInput must be implemented in the executor.")
end

return ExecutorInterface
