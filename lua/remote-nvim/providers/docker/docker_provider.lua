---@class remote-nvim.providers.docker.DockerProvider: remote-nvim.providers.Provider
---@field super remote-nvim.providers.Provider
local DockerProvider = require("remote-nvim.providers.provider"):subclass("DockerProvider")

local DockerExecutor = require("remote-nvim.providers.docker.docker_executor")
local Notifier = require("remote-nvim.providers.notifier")

function DockerProvider:init(host, conn_opts)
  DockerProvider.super:init(host, conn_opts)

  self.provider_type = "docker"
  self.executor = DockerExecutor(self.host, self.conn_opts)
  self.notifier = Notifier({
    title = (("Docker: %s"):format(self.unique_host_id)),
  })
end

return DockerProvider
