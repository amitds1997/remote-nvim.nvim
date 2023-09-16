describe("Session provider", function()
  local assert = require("luassert")
  local stub = require("luassert.stub")
  local SessionProvider = require("remote-nvim.providers.session_provider")
  local session_provider

  before_each(function()
    session_provider = SessionProvider()
  end)

  it("should initialize a session without errors", function()
    assert.has.no_errors(function()
      session_provider:get_or_initialize_session("ssh", "localhost", "-p 9111")
    end)
  end)

  it("should return existing session provider when re-called with same details", function()
    local ssh_provider_1 = session_provider:get_or_initialize_session("ssh", "localhost", "-p 9111")
    local ssh_provider_2 = session_provider:get_or_initialize_session("ssh", "localhost", "-p 9111")

    assert.are.equal(ssh_provider_1, ssh_provider_2)
  end)

  it("should error if an unknown provider type is provided", function()
    assert.error_matches(function()
      session_provider:get_or_initialize_session("unknown", "localhost", "-p 9111")
    end, "Unknown provider type")
  end)

  it("should return saved configurations", function()
    session_provider.remote_workspaces_config = vim.empty_dict()
    local get_workspaces_stub = stub(session_provider.remote_workspaces_config, "get_all_workspaces")
    local provider_type = "ssh"

    session_provider:get_saved_host_configs(provider_type)
    assert.stub(get_workspaces_stub).was.called_with(session_provider.remote_workspaces_config, provider_type)
  end)
end)
