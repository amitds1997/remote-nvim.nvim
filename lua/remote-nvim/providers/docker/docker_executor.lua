---@class remote-nvim.providers.docker.DockerExecutor: remote-nvim.providers.Executor
---@field super remote-nvim.providers.Executor
local DockerExecutor = require("remote-nvim.providers.executor"):subclass("DockerExecutor")
local remote_neovim = require("remote-nvim")

function DockerExecutor:init(host, conn_opts)
  DockerExecutor.super:init(host, conn_opts)

  self.copy_conn_opts = self.conn_opts
  self.docker_binary = remote_neovim.config.docker_config.docker_binary
end

function DockerExecutor:upload(localSrcPath, remoteDestPath, cb)
  local remotePath = ("%s:%s"):format(self.host, remoteDestPath)
  local upload_command = ("%s cp %s %s %s"):format(self.docker_binary, self.copy_conn_opts, localSrcPath, remotePath)
  return self:run_executor_job(upload_command, cb)
end

function DockerExecutor:download(remoteSrcPath, localDescPath, cb)
  local remotePath = ("%s:%s"):format(self.host, remoteSrcPath)
  local download_command = ("%s cp %s %s %s"):format(self.docker_binary, self.copy_conn_opts, remotePath, localDescPath)
  return self:run_executor_job(download_command, cb)
end

function DockerExecutor:run_command(command, additional_conn_opts, cb)
  local conn_opts = additional_conn_opts == nil and self.conn_opts or (self.conn_opts .. " " .. additional_conn_opts)
  local host_conn_opts = conn_opts == "" and self.host or conn_opts .. " " .. self.host

  -- Shell escape the passed command
  local run_command = ("%s exec %s sh -c '%s'"):format(self.docker_binary, host_conn_opts, command)
  return self:run_executor_job(run_command, cb)
end

return DockerExecutor
