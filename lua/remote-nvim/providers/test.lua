local SSHProvider = require("remote-nvim.providers.ssh.ssh_provider")
-- local SSHUtils = require("remote-nvim.providers.ssh.ssh_utils")
-- local ssh_executor = require("remote-nvim.providers.ssh.ssh_executor")
-- local utils        = require("remote-nvim.utils")
local M = {}

function M.test()
  -- local provider = SSHProvider:new("vscode-remote-try-node.devpod")
  local provider = SSHProvider:new("colima")
  -- local provider = SSHProvider:new("test@localhost", "-p 9111")
  -- provider:connect()
  provider:setupRemote()
  -- coroutine.resume(provider:connect())
  -- vim.fn.jobwait({provider.ssh_executor.job_id})
  -- local co = provider:connect()
  -- vim.notify("Working")

  -- local SSHRunner = ssh_executor:new("vscode-remote-try-node.devpod", "")
  -- local SSHRunner = ssh_executor:new("test@localhost", "-p 9111")
  -- local co = coroutine.create(function()
  --   SSHRunner:runCommand("ech 'OK'")
  --   vim.notify("[OUT] " .. SSHRunner:getStdout())

  --   SSHRunner:runCommand("echo 'Magic'")
  --   vim.notify("[OUT] " .. SSHRunner:getStdout())
  -- end)
  -- SSHRunner.coroutine_thread = co
  -- coroutine.resume(co)
  -- print(vim.inspect(provider))
  -- print(utils.get_package_root())

  -- instance.local_nvim_scripts_path = utils.path_join(utils.is_windows, utils.get_package_root(), "scripts")
  -- local curl = require("plenary.curl")
  -- local res = curl.get(
  --   "https://api.github.com/repos/neovim/neovim/releases", {
  --     headers = {
  --       accept = "application/vnd.github+json"
  --     }
  --   }
  -- )
  -- print(vim.inspect(vim.fn.json_decode(res).json))
end

return M
