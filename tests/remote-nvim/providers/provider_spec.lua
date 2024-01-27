---@diagnostic disable:invisible
describe("Provider", function()
  local assert = require("luassert.assert")
  local remote_nvim = require("remote-nvim")
  local Provider = require("remote-nvim.providers.provider")
  local stub = require("luassert.stub")
  local mock = require("luassert.mock")
  local match = require("luassert.match")
  ---@type remote-nvim.providers.Provider
  local provider
  local provider_host
  local progress_viewer

  before_each(function()
    provider_host = require("remote-nvim.utils").generate_random_string(6)
    progress_viewer = mock(require("remote-nvim.ui.progressview"), true)

    provider = Provider({
      host = provider_host,
      progress_view = progress_viewer,
    })
    stub(vim, "notify")
  end)

  describe("should handle array-type connections options", function()
    it("when it is not empty", function()
      provider = Provider({
        host = provider_host,
        conn_opts = { "-p", "3011", "-t", "-x" },
        progress_view = progress_viewer,
      })
      assert.equals("-p 3011 -t -x", provider.conn_opts)
    end)

    it("when it is an empty array", function()
      provider = Provider({
        host = provider_host,
        conn_opts = {},
        progress_view = progress_viewer,
      })
      assert.equals("", provider.conn_opts)
    end)
  end)

  it("should handle missing connection options correctly", function()
    provider = Provider({
      host = provider_host,
      progress_view = progress_viewer,
    })
    assert.equals("", provider.conn_opts)

    provider = Provider({ host = provider_host, conn_opts = nil, progress_view = progress_viewer })
    assert.equals("", provider.conn_opts)
  end)

  it("should correctly set unique host ID when passed manually as an option", function()
    local unique_host_id = "custom-host-id"
    provider = Provider({
      host = provider_host,
      unique_host_id = unique_host_id,
      progress_view = progress_viewer,
    })
    assert.equals(unique_host_id, provider.unique_host_id)
  end)

  describe("should handle setting workspace variables", function()
    local detect_remote_os_stub, get_remote_neovim_version_preference_stub
    local workspace_id = require("remote-nvim.utils").generate_random_string(10)

    before_each(function()
      provider = Provider({
        host = provider_host,
        conn_opts = { "-p", "3011" },
        progress_view = progress_viewer,
      })
      detect_remote_os_stub = stub(provider, "_get_remote_os")
      get_remote_neovim_version_preference_stub = stub(provider, "_get_remote_neovim_version_preference")

      provider._config_provider:add_workspace_config(provider.unique_host_id, {
        provider = "local",
        host = provider.host,
        connection_options = provider.conn_opts,
        remote_neovim_home = ".remote-nvim",
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

    it("by creating new workspace config record when does not exist if able to connect to remote machine", function()
      provider._config_provider:remove_workspace_config(provider.unique_host_id)
      provider:_setup_workspace_variables()

      assert.are.same({
        provider = "local",
        host = provider.host,
        connection_options = provider.conn_opts,
        remote_neovim_home = provider._remote_neovim_home,
        config_copy = nil,
        client_auto_start = nil,
        workspace_id = workspace_id,
        neovim_version = "stable",
        os = "Linux",
      }, provider._config_provider:get_workspace_config(provider.unique_host_id))
    end)

    it("by not creating workspace config record if not able to connect to remote", function()
      provider._config_provider:remove_workspace_config(provider.unique_host_id)
      local executor_job_status_stub = stub(provider.executor, "last_job_status")
      executor_job_status_stub.returns(255)

      local co = coroutine.create(function()
        provider:_setup_workspace_variables()
      end)
      coroutine.resume(co)
      assert(vim.tbl_isempty(provider._config_provider:get_workspace_config(provider.unique_host_id)))
    end)

    it("by setting up remote OS if not set", function()
      provider._config_provider:update_workspace_config(provider.unique_host_id, {
        os = nil,
      })
      provider:_setup_workspace_variables()

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal("Linux", wk_config["os"])
    end)

    it("by setting up remote Neovim if not set", function()
      provider._config_provider:add_workspace_config(provider.unique_host_id, {
        neovim_version = nil,
      })
      provider:_setup_workspace_variables()

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal("stable", wk_config["neovim_version"])
    end)

    it("by correctly setting workspace variables", function()
      provider:_setup_workspace_variables()
      local remote_home = provider._remote_neovim_home

      assert.equals("Linux", provider._remote_os)
      assert.equals(false, provider._remote_is_windows)
      assert.equals("stable", provider._remote_neovim_version)
      assert.equals(workspace_id, provider._remote_workspace_id)
      assert.equals(remote_home, provider._remote_neovim_home)
      assert.equals(("%s/workspaces"):format(remote_home), provider._remote_workspaces_path)
      assert.equals(("%s/scripts"):format(remote_home), provider._remote_scripts_path)
      assert.equals(("%s/scripts/neovim_install.sh"):format(remote_home), provider._remote_neovim_install_script_path)
      assert.equals(("%s/workspaces/%s"):format(remote_home, workspace_id), provider._remote_workspace_id_path)

      -- XDG variables
      assert.equals(("%s/workspaces/%s/.config"):format(remote_home, workspace_id), provider._remote_xdg_config_path)
      assert.equals(("%s/workspaces/%s/.cache"):format(remote_home, workspace_id), provider._remote_xdg_cache_path)
      assert.equals(("%s/workspaces/%s/.local/share"):format(remote_home, workspace_id), provider._remote_xdg_data_path)
      assert.equals(
        ("%s/workspaces/%s/.local/state"):format(remote_home, workspace_id),
        provider._remote_xdg_state_path
      )

      -- Remote config path
      assert.equals(
        ("%s/workspaces/%s/.config/nvim"):format(remote_home, workspace_id),
        provider._remote_neovim_config_path
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
      assert.equals(0, provider:_handle_job_completion(desc))
    end)

    it("when they fail", function()
      executor_job_status_stub.returns(255)

      local co = coroutine.create(function()
        provider:_handle_job_completion(desc)
      end)
      local _, ret_or_err = coroutine.resume(co)
      assert.equals(255, ret_or_err)
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
      local _, ret_or_err = coroutine.resume(co)
      assert.equals(nil, ret_or_err)
    end)

    it("when choice selection is done", function()
      local choice = "choice"
      get_selection_stub.returns(choice)
      assert.equals(choice, provider:get_selection({}, {}))
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
        remote_neovim_home = ".remote-nvim",
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
      assert.equals(true, provider:_get_neovim_config_upload_preference())

      provider._config_provider:update_workspace_config(provider.unique_host_id, {
        config_copy = false,
      })
      provider:_setup_workspace_variables()
      assert.equals(false, provider:_get_neovim_config_upload_preference())
    end)

    it("when the choice is 'Yes (always)'", function()
      selection_stub.returns("Yes (always)")
      assert.equals(true, provider:_get_neovim_config_upload_preference())

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(true, wk_config["config_copy"])
    end)

    it("when the choice is 'No (never)'", function()
      selection_stub.returns("No (never)")
      assert.equals(false, provider:_get_neovim_config_upload_preference())

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(false, wk_config["config_copy"])
    end)

    it("when the choice is 'Yes'", function()
      selection_stub.returns("Yes")
      assert.equals(true, provider:_get_neovim_config_upload_preference())

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(nil, wk_config["config_copy"]) -- The value should not be stored
    end)

    it("when the choice is 'No'", function()
      selection_stub.returns("No")
      assert.equals(false, provider:_get_neovim_config_upload_preference())

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(nil, wk_config["config_copy"]) -- The value should not be stored
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
        remote_neovim_home = ".remote-nvim",
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
        ("rm -rf %s"):format(provider._remote_workspace_id_path),
        match.is_string(),
        nil,
        match.is_function()
      )
      assert.are.same({}, provider._config_provider:get_workspace_config(provider.unique_host_id))
    end)

    it("when asked to cleanup entire remote neovim directory", function()
      selection_stub.returns("Delete remote neovim from remote host (Nuke it!)")

      provider:clean_up_remote_host()
      assert.stub(run_command_stub).was.called_with(
        match.is_ref(provider),
        ("rm -rf %s"):format(provider._remote_neovim_home),
        match.is_string(),
        nil,
        match.is_function()
      )
      assert.are.same({}, provider._config_provider:get_workspace_config(provider.unique_host_id))
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
      assert.equals(false, provider._setup_running)
      assert.equals(nil, provider._remote_server_process_id)
      assert.equals(nil, provider._local_free_port)
    end)
  end)

  it("should stop running remote server if needed", function()
    local system_stub = stub(vim, "system")
    provider._setup_running = true
    provider._remote_server_process_id = 2100
    provider._local_free_port = "52212"

    provider:stop_neovim()
    assert
      .stub(system_stub).was
      .called_with({ "nvim", "--server", "localhost:52212", "--remote-send", ":qall!<CR>" }, { text = true }, match.is_function())
  end)

  describe("should determine correctly if remote server is running", function()
    it("when we do not have a registered process id", function()
      provider._remote_server_process_id = nil
      assert.equals(false, provider:is_remote_server_running())
    end)

    describe("when we have a registered process", function()
      local job_wait_stub

      before_each(function()
        provider._remote_server_process_id = 21
        job_wait_stub = stub(vim.fn, "jobwait")
      end)

      it("and it is still running", function()
        job_wait_stub.returns({ -1 })
        assert.equals(true, provider:is_remote_server_running())
      end)

      it("but it is no longer running", function()
        job_wait_stub.returns({ 0 })
        assert.equals(false, provider:is_remote_server_running())
      end)
    end)
  end)

  it("should provide correct remote neovim binary path", function()
    provider._remote_is_windows = false
    provider._remote_neovim_home = "~/.remote-nvim"
    provider._remote_neovim_version = "stable"

    assert.equals("~/.remote-nvim/nvim-downloads/stable/bin/nvim", provider:_remote_neovim_binary_path())
  end)

  it("should return same remote neovim path over multiple calls", function()
    stub(provider, "run_command")
    local output_stub = stub(provider.executor, "job_stdout")
    output_stub.returns({ "/home/test-user" })
    provider._remote_neovim_home = nil

    provider:_get_remote_neovim_home()
    assert.equals("/home/test-user/.remote-nvim", provider._remote_neovim_home)
    assert.equals(provider._remote_neovim_home, provider:_get_remote_neovim_home())
    assert.equals(provider:_get_remote_neovim_home(), provider:_get_remote_neovim_home())
  end)

  describe("should handle remote setup correctly", function()
    it("when another setup is already running", function()
      provider._setup_running = true

      provider:_setup_remote()
      local run_command_stub = stub(provider, "run_command")
      assert.stub(run_command_stub).was.not_called()
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
          match.is_string()
        )

        -- copy scripts
        assert
          .stub(upload_stub).was
          .called_with(
            match.is_ref(provider),
            require("plenary.path"):new("scripts"):absolute(),
            "~/.remote-nvim",
            match.is_string()
          )

        -- install neovim if needed
        assert.stub(run_command_stub).was.called_with(
          match.is_ref(provider),
          "chmod +x ~/.remote-nvim/scripts/neovim_install.sh && ~/.remote-nvim/scripts/neovim_install.sh -v stable -d ~/.remote-nvim",
          match.is_string()
        )

        assert.stub(upload_stub).was.called_with(
          match.is_ref(provider),
          remote_nvim.config.neovim_user_config_path,
          "~/.remote-nvim/workspaces/akfdjakjfdk/.config",
          match.is_string()
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
          match.is_string()
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
          match.is_string()
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

    describe("when launching a remote server", function()
      local output_stub, local_free_port_stub
      before_each(function()
        output_stub = stub(provider.executor, "job_stdout")
        local_free_port_stub = stub(require("remote-nvim.providers.utils"), "find_free_port")
        is_remote_server_running_stub.returns(false)
        output_stub.returns({ 32123 })
        local_free_port_stub.returns(52232)
      end)

      it("with no set working directory", function()
        provider:_launch_remote_neovim_server()
        assert.stub(run_command_stub).was.called_with(
          match.is_ref(provider),
          "~/.remote-nvim/nvim-downloads/stable/bin/nvim -l ~/.remote-nvim/scripts/free_port_finder.lua",
          match.is_string()
        )
        assert.stub(local_free_port_stub).was.called()
        assert.stub(run_command_stub).was.called_with(
          match.is_ref(provider),
          "XDG_CONFIG_HOME=~/.remote-nvim/workspaces/ajfdalfj/.config XDG_DATA_HOME=~/.remote-nvim/workspaces/ajfdalfj/.local/share XDG_STATE_HOME=~/.remote-nvim/workspaces/ajfdalfj/.local/state XDG_CACHE_HOME=~/.remote-nvim/workspaces/ajfdalfj/.cache ~/.remote-nvim/nvim-downloads/stable/bin/nvim --listen 0.0.0.0:32123 --headless",
          match.is_string(),
          "-t -L 52232:localhost:32123",
          match.is_function()
        )
      end)

      it("when a working directory is set", function()
        provider._remote_working_dir = "/home/test-user"
        provider:_launch_remote_neovim_server()
        assert.stub(run_command_stub).was.called_with(
          match.is_ref(provider),
          "~/.remote-nvim/nvim-downloads/stable/bin/nvim -l ~/.remote-nvim/scripts/free_port_finder.lua",
          match.is_string()
        )
        assert.stub(local_free_port_stub).was.called()
        assert.stub(run_command_stub).was.called_with(
          match.is_ref(provider),
          "XDG_CONFIG_HOME=~/.remote-nvim/workspaces/ajfdalfj/.config XDG_DATA_HOME=~/.remote-nvim/workspaces/ajfdalfj/.local/share XDG_STATE_HOME=~/.remote-nvim/workspaces/ajfdalfj/.local/state XDG_CACHE_HOME=~/.remote-nvim/workspaces/ajfdalfj/.cache ~/.remote-nvim/nvim-downloads/stable/bin/nvim --listen 0.0.0.0:32123 --headless --cmd ':cd /home/test-user'",
          match.is_string(),
          "-t -L 52232:localhost:32123",
          match.is_function()
        )
      end)
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
        remote_neovim_home = ".remote-nvim",
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
      assert.equals(true, provider:_get_local_client_start_preference())

      provider._config_provider:update_workspace_config(provider.unique_host_id, {
        client_auto_start = false,
      })
      provider:_setup_workspace_variables()
      assert.equals(false, provider:_get_local_client_start_preference())
    end)

    it("when the choice is 'Yes (always)'", function()
      selection_stub.returns("Yes (always)")
      assert.equals(true, provider:_get_local_client_start_preference())

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(true, wk_config["client_auto_start"])
    end)

    it("when the choice is 'No (never)'", function()
      selection_stub.returns("No (never)")
      assert.equals(false, provider:_get_local_client_start_preference())

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(false, wk_config["client_auto_start"])
    end)

    it("when the choice is 'Yes'", function()
      selection_stub.returns("Yes")
      assert.equals(true, provider:_get_local_client_start_preference())

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(nil, wk_config["client_auto_start"])
    end)

    it("when the choice is 'No'", function()
      selection_stub.returns("No")
      assert.equals(false, provider:_get_local_client_start_preference())

      local wk_config = provider._config_provider:get_workspace_config(provider.unique_host_id)
      assert.are.equal(nil, wk_config["client_auto_start"])
    end)
  end)

  describe("should handle local client launch correctly", function()
    before_each(function()
      provider._config_provider:add_workspace_config(provider.unique_host_id, {
        provider = provider.provider_type,
        host = provider.host,
        connection_options = provider.conn_opts,
        remote_neovim_home = ".remote-nvim",
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
      local defined_callback_stub = stub(remote_nvim.config.local_client_config, "callback")
      provider:_setup_workspace_variables()
      provider:_launch_local_neovim_client()
      assert.stub(defined_callback_stub).was.not_called()
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

  describe("should handle uploading correctly", function()
    it("when local upload path does not exist", function()
      assert.error_matches(function()
        provider:upload("dkjfakdjf", "akjdfkd", "Upload data")
      end, "Local path 'dkjfakdjf' does not exist")
    end)
  end)
end)
