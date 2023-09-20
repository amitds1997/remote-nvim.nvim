describe("SSH Provider", function()
  local SSHProvider = require("remote-nvim.providers.ssh.ssh_provider")
  local assert = require("luassert")
  local stub = require("luassert.stub")
  local remote_nvim = require("remote-nvim")
  local get_workspace_config_stub

  before_each(function()
    get_workspace_config_stub = stub(remote_nvim.session_provider.remote_workspaces_config, "get_workspace_config")

    get_workspace_config_stub.returns({
      provider = "ssh",
      host = "localhost",
      connection_options = "",
      remote_neovim_home = remote_nvim.config.remote_neovim_install_home,
      config_copy = nil,
      client_auto_start = nil,
      workspace_id = "NA",
      neovim_version = "stable",
      os = "Linux",
    })
  end)

  it("should remove 'ssh' prefix from connection options (if present)", function()
    local ssh_provider = SSHProvider("localhost", "ssh localhost -p 3011")
    assert.equals(ssh_provider.conn_opts, "-p 3011")

    -- Even if there are additional whitespaces
    ssh_provider = SSHProvider("localhost", " ssh localhost -p 3011")
    assert.equals(ssh_provider.conn_opts, "-p 3011")
  end)

  it("should remove host name from connection options (if present)", function()
    local ssh_provider = SSHProvider("localhost", "localhost -p 3011")
    assert.equals(ssh_provider.conn_opts, "-p 3011")

    ssh_provider = SSHProvider("localhost", " localhost ")
    assert.equals(ssh_provider.conn_opts, "")
  end)

  it("should remove '-N' ssh option from connection options (if present)", function()
    local ssh_provider = SSHProvider("localhost", "-p 3011 -N")
    assert.equals(ssh_provider.conn_opts, "-p 3011")

    ssh_provider = SSHProvider("localhost", "-N")
    assert.equals(ssh_provider.conn_opts, "")
  end)

  it("should consolidate multiple whitespaces into one in connection options", function()
    local ssh_provider = SSHProvider("localhost", "  -p 3011      -L 2011:localhost:3011    ")
    assert.equals(ssh_provider.conn_opts, "-p 3011 -L 2011:localhost:3011")
  end)

  it("should generate unique host ID correctly", function()
    local ssh_provider = SSHProvider("localhost")
    assert.equals(ssh_provider.unique_host_id, "localhost")

    ssh_provider = SSHProvider("localhost", "-p 3011")
    assert.equals(ssh_provider.unique_host_id, "localhost:3011")

    ssh_provider = SSHProvider("localhost", "-p")
    assert.equals(ssh_provider.unique_host_id, "localhost")
  end)
end)
