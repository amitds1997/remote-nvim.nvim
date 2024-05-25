local DevpodProvider = require("remote-nvim.providers.devpod.devpod_provider")
local assert = require("luassert.assert")
local mock = require("luassert.mock")
local remote_nvim = require("remote-nvim")
local stub = require("luassert.stub")

describe("Provider", function()
  local progress_viewer, executable_stub
  before_each(function()
    progress_viewer = mock(require("remote-nvim.ui.progressview"), true)
    executable_stub = stub(vim.fn, "executable")
    executable_stub.returns(1)
  end)

  describe("should initialize correctly", function()
    it("and raise error when unique host ID is not provided", function()
      assert.error_matches(function()
        DevpodProvider({
          unique_host_id = nil,
          host = "localhost",
          devpod_opts = {
            source = "docker",
            source_opts = {
              type = "image",
            },
          },
          progress_view = progress_viewer,
        })
      end, "Unique host ID cannot be nil")
    end)
    it("and raise error when host is not provided", function()
      assert.error_matches(function()
        DevpodProvider({
          unique_host_id = "unique-local-host",
          host = nil,
          devpod_opts = {
            source = "docker",
            source_opts = {
              type = "image",
            },
          },
          progress_view = progress_viewer,
        })
      end, "Host cannot be nil")
    end)
    it("and raise error when devpod options is not provided", function()
      assert.error_matches(function()
        DevpodProvider({
          unique_host_id = "unique-local-host",
          host = "localhost",
          devpod_opts = nil,
          progress_view = progress_viewer,
        })
      end, "Devpod options should not be nil")
    end)
    it("and raise error when devpod source is not provided", function()
      assert.error_matches(function()
        DevpodProvider({
          unique_host_id = "unique-local-host",
          host = "localhost",
          devpod_opts = {
            source = nil,
            source_opts = {
              type = "image",
            },
          },
          progress_view = progress_viewer,
        })
      end, "Source should not be nil")
    end)
    it("when necessary arguments are provided", function()
      local provider = DevpodProvider({
        unique_host_id = "unique-local-host",
        host = "localhost",
        devpod_opts = {
          source = "docker",
          source_opts = {
            type = "image",
          },
        },
        progress_view = progress_viewer,
      })
      local ssh_config_path = remote_nvim.config.devpod.ssh_config_path

      assert.equals("unique-local-host.devpod", provider.host)
      assert.are.same({ "-F", ssh_config_path }, provider.ssh_conn_opts)
      assert.are.same({
        "--open-ide=false",
        "--configure-ssh=true",
        "--ide=none",
        ("--ssh-config=%s"):format(ssh_config_path),
        "--log-output=raw",
      }, provider.launch_opts)
    end)

    it("does not add ssh-config details for existing devpod workspace", function()
      local provider = DevpodProvider({
        unique_host_id = "unique-local-host",
        host = "localhost",
        devpod_opts = {
          source = "docker",
          source_opts = {
            type = "existing",
          },
        },
        progress_view = progress_viewer,
      })

      assert.are.same({}, provider.ssh_conn_opts)
      assert.are.same({
        "--open-ide=false",
        "--configure-ssh=true",
        "--ide=none",
        "--log-output=raw",
      }, provider.launch_opts)
    end)
  end)

  describe("should launch devpod workspace correctly", function()
    local provider, handler_setup_stub

    before_each(function()
      provider = DevpodProvider({
        unique_host_id = "unique-local-host",
        host = "localhost",
        devpod_opts = {
          source = "docker",
          source_opts = {
            type = "image",
          },
        },
        progress_view = progress_viewer,
      })
      handler_setup_stub = stub(provider, "_handle_provider_setup")
    end)

    it("when a workspace is already active", function()
      provider._devpod_workspace_active = true
      provider:_launch_devpod_workspace()
      assert.stub(handler_setup_stub).was.not_called()
    end)

    it("when no workspace is active", function()
      stub(provider.local_provider, "run_command")
      provider._devpod_workspace_active = false

      provider:_launch_devpod_workspace()
      assert.stub(handler_setup_stub).was.called()
      assert.is_true(provider._devpod_workspace_active)
    end)
  end)
end)
