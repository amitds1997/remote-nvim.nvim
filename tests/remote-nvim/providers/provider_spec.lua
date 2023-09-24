---@diagnostic disable:invisible
describe("Provider", function()
  local assert = require("luassert.assert")
  local remote_nvim = require("remote-nvim")
  local Provider = require("remote-nvim.providers.provider")
  local stub = require("luassert.stub")
  local match = require("luassert.match")
  ---@type remote-nvim.providers.Provider
  local provider
  local provider_host
  local notifier_stub

  before_each(function()
    provider_host = require("remote-nvim.utils").generate_random_string(6)
    provider = Provider(provider_host)
    notifier_stub = stub(provider.notifier, "notify")
  end)

  describe("should handle array-type connections options", function()
    it("when it is not empty", function()
      provider = Provider(provider_host, { "-p", "3011", "-t", "-x" })
      assert.equals(provider.conn_opts, "-p 3011 -t -x")
    end)

    it("when it is an empty array", function()
      provider = Provider(provider_host, {})
      assert.equals(provider.conn_opts, "")
    end)
  end)

  it("should handle missing connection options correctly", function()
    provider = Provider(provider_host)
    assert.equals(provider.conn_opts, "")

    provider = Provider(provider_host, nil)
    assert.equals(provider.conn_opts, "")
  end)

  it("should handle string connection options correctly", function()
    provider = Provider(provider_host, "-p 3011 -t -x")
    assert.equals(provider.conn_opts, "-p 3011 -t -x")
  end)

  describe("should handle setting workspace variables", function()
    local detect_remote_os_stub, get_remote_neovim_version_preference_stub
    local workspace_id = require("remote-nvim.utils").generate_random_string(10)

    before_each(function()
      provider = Provider(provider_host, { "-p", "3011" })
      detect_remote_os_stub = stub(provider, "_get_remote_os")
      get_remote_neovim_version_preference_stub = stub(provider, "_get_remote_neovim_version_preference")

      provider._config_provider:add_workspace_config(provider.unique_host_id, {
        provider = "local",
        host = provider.host,
        connection_options = provider.conn_opts,
        remote_neovim_home = remote_nvim.config.remote_neovim_install_home,
        config_copy = nil,
        client_auto_start = nil,
        workspace_id = workspace_id,
        neovim_version = "stable",
        os = "Linux",
      })
      detect_remote_os_stub.returns("Linux")
      get_remote_neovim_version_preference_stub.returns("stable")
      provider:_setup_workspace_variables()
    end)

    after_each(function()
      provider._config_provider:remove_workspace_config(provider.unique_host_id)
    end)

    it("by creating new workspace config record when does not exist", function()
      provider._config_provider:remove_workspace_config(provider.unique_host_id)
      provider:_setup_workspace_variables()

      assert.are.same(provider._config_provider:get_workspace_config(provider.unique_host_id), {
        provider = "local",
        host = provider.host,
        connection_options = provider.conn_opts,
        remote_neovim_home = remote_nvim.config.remote_neovim_install_home,
        config_copy = nil,
        client_auto_start = nil,
        workspace_id = workspace_id,
        neovim_version = "stable",
        os = "Linux",
      })
    end)

    it("by setting up remote OS if not set", function()
      provider._config_provider:update_workspace_config(provider.unique_host_id, {
        os = nil,
      })
      provider:_setup_workspace_variables()

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(wk_config["os"], "Linux")
    end)

    it("by setting up remote Neovim if not set", function()
      provider._config_provider:add_workspace_config(provider.unique_host_id, {
        neovim_version = nil,
      })
      provider:_setup_workspace_variables()

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(wk_config["neovim_version"], "stable")
    end)

    it("by correctly setting workspace variables", function()
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
      assert.equals(provider._remote_xdg_data_path, ("%s/workspaces/%s/.local/share"):format(remote_home, workspace_id))
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
      executor_job_status_stub.returns(255)

      local co = coroutine.create(function()
        provider:_handle_job_completion(desc)
      end)
      coroutine.resume(co)

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

  describe("should handle config copy correctly", function()
    local selection_stub

    before_each(function()
      selection_stub = stub(provider, "get_selection")
      provider._config_provider:add_workspace_config(provider.unique_host_id, {
        provider = provider.provider_type,
        host = provider.host,
        connection_options = provider.conn_opts,
        remote_neovim_home = remote_nvim.config.remote_neovim_install_home,
        config_copy = nil,
        client_auto_start = nil,
        workspace_id = "ajdfkafd",
        neovim_version = "stable",
        os = "Linux",
      })
    end)

    after_each(function()
      provider._config_provider:remove_workspace_config(provider.unique_host_id)
    end)

    it("when the value is already known", function()
      provider._config_provider:update_workspace_config(provider.unique_host_id, {
        config_copy = true,
      })
      provider:_setup_workspace_variables()
      assert.equals(provider:_get_neovim_config_upload_preference(), true)

      provider._config_provider:update_workspace_config(provider.unique_host_id, {
        config_copy = false,
      })
      provider:_setup_workspace_variables()
      assert.equals(provider:_get_neovim_config_upload_preference(), false)
    end)

    it("when the choice is 'Yes (always)'", function()
      selection_stub.returns("Yes (always)")
      assert.equals(provider:_get_neovim_config_upload_preference(), true)

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(wk_config["config_copy"], true)
    end)

    it("when the choice is 'No (never)'", function()
      selection_stub.returns("No (never)")
      assert.equals(provider:_get_neovim_config_upload_preference(), false)

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(wk_config["config_copy"], false)
    end)

    it("when the choice is 'Yes'", function()
      selection_stub.returns("Yes")
      assert.equals(provider:_get_neovim_config_upload_preference(), true)

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(wk_config["config_copy"], nil) -- The value should not be stored
    end)

    it("when the choice is 'No'", function()
      selection_stub.returns("No")
      assert.equals(provider:_get_neovim_config_upload_preference(), false)

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(wk_config["config_copy"], nil) -- The value should not be stored
    end)
  end)

  describe("should handle remote cleanup correctly", function()
    local selection_stub, run_command_stub

    before_each(function()
      run_command_stub = stub(provider, "run_command")
      selection_stub = stub(provider, "get_selection")
      provider._config_provider:add_workspace_config(provider.unique_host_id, {
        provider = provider.provider_type,
        host = provider.host,
        connection_options = provider.conn_opts,
        remote_neovim_home = remote_nvim.config.remote_neovim_install_home,
        config_copy = nil,
        client_auto_start = nil,
        workspace_id = "ajdfkafd",
        neovim_version = "stable",
        os = "Linux",
      })
      provider:_setup_workspace_variables()
    end)

    after_each(function()
      provider._config_provider:remove_workspace_config(provider.unique_host_id)
    end)

    it("when asked to cleanup just the remote workspace", function()
      selection_stub.returns("Delete neovim workspace (Choose if multiple people use the same user account)")

      provider:clean_up_remote_host()
      assert.stub(run_command_stub).was.called_with(
        match.is_ref(provider),
        "rm -rf ~/.remote-nvim/workspaces/ajdfkafd",
        "Delete remote nvim workspace from remote host"
      )
      assert.are.same(provider._config_provider:get_workspace_config(provider.unique_host_id), {})
    end)

    it("when asked to clenaup entire remote neovim directory", function()
      selection_stub.returns("Delete remote neovim from remote host (Nuke it!)")

      provider:clean_up_remote_host()
      assert
        .stub(run_command_stub).was
        .called_with(match.is_ref(provider), "rm -rf ~/.remote-nvim", "Delete remote nvim from remote host")
      assert.are.same(provider._config_provider:get_workspace_config(provider.unique_host_id), {})
    end)
  end)

  describe("should handle resetting correctly", function()
    local jobwait_stub
    before_each(function()
      jobwait_stub = stub(vim.fn, "jobwait")
      jobwait_stub.returns({ -1 })
    end)

    it("when remote server is not running", function()
      provider._setup_running = true
      provider._remote_server_process_id = nil
      provider._local_free_port = "52212"

      provider:_reset()
      assert.equals(provider._setup_running, false)
      assert.equals(provider._remote_server_process_id, nil)
      assert.equals(provider._local_free_port, nil)
    end)
  end)

  it("should stop running remote server if needed", function()
    local system_stub = stub(vim.fn, "system")
    provider._setup_running = true
    provider._remote_server_process_id = 2100
    provider._local_free_port = "52212"

    provider:stop_neovim()
    assert.equals(provider._setup_running, false)
    assert.equals(provider._remote_server_process_id, nil)
    assert.equals(provider._local_free_port, nil)
    assert.stub(system_stub).was.called()
  end)

  describe("should determine correctly if remote server is running", function()
    it("when we do not have a registered process id", function()
      provider._remote_server_process_id = nil
      assert.equals(provider:is_remote_server_running(), false)
    end)

    describe("when we have a registered process", function()
      local job_wait_stub

      before_each(function()
        provider._remote_server_process_id = 21
        job_wait_stub = stub(vim.fn, "jobwait")
      end)

      it("and it is still running", function()
        job_wait_stub.returns({ -1 })
        assert.equals(provider:is_remote_server_running(), true)
      end)

      it("but it is no longer running", function()
        job_wait_stub.returns({ 0 })
        assert.equals(provider:is_remote_server_running(), false)
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
          "Another instance of setup is already running. Wait for it to complete",
          vim.log.levels.WARN
        )
    end)

    describe("and runs correct commands", function()
      local run_command_stub, upload_stub

      before_each(function()
        run_command_stub = stub(provider, "run_command")
        upload_stub = stub(provider, "upload")

        provider._config_provider:add_workspace_config(provider.unique_host_id, {
          provider = "local",
          host = provider_host,
          connection_options = "",
          remote_neovim_home = "~/.remote-nvim",
          config_copy = true,
          client_auto_start = nil,
          workspace_id = "akfdjakjfdk",
          neovim_version = "stable",
          os = "Linux",
        })
        provider:_setup_workspace_variables()
      end)

      after_each(function()
        provider._config_provider:remove_workspace_config(provider.unique_host_id)
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
        provider._config_provider:update_workspace_config(provider.unique_host_id, {
          config_copy = false,
        })
        provider:_setup_workspace_variables()

        provider:_setup_remote()
        assert.stub(upload_stub).was.not_called_with(
          match.is_ref(provider),
          remote_nvim.config.neovim_user_config_path,
          "~/.remote-nvim/workspaces/akfdjakjfdk/.config",
          "Copy user neovim config"
        )
      end)

      it("when we have custom install scripts", function()
        local default_install_script_path = remote_nvim.default_opts.neovim_install_script_path
        remote_nvim.default_opts.neovim_install_script_path = remote_nvim.config.neovim_install_script_path
          .. "/afddafd"
        provider:_setup_remote()

        assert.stub(upload_stub).was.called_with(
          match.is_ref(provider),
          remote_nvim.config.neovim_install_script_path,
          "~/.remote-nvim/scripts",
          "Copy user-specified files"
        )
        remote_nvim.default_opts.neovim_install_script_path = default_install_script_path
      end)
    end)
  end)

  describe("should handle launching remote neovim server correctly", function()
    local is_remote_server_running_stub, run_command_stub
    before_each(function()
      is_remote_server_running_stub = stub(provider, "is_remote_server_running")
      run_command_stub = stub(provider, "run_command")

      provider._config_provider:add_workspace_config(provider.unique_host_id, {
        provider = "local",
        host = provider_host,
        connection_options = "",
        remote_neovim_home = "~/.remote-nvim",
        config_copy = true,
        client_auto_start = nil,
        workspace_id = "ajfdalfj",
        neovim_version = "stable",
        os = "Linux",
      })
      provider:_setup_workspace_variables()
    end)

    after_each(function()
      provider._config_provider:remove_workspace_config(provider.unique_host_id)
    end)

    it("when a remote server is already running", function()
      is_remote_server_running_stub.returns(true)
      provider:_launch_remote_neovim_server()
      assert.stub(run_command_stub).was.not_called()
    end)

    it("when launching a remote server", function()
      local output_stub = stub(provider.executor, "job_stdout")
      local local_free_port_stub = stub(require("remote-nvim.providers.utils"), "find_free_port")
      is_remote_server_running_stub.returns(false)
      output_stub.returns({ 32123 })
      local_free_port_stub.returns(52232)

      provider:_launch_remote_neovim_server()
      assert.stub(run_command_stub).was.called_with(
        match.is_ref(provider),
        "~/.remote-nvim/nvim-downloads/stable/bin/nvim -l ~/.remote-nvim/scripts/free_port_finder.lua",
        "Find free port on remote"
      )
      assert.stub(local_free_port_stub).was.called()
      assert.stub(run_command_stub).was.called_with(
        match.is_ref(provider),
        "XDG_CONFIG_HOME=~/.remote-nvim/workspaces/ajfdalfj/.config XDG_DATA_HOME=~/.remote-nvim/workspaces/ajfdalfj/.local/share XDG_STATE_HOME=~/.remote-nvim/workspaces/ajfdalfj/.local/state XDG_CACHE_HOME=~/.remote-nvim/workspaces/ajfdalfj/.cache ~/.remote-nvim/nvim-downloads/stable/bin/nvim --listen 0.0.0.0:32123 --headless",
        "Launch remote server",
        "-t -L 52232:localhost:32123",
        match.is_function()
      )
    end)
  end)

  describe("should handle local client start preference correctly", function()
    local selection_stub

    before_each(function()
      selection_stub = stub(provider, "get_selection")
    end)

    before_each(function()
      selection_stub = stub(provider, "get_selection")
      provider._config_provider:add_workspace_config(provider.unique_host_id, {
        provider = provider.provider_type,
        host = provider.host,
        connection_options = provider.conn_opts,
        remote_neovim_home = remote_nvim.config.remote_neovim_install_home,
        config_copy = nil,
        client_auto_start = nil,
        workspace_id = "ajdfkafd",
        neovim_version = "stable",
        os = "Linux",
      })
    end)

    after_each(function()
      provider._config_provider:remove_workspace_config(provider.unique_host_id)
    end)

    it("when the value is already known", function()
      provider._config_provider:update_workspace_config(provider.unique_host_id, {
        client_auto_start = true,
      })
      provider:_setup_workspace_variables()
      assert.equals(provider:_get_local_client_start_preference(), true)

      provider._config_provider:update_workspace_config(provider.unique_host_id, {
        client_auto_start = false,
      })
      provider:_setup_workspace_variables()
      assert.equals(provider:_get_local_client_start_preference(), false)
    end)

    it("when the choice is 'Yes (always)'", function()
      selection_stub.returns("Yes (always)")
      assert.equals(provider:_get_local_client_start_preference(), true)

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(wk_config["client_auto_start"], true)
    end)

    it("when the choice is 'No (never)'", function()
      selection_stub.returns("No (never)")
      assert.equals(provider:_get_local_client_start_preference(), false)

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(wk_config["client_auto_start"], false)
    end)

    it("when the choice is 'Yes'", function()
      selection_stub.returns("Yes")
      assert.equals(provider:_get_local_client_start_preference(), true)

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(wk_config["client_auto_start"], nil)
    end)

    it("when the choice is 'No'", function()
      selection_stub.returns("No")
      assert.equals(provider:_get_local_client_start_preference(), false)

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(wk_config["client_auto_start"], nil)
    end)
  end)

  describe("should handle local client launch correctly", function()
    before_each(function()
      provider._config_provider:add_workspace_config(provider.unique_host_id, {
        provider = provider.provider_type,
        host = provider.host,
        connection_options = provider.conn_opts,
        remote_neovim_home = remote_nvim.config.remote_neovim_install_home,
        config_copy = nil,
        client_auto_start = nil,
        workspace_id = "ajdfkafd",
        neovim_version = "stable",
        os = "Linux",
      })
    end)

    after_each(function()
      provider._config_provider:remove_workspace_config(provider.unique_host_id)
    end)

    it("when user does not want to launch client", function()
      provider._config_provider:update_workspace_config(provider.unique_host_id, {
        client_auto_start = false,
      })
      provider:_setup_workspace_variables()

      provider:_launch_local_neovim_client()
      assert
        .stub(notifier_stub).was
        .called_with(provider.notifier, "Run :RemoteSessionInfo to find local client command", vim.log.levels.INFO, true)
    end)

    it("when user wants to launch client", function()
      provider._config_provider:update_workspace_config(provider.unique_host_id, {
        client_auto_start = true,
      })
      provider:_setup_workspace_variables()
      stub(provider, "_wait_for_server_to_be_ready")
      local defined_callback_stub = stub(remote_nvim.config.local_client_config, "callback")

      provider:_launch_local_neovim_client()
      assert.stub(defined_callback_stub).was.called()
    end)
  end)
end)
