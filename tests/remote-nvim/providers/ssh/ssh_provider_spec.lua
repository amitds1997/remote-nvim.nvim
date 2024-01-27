describe("SSH Provider", function()
  local SSHProvider = require("remote-nvim.providers.ssh.ssh_provider")
  local assert = require("luassert.assert")
  local mock = require("luassert.mock")
  local progress_viewer

  before_each(function()
    progress_viewer = mock(require("remote-nvim.ui.progressview"), true)
  end)

  it("should remove 'ssh' prefix from connection options (if present)", function()
    local ssh_provider =
      SSHProvider({ host = "localhost", conn_opts = { "ssh localhost -p 3011" }, progress_view = progress_viewer })
    assert.equals("-p 3011", ssh_provider.conn_opts)

    -- Even if there are additional whitespaces
    ssh_provider =
      SSHProvider({ host = "localhost", conn_opts = { " ssh localhost -p 3011" }, progress_view = progress_viewer })
    assert.equals("-p 3011", ssh_provider.conn_opts)
  end)

  it("should correctly set unique host ID when passed manually as an option", function()
    local unique_host_id = "custom-host-id"
    local provider = SSHProvider({
      host = "localhost",
      unique_host_id = unique_host_id,
      progress_view = progress_viewer,
    })
    assert.equals(unique_host_id, provider.unique_host_id)
  end)

  describe("should correctly set provider type", function()
    it("when it is provided manually", function()
      local provider = SSHProvider({
        host = "localhost",
        provider_type = "devpod",
        progress_view = progress_viewer,
      })
      assert.equals("devpod", provider.provider_type)
    end)

    it("when not provided to 'ssh'", function()
      local provider = SSHProvider({
        host = "localhost",
        progress_view = progress_viewer,
      })
      assert.equals("ssh", provider.provider_type)
    end)
  end)

  it("should remove host name from connection options (if present)", function()
    local ssh_provider =
      SSHProvider({ host = "localhost", conn_opts = { "localhost -p 3011" }, progress_view = progress_viewer })
    assert.equals("-p 3011", ssh_provider.conn_opts)

    ssh_provider = SSHProvider({ host = "localhost", conn_opts = { " localhost" }, progress_view = progress_viewer })
    assert.equals("", ssh_provider.conn_opts)

    ssh_provider = SSHProvider({ host = "localhost", conn_opts = { "localhost " }, progress_view = progress_viewer })
    assert.equals("", ssh_provider.conn_opts)

    ssh_provider =
      SSHProvider({ host = "user@localhost", conn_opts = { "user@localhost" }, progress_view = progress_viewer })
    assert.equals("", ssh_provider.conn_opts)
  end)

  it("should remove '-N' ssh option from connection options (if present)", function()
    local ssh_provider =
      SSHProvider({ host = "localhost", conn_opts = { "-p 3011 -N" }, progress_view = progress_viewer })
    assert.equals("-p 3011", ssh_provider.conn_opts)

    ssh_provider = SSHProvider({ host = "localhost", conn_opts = { "-N" }, progress_view = progress_viewer })
    assert.equals("", ssh_provider.conn_opts)
  end)

  it("should consolidate multiple whitespaces into one in connection options", function()
    local ssh_provider = SSHProvider({
      host = "localhost",
      conn_opts = { "  -p 3011      -L 2011:localhost:3011    " },
      progress_view = progress_viewer,
    })
    assert.equals("-p 3011 -L 2011:localhost:3011", ssh_provider.conn_opts)
  end)

  it("should generate unique host ID correctly", function()
    local ssh_provider = SSHProvider({ host = "localhost", progress_view = progress_viewer })
    assert.equals("localhost", ssh_provider.unique_host_id)

    ssh_provider = SSHProvider({ host = "localhost", conn_opts = { "-p 3011" }, progress_view = progress_viewer })
    assert.equals("localhost:3011", ssh_provider.unique_host_id)

    ssh_provider = SSHProvider({ host = "localhost", conn_opts = { "-p" }, progress_view = progress_viewer })
    assert.equals("localhost", ssh_provider.unique_host_id)
  end)
end)
