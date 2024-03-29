---@diagnostic disable:invisible
describe("Session provider", function()
  local assert = require("luassert.assert")
  local stub = require("luassert.stub")
  local SessionProvider = require("remote-nvim.providers.session_provider")
  ---@type remote-nvim.providers.SessionProvider
  local session_provider

  before_each(function()
    session_provider = SessionProvider()
  end)

  it("should initialize a session without errors", function()
    assert.has.no_errors(function()
      session_provider:get_or_initialize_session({
        provider_type = "ssh",
        host = "localhost",
        conn_opts = { "-p 9111" },
      })
    end)
  end)

  it("should return existing session provider when re-called with same details", function()
    local ssh_provider_1 = session_provider:get_or_initialize_session({
      provider_type = "ssh",
      host = "localhost",
      conn_opts = { "-p 9111" },
    })
    local ssh_provider_2 = session_provider:get_or_initialize_session({
      provider_type = "ssh",
      host = "localhost",
      conn_opts = { "-p 9111" },
    })

    assert.are.equal(ssh_provider_1, ssh_provider_2)
  end)

  it("should error if an unknown provider type is provided", function()
    assert.error_matches(function()
      session_provider:get_or_initialize_session({
        ---@diagnostic disable-next-line:assign-type-mismatch
        provider_type = "unknown",
        host = "localhost",
        conn_opts = { "-p 9111" },
      })
    end, "Unknown provider type")
  end)

  it("should return saved configurations", function()
    local get_workspace_config_stub = stub(session_provider.remote_workspaces_config, "get_workspace_config")
    local provider_type = "ssh"

    session_provider:get_saved_host_configs(provider_type)
    assert
      .stub(get_workspace_config_stub).was
      .called_with(session_provider.remote_workspaces_config, nil, provider_type)
  end)
end)
