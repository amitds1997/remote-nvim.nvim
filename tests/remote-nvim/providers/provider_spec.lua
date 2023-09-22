describe("Provider", function()
  local assert = require("luassert")
  local remote_nvim = require("remote-nvim")
  local Provider = require("remote-nvim.providers.provider")
  local stub = require("luassert.stub")
  local match = require("luassert.match")
  local provider, notifier_stub

  before_each(function()
    provider = Provider("localhost")
    notifier_stub = stub(provider.notifier, "notify")
  end)

  describe("should handle array-type connections options", function()
    it("when it is not empty", function()
      provider = Provider("localhost", { "-p", "3011", "-t", "-x" })
      assert.equals(provider.conn_opts, "-p 3011 -t -x")
    end)

    it("when it is an empty array", function()
      provider = Provider("localhost", {})
      assert.equals(provider.conn_opts, "")
    end)
  end)

  it("should handle missing connection options correctly", function()
    provider = Provider("localhost")
    assert.equals(provider.conn_opts, "")

    provider = Provider("localhost", nil)
    assert.equals(provider.conn_opts, "")
  end)

  it("should handle string connection options correctly", function()
    provider = Provider("localhost", "-p 3011 -t -x")
    assert.equals(provider.conn_opts, "-p 3011 -t -x")
  end)

  describe("should handle setting workspace variables", function()
    local add_workspace_config, get_workspace_config_stub, update_workspace_config_stub, detect_remote_os_stub, get_remote_neovim_version_preference_stub
    local workspace_id = require("remote-nvim.utils").generate_random_string(10)

    before_each(function()
      add_workspace_config = stub(remote_nvim.session_provider.remote_workspaces_config, "add_workspace_config")
      get_workspace_config_stub = stub(remote_nvim.session_provider.remote_workspaces_config, "get_workspace_config")
      update_workspace_config_stub =
        stub(remote_nvim.session_provider.remote_workspaces_config, "update_workspace_config")

      provider = Provider("localhost", { "-p", "3011" })
      provider.unique_host_id = "localhost:3011"
      provider.provider_type = "test-provider"

      detect_remote_os_stub = stub(provider, "_get_remote_os")
      get_remote_neovim_version_preference_stub = stub(provider, "_get_remote_neovim_version_preference")

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
      update_workspace_config_stub:clear()
    end)

    it("by creating new workspace config record when does not exist", function()
      get_workspace_config_stub.returns({})

      provider:_setup_workspace_variables()
      assert
        .stub(add_workspace_config).was
        .called_with(remote_nvim.session_provider.remote_workspaces_config, provider.unique_host_id, {
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
      assert.stub(update_workspace_config_stub).was.called_with(
        remote_nvim.session_provider.remote_workspaces_config,
        provider.unique_host_id,
        match.is_same({
          os = "Linux",
        })
      )
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
      assert.stub(update_workspace_config_stub).was.called_with(
        remote_nvim.session_provider.remote_workspaces_config,
        provider.unique_host_id,
        match.is_same({ neovim_version = "stable" })
      )
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
    local executor_job_status_stub
    local desc = "Test command"

    before_each(function()
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
    local get_selection_stub

    before_each(function()
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
    local output_stub, selection_stub

    before_each(function()
      _ = stub(provider.notifier, "notify")
      _ = stub(provider, "run_command")
      output_stub = stub(provider.executor, "job_stdout")
      selection_stub = stub(provider, "get_selection")
    end)

    it("when output is not correct", function()
      output_stub.returns({})
      selection_stub.returns("Linux")
      assert.equals(provider:_get_remote_os(), "Linux")
    end)

    it("when it is Linux OS", function()
      output_stub.returns({ "Linux" })
      assert.equals(provider:_get_remote_os(), "Linux")
    end)

    it("when it is MacOS", function()
      output_stub.returns({ "Darwin" })
      assert.equals(provider:_get_remote_os(), "macOS")
    end)

    it("when it is any another OS", function()
      output_stub.returns({ "Windows" })
      selection_stub.returns("Windows")
      assert.equals(provider:_get_remote_os(), "Windows")
    end)
  end)

  describe("should handle config copy correctly", function()
    local selection_stub, update_workspace_config_stub

    before_each(function()
      selection_stub = stub(provider, "get_selection")
      update_workspace_config_stub =
        stub(remote_nvim.session_provider.remote_workspaces_config, "update_workspace_config")
    end)

    it("when the value is already known", function()
      for _, value in ipairs({ true, false }) do
        provider.workspace_config.config_copy = value
        assert.equals(provider:_get_neovim_config_upload_preference(), value)
      end
    end)

    it("when the choice is 'Yes (always)'", function()
      selection_stub.returns("Yes (always)")
      assert.equals(provider:_get_neovim_config_upload_preference(), true)

      assert.stub(update_workspace_config_stub).was.called_with(
        remote_nvim.session_provider.remote_workspaces_config,
        provider.unique_host_id,
        match.is_same({ config_copy = true })
      )
    end)

    it("when the choice is 'No (never)'", function()
      selection_stub.returns("No (never)")
      assert.equals(provider:_get_neovim_config_upload_preference(), false)

      assert.stub(update_workspace_config_stub).was.called_with(
        remote_nvim.session_provider.remote_workspaces_config,
        provider.unique_host_id,
        match.is_same({ config_copy = false })
      )
    end)

    it("when the choice is 'Yes'", function()
      selection_stub.returns("Yes")
      assert.equals(provider:_get_neovim_config_upload_preference(), true)

      assert.stub(update_workspace_config_stub).was.not_called()
    end)

    it("when the choice is 'No'", function()
      selection_stub.returns("No")
      assert.equals(provider:_get_neovim_config_upload_preference(), false)

      assert.stub(update_workspace_config_stub).was.not_called()
    end)
  end)

  describe("should handle remote cleanup correctly", function()
    local selection_stub, run_command_stub

    before_each(function()
      _ = stub(remote_nvim.session_provider.remote_workspaces_config, "delete_workspace")
      run_command_stub = stub(provider, "run_command")
      selection_stub = stub(provider, "get_selection")
      _ = stub(provider, "_verify_connection_to_host")
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
    provider._setup_running = true
    provider._remote_server_process_id = 2100
    provider._local_free_port = 52212

    provider:_reset()
    assert.equals(provider._setup_running, false)
    assert.equals(provider._remote_server_process_id, nil)
    assert.equals(provider._local_free_port, nil)
  end)

  describe("should determine correctly if remote server is running", function()
    it("when we do not have a registered process id", function()
      provider._remote_server_process_id = nil
      assert.equals(provider:_remote_server_already_running(), false)
    end)

    describe("when we have a registered process", function()
      local job_wait_stub

      before_each(function()
        provider._remote_server_process_id = 21
        job_wait_stub = stub(vim.fn, "jobwait")
      end)

      it("and it is still running", function()
        job_wait_stub.returns({ -1 })
        assert.equals(provider:_remote_server_already_running(), true)
      end)

      it("but it is no longer running", function()
        job_wait_stub.returns({ 0 })
        assert.equals(provider:_remote_server_already_running(), false)
      end)
    end)
  end)

  it("should provide correct remote neovim binary path", function()
    provider._remote_is_windows = false
    provider._remote_neovim_home = "~/.remote-nvim"
    provider._remote_neovim_version = "stable"

    assert.equals(provider:_remote_neovim_binary_path(), "~/.remote-nvim/nvim-downloads/stable/bin/nvim")
  end)

  describe("should handle remote setup correctly", function()
    it("when another setup is already running", function()
      provider._setup_running = true
      local notify_once_stub = stub(provider.notifier, "notify_once")

      provider:_setup_remote()
      assert
        .stub(notify_once_stub).was
        .called_with(
          provider.notifier,
          "Another instance of setup is already running. Wait for it to complete.",
          vim.log.levels.WARN
        )
    end)

    describe("and runs correct commands", function()
      local run_command_stub, upload_stub, host_record_exists_stub, get_workspace_config_stub, workspace_id, config_upload_preference_stub

      before_each(function()
        workspace_id = "akfdjakjfdk"
        run_command_stub = stub(provider, "run_command")
        upload_stub = stub(provider, "upload")

        host_record_exists_stub = stub(remote_nvim.session_provider.remote_workspaces_config, "host_record_exists")
        host_record_exists_stub.returns(true)

        get_workspace_config_stub = stub(remote_nvim.session_provider.remote_workspaces_config, "get_workspace_config")
        get_workspace_config_stub.returns({
          provider = "local",
          host = "localhost",
          connection_options = "",
          remote_neovim_home = "~/.remote-nvim",
          config_copy = true,
          client_auto_start = nil,
          workspace_id = workspace_id,
          neovim_version = "stable",
          os = "Linux",
        })
        config_upload_preference_stub = stub(provider, "_get_neovim_config_upload_preference")
        config_upload_preference_stub.returns(true)
        provider:_setup_workspace_variables()
      end)

      it("in default scenario", function()
        provider:_setup_remote()

        -- create directories
        assert.stub(run_command_stub).was.called_with(
          match.is_ref(provider),
          "mkdir -p ~/.remote-nvim/workspaces && mkdir -p ~/.remote-nvim/scripts && mkdir -p ~/.remote-nvim/workspaces/akfdjakjfdk/.config && mkdir -p ~/.remote-nvim/workspaces/akfdjakjfdk/.cache && mkdir -p ~/.remote-nvim/workspaces/akfdjakjfdk/.local/state && mkdir -p ~/.remote-nvim/workspaces/akfdjakjfdk/.local/share",
          "Create necessary directories"
        )

        -- copy scripts
        assert.stub(upload_stub).was.called_with(
          match.is_ref(provider),
          require("plenary.path"):new("scripts"):absolute(),
          "~/.remote-nvim",
          "Copy necessary files"
        )

        -- install neovim if needed
        assert.stub(run_command_stub).was.called_with(
          match.is_ref(provider),
          "chmod +x ~/.remote-nvim/scripts/neovim_install.sh && ~/.remote-nvim/scripts/neovim_install.sh -v stable -d ~/.remote-nvim",
          "Install Neovim if not exists"
        )

        assert.stub(upload_stub).was.called_with(
          match.is_ref(provider),
          remote_nvim.config.neovim_user_config_path,
          "~/.remote-nvim/workspaces/akfdjakjfdk/.config",
          "Copy user neovim config"
        )
      end)

      it("when we do not want to copy config", function()
        config_upload_preference_stub.returns(false)
        provider:_setup_remote()
        assert.stub(upload_stub).was.not_called_with(
          match.is_ref(provider),
          remote_nvim.config.neovim_user_config_path,
          "~/.remote-nvim/workspaces/akfdjakjfdk/.config",
          "Copy user neovim config"
        )
      end)

      it("when we have custom install scripts", function()
        local t = remote_nvim.default_opts.neovim_install_script_path
        remote_nvim.default_opts.neovim_install_script_path = remote_nvim.config.neovim_install_script_path
          .. "/afddafd"
        provider:_setup_remote()

        assert.stub(upload_stub).was.called_with(
          match.is_ref(provider),
          remote_nvim.config.neovim_install_script_path,
          "~/.remote-nvim/scripts",
          "Copy user-specified files"
        )
        remote_nvim.default_opts.neovim_install_script_path = t
      end)
    end)
  end)

  describe("should handle launching remote neovim server correctly", function()
    local remote_server_already_running_stub, run_command_stub
    before_each(function()
      remote_server_already_running_stub = stub(provider, "_remote_server_already_running")
      run_command_stub = stub(provider, "run_command")
      remote_server_already_running_stub.returns(false)
    end)

    it("when a remote server is already running", function()
      remote_server_already_running_stub.returns(true)
      provider:_launch_remote_neovim_server()
      assert.stub(run_command_stub).was.not_called()
    end)

    it("when launching a remote server", function()
      local workspace_id = "ajfdalfj"
      local output_stub = stub(provider.executor, "job_stdout")
      local remote_nvim_path_stub = stub(provider, "_remote_neovim_binary_path")
      local local_free_port_stub = stub(require("remote-nvim.providers.utils"), "find_free_port")

      local host_record_exists_stub = stub(remote_nvim.session_provider.remote_workspaces_config, "host_record_exists")
      host_record_exists_stub.returns(true)

      local get_workspace_config_stub =
        stub(remote_nvim.session_provider.remote_workspaces_config, "get_workspace_config")
      get_workspace_config_stub.returns({
        provider = "local",
        host = "localhost",
        connection_options = "",
        remote_neovim_home = "~/.remote-nvim",
        config_copy = true,
        client_auto_start = nil,
        workspace_id = workspace_id,
        neovim_version = "stable",
        os = "Linux",
      })
      provider:_setup_workspace_variables()

      remote_nvim_path_stub.returns("nvim")
      output_stub.returns({ 32123 })
      local_free_port_stub.returns(52232)

      provider:_launch_remote_neovim_server()
      assert
        .stub(run_command_stub).was
        .called_with(match.is_ref(provider), "nvim -l ~/.remote-nvim/scripts/free_port_finder.lua", "Find free port on remote")
      assert.stub(local_free_port_stub).was.called()
      assert.stub(run_command_stub).was.called_with(
        match.is_ref(provider),
        "XDG_CONFIG_HOME=~/.remote-nvim/workspaces/ajfdalfj/.config XDG_DATA_HOME=~/.remote-nvim/workspaces/ajfdalfj/.local/share XDG_STATE_HOME=~/.remote-nvim/workspaces/ajfdalfj/.local/state XDG_CACHE_HOME=~/.remote-nvim/workspaces/ajfdalfj/.cache nvim --listen 0.0.0.0:32123 --headless",
        "Launch remote server",
        "-t -L 52232:localhost:32123",
        match.is_function()
      )
    end)
  end)

  describe("should handle local client start preference correctly", function()
    local selection_stub, update_workspace_config_stub

    before_each(function()
      selection_stub = stub(provider, "get_selection")
      update_workspace_config_stub =
        stub(remote_nvim.session_provider.remote_workspaces_config, "update_workspace_config")
    end)

    it("when the value is already known", function()
      for _, value in ipairs({ true, false }) do
        provider.workspace_config.client_auto_start = value
        assert.equals(provider:_get_local_client_start_preference(), value)
      end
    end)

    it("when the choice is 'Yes (always)'", function()
      selection_stub.returns("Yes (always)")
      assert.equals(provider:_get_local_client_start_preference(), true)

      assert.stub(update_workspace_config_stub).was.called_with(
        remote_nvim.session_provider.remote_workspaces_config,
        provider.unique_host_id,
        match.is_same({ client_auto_start = true })
      )
    end)

    it("when the choice is 'No (never)'", function()
      selection_stub.returns("No (never)")
      assert.equals(provider:_get_local_client_start_preference(), false)

      assert.stub(update_workspace_config_stub).was.called_with(
        remote_nvim.session_provider.remote_workspaces_config,
        provider.unique_host_id,
        match.is_same({ client_auto_start = false })
      )
    end)

    it("when the choice is 'Yes'", function()
      selection_stub.returns("Yes")
      assert.equals(provider:_get_local_client_start_preference(), true)

      assert.stub(update_workspace_config_stub).was.not_called()
    end)

    it("when the choice is 'No'", function()
      selection_stub.returns("No")
      assert.equals(provider:_get_local_client_start_preference(), false)

      assert.stub(update_workspace_config_stub).was.not_called()
    end)
  end)

  describe("should handle local client launch correctly", function()
    local local_client_preference_stub

    before_each(function()
      local_client_preference_stub = stub(provider, "_get_local_client_start_preference")
    end)

    it("when user does not want to launch client", function()
      local_client_preference_stub.returns(false)

      provider:_launch_local_neovim_client()
      assert
        .stub(notifier_stub).was
        .called_with(provider.notifier, "Run :RemoteSessionInfo to find local client command", vim.log.levels.INFO, true)
    end)

    describe("when user wants to launch client", function()
      local_client_preference_stub.returns(true)
      _ = stub(provider, "_wait_for_server_to_be_ready")

      local defined_callback_stub = stub(remote_nvim.config.local_client_config, "callback")
      local get_workspace_config_stub =
        stub(remote_nvim.session_provider.remote_workspaces_config, "get_workspace_config")
      get_workspace_config_stub.returns({})

      provider:_launch_local_neovim_client()
      assert.stub(defined_callback_stub).was.called_with(provider._local_free_port, match.is_table())
      assert.stub(get_workspace_config_stub).was.called()
    end)
  end)
end)
