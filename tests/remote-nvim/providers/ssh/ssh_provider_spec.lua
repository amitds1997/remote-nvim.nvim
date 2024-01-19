describe("SSH Provider", function()
  local SSHProvider = require("remote-nvim.providers.ssh.ssh_provider")
  local assert = require("luassert.assert")

  it("should remove 'ssh' prefix from connection options (if present)", function()
    local ssh_provider = SSHProvider({ host = "localhost", conn_opts = { "ssh localhost -p 3011" } })
    assert.equals(ssh_provider.conn_opts, "-p 3011")

    -- Even if there are additional whitespaces
    ssh_provider = SSHProvider({ host = "localhost", conn_opts = { " ssh localhost -p 3011" } })
    assert.equals(ssh_provider.conn_opts, "-p 3011")
  end)

  it("should remove host name from connection options (if present)", function()
    local ssh_provider = SSHProvider({ host = "localhost", conn_opts = { "localhost -p 3011" } })
    assert.equals(ssh_provider.conn_opts, "-p 3011")

    ssh_provider = SSHProvider({ host = "localhost", conn_opts = { " localhost" } })
    assert.equals(ssh_provider.conn_opts, "")

    ssh_provider = SSHProvider({ host = "localhost", conn_opts = { "localhost " } })
    assert.equals(ssh_provider.conn_opts, "")

    ssh_provider = SSHProvider({ host = "user@localhost", conn_opts = { "user@localhost" } })
    assert.equals("", ssh_provider.conn_opts)
  end)

  it("should remove '-N' ssh option from connection options (if present)", function()
    local ssh_provider = SSHProvider({ host = "localhost", conn_opts = { "-p 3011 -N" } })
    assert.equals(ssh_provider.conn_opts, "-p 3011")

    ssh_provider = SSHProvider({ host = "localhost", conn_opts = { "-N" } })
    assert.equals(ssh_provider.conn_opts, "")
  end)

  it("should consolidate multiple whitespaces into one in connection options", function()
    local ssh_provider =
      SSHProvider({ host = "localhost", conn_opts = { "  -p 3011      -L 2011:localhost:3011    " } })
    assert.equals(ssh_provider.conn_opts, "-p 3011 -L 2011:localhost:3011")
  end)

  it("should generate unique host ID correctly", function()
    local ssh_provider = SSHProvider({ host = "localhost" })
    assert.equals(ssh_provider.unique_host_id, "localhost")

    ssh_provider = SSHProvider({ host = "localhost", conn_opts = { "-p 3011" } })
    assert.equals(ssh_provider.unique_host_id, "localhost:3011")

    ssh_provider = SSHProvider({ host = "localhost", conn_opts = { "-p" } })
    assert.equals(ssh_provider.unique_host_id, "localhost")
  end)
end)
