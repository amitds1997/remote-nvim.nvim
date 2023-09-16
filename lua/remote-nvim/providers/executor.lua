---@class Object
---@field subclass function
---@field super table

---@class Executor: Object
---@field host string Host name
---@field conn_opts string Connection options (passed when connecting)
---@field _job_id integer|nil Job ID of the current job
---@field _job_exit_code integer|nil Exit code of the job on the executor
---@field _job_stdout string[] Job output (if job is running)
local Executor = require("remote-nvim.middleclass")("Executor")

---Initialize executor instance
---@param host string Host name
---@param conn_opts string Connection options (passed when connecting)
function Executor:initialize(host, conn_opts)
  self.host = host
  self.conn_opts = conn_opts

  self._job_id = nil
  self._job_exit_code = nil
  self._job_stdout = {}
end

---@protected
---Reset executor state
function Executor:reset()
  self._job_id = nil
  self._job_exit_code = nil
  self._job_stdout = {}
end

---Upload data to the host
---@param localSrcPath string Local path from which data would be uploaded
---@param remoteDestPath string Path on host where data would be uploaded
---@param cb? function Callback to call on upload completion
-- selene: allow(unused_variable)
function Executor:upload(localSrcPath, remoteDestPath, cb)
  error("Not implemented")
end

---Download data from host
---@param remoteSrcPath string Remote path where data is located
---@param localDestPath string Local path where data will be downloaded
---@param cb function Callback to call on download completion
-- selene: allow(unused_variable)
function Executor:download(remoteSrcPath, localDestPath, cb)
  error("Not implemented")
end

---Run command on host
---@param command string Command to run on the remote host
---@param cb? function Callback to call on job completion
function Executor:run_command(command, cb)
  return self:run_executor_job(command, cb)
end

---@protected
---@async
---Run the job over executor
---@param command string Command which should be started as a job
---@param cb? function Callback to be called on job completion
function Executor:run_executor_job(command, cb)
  local co = coroutine.running()

  self:reset() -- Reset job internal state variables
  self._job_id = vim.fn.jobstart(command, {
    pty = true,
    on_stdout = function(_, data_chunk)
      self:process_stdout(data_chunk)
    end,
    on_exit = function(_, exit_code)
      self:process_job_completion(exit_code)
      if cb ~= nil then
        cb()
      end
      if co ~= nil then
        coroutine.resume(co)
      end
    end,
  })

  if co ~= nil then
    return coroutine.yield(self)
  end

  return self
end

---@protected
---Process output generated by stdout
---@param output_chunks string[]
function Executor:process_stdout(output_chunks)
  for _, chunk in ipairs(output_chunks) do
    local cleaned_chunk = chunk:gsub("\r", "\n")
    table.insert(self._job_stdout, cleaned_chunk)
  end
end

---@protected
---Process job completion
---@param exit_code number Exit code of the job running on the executor
function Executor:process_job_completion(exit_code)
  self._job_exit_code = exit_code
end

---Get last job's status (exit code)
function Executor:last_job_status()
  assert(self._job_id ~= nil, "No jobs running")
  return self._job_exit_code or vim.fn.jobwait({ self._job_id }, 0)[1]
end

---Cancel running job on executor
---@return number status_code Returns 1 for valid job id, 0 for exited, stopped or invalid jobs
function Executor:cancel_running_job()
  assert(self._job_id ~= nil, "No running job to be cancelled")
  return vim.fn.jobstop(self._job_id)
end

---Get output generated by job running on the executor
---@return string[] stdout Job output separated by new lines
function Executor:job_stdout()
  return vim.split(vim.trim(table.concat(self._job_stdout, "")), "\n")
end

return Executor
