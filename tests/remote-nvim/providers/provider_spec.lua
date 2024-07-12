---@diagnostic disable:invisible
describe("Provider", function()
  local assert = require("luassert.assert")
  ---@type remote-nvim.RemoteNeovim
  local remote_nvim = require("remote-nvim")
  local Provider = require("remote-nvim.providers.provider")
  local stub = require("luassert.stub")
  local mock = require("luassert.mock")
  local match = require("luassert.match")
  ---@type remote-nvim.providers.Provider
  local provider
  local provider_host
  local remote_nvim_config_copy
  local progress_viewer
  assert:set_parameter("TableFormatLevel", 1)

  before_each(function()
    provider_host = require("remote-nvim.utils").generate_random_string(6)
    progress_viewer = mock(require("remote-nvim.ui.progressview"), true)
    remote_nvim_config_copy = vim.deepcopy(remote_nvim.config)

    provider = Provider({
      host = provider_host,
      progress_view = progress_viewer,
    })
    stub(vim, "notify")
  end)

  after_each(function()
    remote_nvim.config = remote_nvim_config_copy
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
    local detect_remote_os_and_arch_stub, get_remote_neovim_version_preference_stub
    local workspace_id

    before_each(function()
      workspace_id = require("remote-nvim.utils").generate_random_string(10)
      provider = Provider({
        host = provider_host,
        conn_opts = { "-p", "3011" },
        progress_view = progress_viewer,
      })
      detect_remote_os_and_arch_stub = stub(provider, "_get_remote_os_and_arch")
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
        arch = "x86_64",
        neovim_install_method = "binary",
      })
      detect_remote_os_and_arch_stub.returns("Linux", "x86_64")
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
        arch = "x86_64",
        neovim_install_method = "binary",
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
      assert.equals(("%s/scripts/neovim_download.sh"):format(remote_home), provider._remote_neovim_download_script_path)
      assert.equals(("%s/scripts/neovim_utils.sh"):format(remote_home), provider._remote_neovim_utils_script_path)
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

    it("by correctly setting local copy dirs variables", function()
      remote_nvim.config.remote.copy_dirs = {
        config = {
          base = "a/b",
          dirs = { "c", "d" },
        },
        data = {
          base = "d/e",
          dirs = "*",
          compression = {
            enabled = false,
          },
        },
        cache = {
          base = "f",
          dirs = {},
          compression = {
            enabled = true,
          },
        },
        state = {
          base = "h/e",
          dirs = { "x", "y", "z" },
        },
      }
      provider:_setup_workspace_variables()

      assert.are.same({ "a/b/c", "a/b/d" }, provider._local_path_to_remote_neovim_config)
      assert.are.same({
        data = { "d/e/." },
        cache = {},
        state = { "h/e/x", "h/e/y", "h/e/z" },
      }, provider._local_path_copy_dirs)
    end)
  end)

  describe("should correctly gather available neovim versions", function()
    local offline_mode_config, offline_neovim_version_fetch_stub, online_neovim_version_fetch_stub
    before_each(function()
      offline_mode_config = vim.deepcopy(remote_nvim.config.offline_mode)
      offline_neovim_version_fetch_stub =
        stub(require("remote-nvim.offline-mode"), "get_available_neovim_version_files")
      online_neovim_version_fetch_stub = stub(require("remote-nvim.providers.utils"), "get_valid_neovim_versions")

      stub(provider, "get_selection").returns("stable")

      provider._remote_neovim_version = nil
      provider._remote_os = "Linux"
      provider._remote_neovim_install_method = "binary"
    end)

    it("when in offline mode but GitHub access is turned off", function()
      provider.offline_mode = true
      remote_nvim.config.offline_mode.no_github = true
      offline_neovim_version_fetch_stub.returns({ ["stable"] = "/root/neovim/binary/neovim-stable-linux.appimage" })

      provider:_get_remote_neovim_version_preference("")

      assert
        .stub(offline_neovim_version_fetch_stub).was
        .called_with(provider._remote_os, provider._remote_neovim_install_method)
      assert.stub(online_neovim_version_fetch_stub).was.not_called()
    end)

    it("when in offline mode and GitHub access is not turned off", function()
      provider.offline_mode = true
      remote_nvim.config.offline_mode.no_github = false
      online_neovim_version_fetch_stub.returns({
        { tag = "v0.9.5", commit = "8744ee8783a8597f9fce4a573ae05aca2f412120" },
      })

      provider:_get_remote_neovim_version_preference("")

      assert.stub(offline_neovim_version_fetch_stub).was.not_called()
      assert.stub(online_neovim_version_fetch_stub).was.called()
    end)

    it("when in online mode", function()
      provider.offline_mode = false
      remote_nvim.config.offline_mode.enabled = false

      online_neovim_version_fetch_stub.returns({
        { tag = "stable", commit = "8744ee8783a8597f9fce4a573ae05aca2f412120" },
      })
      provider:_get_remote_neovim_version_preference("")

      assert.stub(offline_neovim_version_fetch_stub).was.not_called()
      assert.stub(online_neovim_version_fetch_stub).was.called()
    end)

    after_each(function()
      remote_nvim.config.offline_mode = offline_mode_config
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
      assert.equals(
        0,
        provider:_handle_job_completion(
          desc,
          progress_viewer:add_progress_node({
            text = "",
            type = "stdout_node",
          })
        )
      )
    end)

    it("when they fail", function()
      executor_job_status_stub.returns(255)

      local co = coroutine.create(function()
        provider:_handle_job_completion(
          desc,
          progress_viewer:add_progress_node({
            text = "",
            type = "stdout_node",
          })
        )
      end)
      local _, ret_or_err = coroutine.resume(co)
      assert.equals(255, ret_or_err)
    end)
  end)

  describe("should correctly handle starting remote neovim", function()
    local is_remote_server_running_stub
    before_each(function()
      is_remote_server_running_stub = stub(provider, "is_remote_server_running")
      is_remote_server_running_stub.returns(false)

      stub(provider, "_setup_workspace_variables")
      stub(provider, "_setup_remote")
      stub(provider, "_launch_remote_neovim_server")
      stub(provider, "_launch_local_neovim_client")
    end)

    it("when it is a start run", function()
      local before_launch_number = provider._neovim_launch_number
      provider:_launch_neovim()
      assert.equals(before_launch_number + 1, provider._neovim_launch_number)
    end)

    it("when it is not a start run", function()
      local before_launch_number = provider._neovim_launch_number
      provider:_launch_neovim(false)
      assert.equals(before_launch_number, provider._neovim_launch_number)
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
        arch = "x86_64",
        neovim_install_method = "binary",
      })
      provider._local_path_to_remote_neovim_config = {}
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
        arch = "x86_64",
        neovim_install_method = "binary",
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
    local job_stop_stub = stub(vim.fn, "jobstop")
    provider._setup_running = true
    provider._remote_server_process_id = 2100

    provider:stop_neovim()
    assert.stub(job_stop_stub).was.called_with(provider._remote_server_process_id)
    assert.is_true(provider._provider_stopped_neovim)
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

  it("should provide correct remote neovim binary paths", function()
    provider._remote_is_windows = false
    provider._remote_neovim_home = "~/.remote-nvim"
    provider._remote_neovim_version = "stable"

    assert.equals("~/.remote-nvim/nvim-downloads/stable", provider:_remote_neovim_binary_dir())
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
      local run_command_stub, upload_stub, offline_mode_config

      before_each(function()
        run_command_stub = stub(provider, "run_command")
        upload_stub = stub(provider, "upload")
        offline_mode_config = vim.deepcopy(remote_nvim.config.offline_mode)

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
          arch = "x86_64",
          neovim_install_method = "binary",
        })
        provider:_setup_workspace_variables()
      end)

      after_each(function()
        remote_nvim.config.offline_mode = offline_mode_config
        provider._config_provider:remove_workspace_config(provider.unique_host_id)
      end)

      it("in default scenario", function()
        provider:_setup_remote()

        -- create directories
        assert.stub(run_command_stub).was.called_with(
          match.is_ref(provider),
          "mkdir -p ~/.remote-nvim/scripts && mkdir -p ~/.remote-nvim/workspaces/akfdjakjfdk/.config/nvim && mkdir -p ~/.remote-nvim/workspaces/akfdjakjfdk/.cache/nvim && mkdir -p ~/.remote-nvim/workspaces/akfdjakjfdk/.local/state/nvim && mkdir -p ~/.remote-nvim/workspaces/akfdjakjfdk/.local/share/nvim && mkdir -p ~/.remote-nvim/nvim-downloads/stable",
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
          "chmod +x ~/.remote-nvim/scripts/neovim_download.sh && chmod +x ~/.remote-nvim/scripts/neovim_utils.sh && chmod +x ~/.remote-nvim/scripts/neovim_install.sh && bash ~/.remote-nvim/scripts/neovim_install.sh -v stable -d ~/.remote-nvim -m binary -a x86_64",
          match.is_string()
        )

        assert.stub(upload_stub).was.called_with(
          match.is_ref(provider),
          provider._local_path_to_remote_neovim_config,
          "~/.remote-nvim/workspaces/akfdjakjfdk/.config/nvim",
          match.is_string(),
          remote_nvim.config.remote.copy_dirs.config.compression
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
          provider._local_path_to_remote_neovim_config,
          "~/.remote-nvim/workspaces/akfdjakjfdk/.config",
          match.is_string(),
          remote_nvim.config.remote.copy_dirs.config.compression
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

      it("when you are in offline mode but GitHub is disabled", function()
        provider.offline_mode = true
        remote_nvim.config.offline_mode.no_github = true

        local release_path = ("%s/nvim-stable-linux.appimage"):format(remote_nvim.config.offline_mode.cache_dir)
        local release_checksum_path = ("%s.sha256sum"):format(release_path)

        provider:_setup_remote()
        assert.stub(upload_stub).was.called_with(match.is_ref(provider), {
          release_path,
          release_checksum_path,
        }, "~/.remote-nvim/nvim-downloads/stable", match.is_string())

        assert.stub(run_command_stub).was.called_with(
          match.is_ref(provider),
          "chmod +x ~/.remote-nvim/scripts/neovim_download.sh && chmod +x ~/.remote-nvim/scripts/neovim_utils.sh && chmod +x ~/.remote-nvim/scripts/neovim_install.sh && bash ~/.remote-nvim/scripts/neovim_install.sh -v stable -d ~/.remote-nvim -m binary -a x86_64 -o",
          match.is_string()
        )
      end)

      it("when you are in offline mode but GitHub is enabled", function()
        provider.offline_mode = true
        remote_nvim.config.offline_mode.no_github = false

        provider:_setup_remote()
        assert.stub(run_command_stub).was.called_with(
          match.is_ref(provider),
          ("bash %s/scripts/neovim_download.sh -o Linux -v stable -a x86_64 -t binary -d %s"):format(
            require("remote-nvim.utils").get_plugin_root(),
            remote_nvim.config.offline_mode.cache_dir
          ),
          match.is_string(),
          nil,
          nil,
          true
        )

        assert.stub(run_command_stub).was.called_with(
          match.is_ref(provider),
          "chmod +x ~/.remote-nvim/scripts/neovim_download.sh && chmod +x ~/.remote-nvim/scripts/neovim_utils.sh && chmod +x ~/.remote-nvim/scripts/neovim_install.sh && bash ~/.remote-nvim/scripts/neovim_install.sh -v stable -d ~/.remote-nvim -m binary -a x86_64 -o",
          match.is_string()
        )
      end)

      it("when additional directories are to be copied", function()
        remote_nvim.config.remote.copy_dirs = {
          config = {
            base = "a/b",
            dirs = { "c", "d" },
          },
          data = {
            base = "data-path",
            dirs = "*",
            compression = {
              enabled = false,
            },
          },
          cache = {
            base = "cache-path",
            dirs = { "dir1", "dir2" },
            compression = {
              enabled = true,
            },
          },
          state = {
            base = "state-path",
            dirs = {},
          },
        }

        provider:_setup_workspace_variables()
        provider:_setup_remote()

        assert.stub(upload_stub).was.called_with(
          match.is_ref(provider),
          { "cache-path/dir1", "cache-path/dir2" },
          "~/.remote-nvim/workspaces/akfdjakjfdk/.cache/nvim",
          match.is_string(),
          remote_nvim.config.remote.copy_dirs.cache.compression
        )
        assert.stub(upload_stub).was.not_called_with(
          match.is_ref(provider),
          { "state-path" },
          "~/.remote-nvim/workspaces/akfdjakjfdk/.local/state/nvim",
          match.is_string(),
          remote_nvim.config.remote.copy_dirs.state.compression
        )
        assert.stub(upload_stub).was.called_with(
          match.is_ref(provider),
          { "data-path/." },
          "~/.remote-nvim/workspaces/akfdjakjfdk/.local/share/nvim",
          match.is_string(),
          remote_nvim.config.remote.copy_dirs.data.compression
        )
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
        arch = "x86_64",
        neovim_install_method = "binary",
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
          "XDG_CONFIG_HOME=~/.remote-nvim/workspaces/ajfdalfj/.config XDG_DATA_HOME=~/.remote-nvim/workspaces/ajfdalfj/.local/share XDG_STATE_HOME=~/.remote-nvim/workspaces/ajfdalfj/.local/state XDG_CACHE_HOME=~/.remote-nvim/workspaces/ajfdalfj/.cache NVIM_APPNAME=nvim ~/.remote-nvim/nvim-downloads/stable/bin/nvim --listen 0.0.0.0:32123 --headless",
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
          "XDG_CONFIG_HOME=~/.remote-nvim/workspaces/ajfdalfj/.config XDG_DATA_HOME=~/.remote-nvim/workspaces/ajfdalfj/.local/share XDG_STATE_HOME=~/.remote-nvim/workspaces/ajfdalfj/.local/state XDG_CACHE_HOME=~/.remote-nvim/workspaces/ajfdalfj/.cache NVIM_APPNAME=nvim ~/.remote-nvim/nvim-downloads/stable/bin/nvim --listen 0.0.0.0:32123 --headless --cmd ':cd /home/test-user'",
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
        arch = "x86_64",
        neovim_install_method = "binary",
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
        arch = "x86_64",
        neovim_install_method = "binary",
      })
    end)

    after_each(function()
      provider._config_provider:remove_workspace_config(provider.unique_host_id)
    end)

    it("when user does not want to launch client", function()
      provider._config_provider:update_workspace_config(provider.unique_host_id, {
        client_auto_start = false,
      })
      local defined_callback_stub = stub(remote_nvim.config, "client_callback")
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
      local defined_callback_stub = stub(remote_nvim.config, "client_callback")

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
