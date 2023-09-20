local ConfigProvider = require("remote-nvim.config")
local stub = require("luassert.stub")

describe("Config", function()
  local config_provider
  before_each(function()
    config_provider = ConfigProvider()
    stub(config_provider._config_path, "write")
    config_provider._config_data = {
      ["localhost:9111"] = {
        workspace_id = "4QdRIosKG6",
        remote_neovim_home = "~/.remote-nvim",
        host = "localhost",
        provider = "ssh",
        connection_options = "-p 9111",
      },
      ["vscode-remote-try-node.devpod"] = {
        neovim_version = "v0.9.2",
        workspace_id = "hCqp3hSupA",
        remote_neovim_home = "~/.remote-nvim",
        host = "vscode-remote-try-node.devpod",
        connection_options = "",
        provider = "ssh",
        os = "Linux",
      },
      ["test-container"] = {
        neovim_version = "v0.9.2",
        workspace_id = "uPdc3uFhcN",
        remote_neovim_home = "~/.remote-nvim",
        host = "test-container",
        connection_options = "",
        provider = "docker",
        os = "Linux",
      },
    }
  end)

  describe("should fetch workspace config correctly", function()
    it("when both provider type and host identifier is specified", function()
      assert.are.same(
        config_provider:get_workspace_config("localhost:9111", "ssh"),
        config_provider._config_data["localhost:9111"]
      )
    end)

    it("when provider type is specified but host identifier is missing", function()
      assert.are.same(config_provider:get_workspace_config(nil, "ssh"), {
        ["localhost:9111"] = {
          workspace_id = "4QdRIosKG6",
          remote_neovim_home = "~/.remote-nvim",
          host = "localhost",
          provider = "ssh",
          connection_options = "-p 9111",
        },
        ["vscode-remote-try-node.devpod"] = {
          neovim_version = "v0.9.2",
          workspace_id = "hCqp3hSupA",
          remote_neovim_home = "~/.remote-nvim",
          host = "vscode-remote-try-node.devpod",
          connection_options = "",
          provider = "ssh",
          os = "Linux",
        },
      })
    end)

    it("when host identifier is specified but provider type is missing", function()
      assert.are.same(config_provider:get_workspace_config("test-container", nil), {
        neovim_version = "v0.9.2",
        workspace_id = "uPdc3uFhcN",
        remote_neovim_home = "~/.remote-nvim",
        host = "test-container",
        connection_options = "",
        provider = "docker",
        os = "Linux",
      })
    end)

    it("when neither provider type or host identifier is specified", function()
      assert.are.same(config_provider:get_workspace_config(nil, nil), config_provider._config_data)
    end)
  end)

  it("should fetch existing host identifiers correctly", function()
    local host_ids = config_provider:get_host_ids()

    -- We sort them both since map -> array does not guarantee order and is not important for us
    table.sort(host_ids)
    local expected_host_ids = { "localhost:9111", "test-container", "vscode-remote-try-node.devpod" }
    table.sort(expected_host_ids)

    assert.is_true(vim.tbl_islist(host_ids))
    assert.are.same(host_ids, expected_host_ids)
  end)

  describe("should add host configuration properly", function()
    local host_id, wk_config, update_workspace_config
    before_each(function()
      update_workspace_config = stub(config_provider, "update_workspace_config")
      host_id = "localhost:9112"
      wk_config = {
        workspace_id = "4QdRIosKG6",
        remote_neovim_home = "~/.remote-nvim",
        host = "localhost",
        provider = "ssh",
        connection_options = "-p 9112",
      }
    end)

    it("when no configuration is provided", function()
      assert.error_matches(function()
        config_provider:add_workspace_config(host_id, nil)
      end, "Workspace config cannot be nil")
    end)

    it("when configuration is provided", function()
      config_provider:add_workspace_config(host_id, wk_config)
      assert.stub(update_workspace_config).was.called_with(config_provider, host_id, wk_config)
    end)
  end)

  it("should remove host configuration properly", function()
    local update_workspace_config = stub(config_provider, "update_workspace_config")
    local host_id = "localhost:9112"

    config_provider:remove_workspace_config(host_id)
    assert.stub(update_workspace_config).was.called_with(config_provider, host_id, nil)
  end)

  describe("should update host configuration properly", function()
    local host_id, wk_config

    before_each(function()
      host_id = "localhost:9112"
      wk_config = {
        workspace_id = "4DqEVbfXT6",
        remote_neovim_home = "~/.remote-nvim",
        host = "localhost",
        provider = "ssh",
        connection_options = "-p 9112",
      }
      config_provider._config_data[host_id] = wk_config
    end)

    it("when update configuration is nil", function()
      assert.are.same(config_provider:update_workspace_config(host_id, nil), nil)
    end)
    it("when update configuration is empty", function()
      assert.are.same(config_provider:update_workspace_config(host_id, {}), wk_config)
    end)

    it("when update configuration contains existing keys", function()
      assert.are.same(
        config_provider:update_workspace_config(host_id, {
          connection_options = "",
          workspace_id = "6PrUBftXT6",
        }),
        {
          workspace_id = "6PrUBftXT6",
          remote_neovim_home = "~/.remote-nvim",
          host = "localhost",
          provider = "ssh",
          connection_options = "",
        }
      )
    end)
  end)
end)
