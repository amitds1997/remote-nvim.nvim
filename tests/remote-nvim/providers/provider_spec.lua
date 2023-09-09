describe("Provider", function()
  local Provider = require("remote-nvim.providers.provider")
  local stub = require("luassert.stub")

  describe("should handle array-type connections options", function()
    it("when it is not empty", function()
      local provider = Provider("localhost", { "-p", "3011", "-t", "-x" })
      assert.equals(provider.conn_opts, "-p 3011 -t -x")
    end)

    it("when it is an empty array", function()
      local provider = Provider("localhost", {})
      assert.equals(provider.conn_opts, "")
    end)
  end)

  it("should handle missing connection options correctly", function()
    local provider = Provider("localhost")
    assert.equals(provider.conn_opts, "")

    provider = Provider("localhost", nil)
    assert.equals(provider.conn_opts, "")
  end)

  it("should handle string connection options correctly", function()
    local provider = Provider("localhost", "-p 3011 -t -x")
    assert.equals(provider.conn_opts, "-p 3011 -t -x")
  end)

  describe("should handle setting workspace variables", function()
    local remote_nvim = require("remote-nvim")
    local provider, host_record_exists_stub, add_host_config_stub, get_workspace_config_stub, update_host_record_stub, detect_remote_os_stub, get_remote_neovim_version_preference_stub
    local workspace_id = require("remote-nvim.utils").generate_random_string(10)

    before_each(function()
      host_record_exists_stub = stub(remote_nvim.host_workspace_config, "host_record_exists")
      add_host_config_stub = stub(remote_nvim.host_workspace_config, "add_host_config")
      get_workspace_config_stub = stub(remote_nvim.host_workspace_config, "get_workspace_config")
      update_host_record_stub = stub(remote_nvim.host_workspace_config, "update_host_record")

      provider = Provider("localhost", { "-p", "3011" })
      provider.unique_host_id = "localhost:3011"
      provider.provider_type = "test-provider"

      detect_remote_os_stub = stub(provider, "detect_remote_os")
      get_remote_neovim_version_preference_stub = stub(provider, "get_remote_neovim_version_preference")

      host_record_exists_stub.returns(true)
      get_workspace_config_stub.returns({
        provider = provider.provider_type,
        host = provider.host,
        connection_options = provider.conn_opts,
        remote_neovim_home = remote_nvim.config.remote_neovim_install_home,
        config_copy = nil,
        client_auto_start = nil,
        workspace_id = workspace_id,
        neovim_version = "stable",
        os = "Linux",
      })
      update_host_record_stub:clear()
    end)

    it("by creating new workspace config record when does not exist", function()
      host_record_exists_stub.returns(false)

      provider:_setup_workspace_variables()
      assert.stub(add_host_config_stub).was.called_with(remote_nvim.host_workspace_config, provider.unique_host_id, {
        provider = provider.provider_type,
        host = provider.host,
        connection_options = provider.conn_opts,
        remote_neovim_home = remote_nvim.config.remote_neovim_install_home,
        config_copy = nil,
        client_auto_start = nil,
        workspace_id = workspace_id,
      })
    end)

    it("by setting up remote OS if not set", function()
      get_workspace_config_stub.returns({
        provider = provider.provider_type,
        host = provider.host,
        connection_options = provider.conn_opts,
        remote_neovim_home = remote_nvim.config.remote_neovim_install_home,
        config_copy = nil,
        client_auto_start = nil,
        workspace_id = workspace_id,
        neovim_version = "stable",
        os = nil,
      })
      detect_remote_os_stub.returns("Linux")

      provider:_setup_workspace_variables()
      assert
        .stub(update_host_record_stub).was
        .called_with(remote_nvim.host_workspace_config, provider.unique_host_id, "os", "Linux")
    end)

    it("by setting up remote Neovim if not set", function()
      get_workspace_config_stub.returns({
        provider = provider.provider_type,
        host = provider.host,
        connection_options = provider.conn_opts,
        remote_neovim_home = remote_nvim.config.remote_neovim_install_home,
        config_copy = nil,
        client_auto_start = nil,
        workspace_id = workspace_id,
        neovim_version = nil,
        os = "Linux",
      })
      get_remote_neovim_version_preference_stub.returns("stable")

      provider:_setup_workspace_variables()
      assert
        .stub(update_host_record_stub).was
        .called_with(remote_nvim.host_workspace_config, provider.unique_host_id, "neovim_version", "stable")
    end)

    describe("by correctly setting workspace variables", function()
      it("on Linux and MacOS", function()
        provider:_setup_workspace_variables()
        local remote_home = remote_nvim.config.remote_neovim_install_home

        assert.equals(provider._remote_os, "Linux")
        assert.equals(provider._remote_is_windows, false)
        assert.equals(provider._remote_neovim_version, "stable")
        assert.equals(provider._remote_workspace_id, workspace_id)
        assert.equals(provider._remote_neovim_home, remote_home)
        assert.equals(provider._remote_workspaces_path, ("%s/workspaces"):format(remote_home))
        assert.equals(provider._remote_scripts_path, ("%s/scripts"):format(remote_home))
        assert.equals(provider._remote_neovim_install_script_path, ("%s/scripts/neovim_install.sh"):format(remote_home))
        assert.equals(provider._remote_workspace_id_path, ("%s/workspaces/%s"):format(remote_home, workspace_id))

        -- XDG variables
        assert.equals(provider._remote_xdg_config_path, ("%s/workspaces/%s/.config"):format(remote_home, workspace_id))
        assert.equals(provider._remote_xdg_cache_path, ("%s/workspaces/%s/.cache"):format(remote_home, workspace_id))
        assert.equals(
          provider._remote_xdg_share_path,
          ("%s/workspaces/%s/.local/share"):format(remote_home, workspace_id)
        )
        assert.equals(
          provider._remote_xdg_state_path,
          ("%s/workspaces/%s/.local/state"):format(remote_home, workspace_id)
        )

        -- Remote config path
        assert.equals(
          provider._remote_neovim_config_path,
          ("%s/workspaces/%s/.config/nvim"):format(remote_home, workspace_id)
        )
      end)
    end)
  end)

  describe("should handle running commands", function()
    local provider, notifier_stub
    local desc = "Test command"

    before_each(function()
      provider = Provider("localhost")
      notifier_stub = stub(provider.notifier, "notify")
    end)

    it("when they succeed", function()
      provider:run_command("uname", desc)

      assert
        .stub(notifier_stub).was
        .called_with(provider.notifier, ("'%s' succeeded."):format(desc), vim.log.levels.INFO)
    end)

    it("when they fail", function()
      assert.error_matches(function()
        provider:run_command("unme", desc)
      end, ("'%s' failed"):format(desc))

      assert
        .stub(notifier_stub).was
        .called_with(provider.notifier, ("'%s' failed."):format(desc), vim.log.levels.ERROR, true)
    end)
  end)
end)
