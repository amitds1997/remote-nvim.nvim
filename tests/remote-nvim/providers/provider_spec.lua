describe("Provider", function()
  local remote_nvim = require("remote-nvim")
  local Provider = require("remote-nvim.providers.provider")
  local stub = require("luassert.stub")
  local match = require("luassert.match")

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

      detect_remote_os_stub = stub(provider, "get_remote_os")
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
          provider._remote_xdg_data_path,
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

  describe("should handle running commands and uploads correctly", function()
    local provider, notifier_stub, executor_job_status_stub
    local desc = "Test command"

    before_each(function()
      provider = Provider("localhost")
      notifier_stub = stub(provider.notifier, "notify")
      executor_job_status_stub = stub(provider.executor, "last_job_status")
    end)

    it("when they succeed", function()
      executor_job_status_stub.returns(0)
      provider:_handle_job_completion(desc)
      assert
        .stub(notifier_stub).was
        .called_with(provider.notifier, ("'%s' succeeded."):format(desc), vim.log.levels.INFO)
    end)

    it("when they fail", function()
      executor_job_status_stub.returns(23)

      assert.error_matches(function()
        provider:_handle_job_completion(desc)
      end, ("'%s' failed"):format(desc))

      assert
        .stub(notifier_stub).was
        .called_with(provider.notifier, ("'%s' failed."):format(desc), vim.log.levels.ERROR, true)
    end)
  end)

  describe("should handle option selection correctly", function()
    local get_selection_stub, provider, notifier_stub
    before_each(function()
      provider = Provider("localhost")
      notifier_stub = stub(provider.notifier, "notify")
      get_selection_stub = stub(require("remote-nvim.providers.utils"), "get_selection")
    end)

    it("when no options are selected", function()
      get_selection_stub.returns(nil)
      local co = coroutine.create(function()
        provider:get_selection({}, {})
      end)
      coroutine.resume(co)
      assert.stub(notifier_stub).was.called_with(provider.notifier, "No selection made", vim.log.levels.WARN, true)
    end)

    it("when choice selection is done", function()
      local choice = "choice"
      get_selection_stub.returns(choice)
      assert.equals(provider:get_selection({}, {}), choice)
    end)
  end)

  describe("should handle remote OS detection correctly", function()
    local provider, output_stub, selection_stub

    before_each(function()
      provider = Provider("localhost")
      _ = stub(provider.notifier, "notify")
      _ = stub(provider, "run_command")
      output_stub = stub(provider.executor, "job_stdout")
      selection_stub = stub(provider, "get_selection")
    end)

    it("when output is not correct", function()
      output_stub.returns({})
      selection_stub.returns("Linux")
      assert.equals(provider:get_remote_os(), "Linux")
    end)

    it("when it is Linux OS", function()
      output_stub.returns({ "Linux" })
      assert.equals(provider:get_remote_os(), "Linux")
    end)

    it("when it is MacOS", function()
      output_stub.returns({ "Darwin" })
      assert.equals(provider:get_remote_os(), "macOS")
    end)

    it("when it is any another OS", function()
      output_stub.returns({ "Windows" })
      selection_stub.returns("Windows")
      assert.equals(provider:get_remote_os(), "Windows")
    end)
  end)

  describe("should handle config copy correctly", function()
    local provider, selection_stub, update_host_record_stub

    before_each(function()
      provider = Provider("localhost")
      selection_stub = stub(provider, "get_selection")
      update_host_record_stub = stub(remote_nvim.host_workspace_config, "update_host_record")
    end)

    it("when the value is already known", function()
      for _, value in ipairs({ true, false }) do
        provider.workspace_config.config_copy = value
        assert.equals(provider:get_neovim_config_upload_preference(), value)
      end
    end)

    it("when the choice is 'Yes (always)'", function()
      selection_stub.returns("Yes (always)")
      assert.equals(provider:get_neovim_config_upload_preference(), true)

      assert
        .stub(update_host_record_stub).was
        .called_with(remote_nvim.host_workspace_config, provider.unique_host_id, "config_copy", true)
    end)

    it("when the choice is 'No (never)'", function()
      selection_stub.returns("No (never)")
      assert.equals(provider:get_neovim_config_upload_preference(), false)

      assert
        .stub(update_host_record_stub).was
        .called_with(remote_nvim.host_workspace_config, provider.unique_host_id, "config_copy", false)
    end)

    it("when the choice is 'Yes'", function()
      selection_stub.returns("Yes")
      assert.equals(provider:get_neovim_config_upload_preference(), true)

      assert.stub(update_host_record_stub).was.not_called()
    end)

    it("when the choice is 'No'", function()
      selection_stub.returns("No")
      assert.equals(provider:get_neovim_config_upload_preference(), false)

      assert.stub(update_host_record_stub).was.not_called()
    end)
  end)

  describe("should handle remote cleanup correctly", function()
    local provider, selection_stub, run_command_stub

    before_each(function()
      provider = Provider("localhost")
      _ = stub(remote_nvim.host_workspace_config, "delete_workspace")
      run_command_stub = stub(provider, "run_command")
      selection_stub = stub(provider, "get_selection")
      _ = stub(provider, "verify_connection_to_host")
    end)

    it("when asked to cleanup remote workspace", function()
      local workspace_path = "~/.remote-nvim/workspaces/abc"
      selection_stub.returns("Delete neovim workspace (Choose if multiple people use the same user account)")
      provider._remote_workspace_id_path = workspace_path

      provider:clean_up_remote_host()
      assert
        .stub(run_command_stub).was
        .called_with(
          match.is_ref(provider),
          "rm -rf ~/.remote-nvim/workspaces/abc",
          "Delete remote nvim workspace from remote host"
        )
    end)

    it("when asked to cleanup remote workspace", function()
      local remote_home = "~/.remote-nvim"
      selection_stub.returns("Delete remote neovim from remote host (Nuke it!)")
      provider._remote_neovim_home = remote_home

      provider:clean_up_remote_host()
      assert
        .stub(run_command_stub).was
        .called_with(match.is_ref(provider), "rm -rf ~/.remote-nvim", "Delete remote nvim from remote host")
    end)
  end)

  it("should handle resetting correctly", function()
    local provider = Provider("localhost")
    provider._setup_running = true
    provider._remote_server_process_id = 2100
    provider._local_free_port = 52212

    provider:reset()
    assert.equals(provider._setup_running, false)
    assert.equals(provider._remote_server_process_id, nil)
    assert.equals(provider._local_free_port, nil)
  end)
end)
