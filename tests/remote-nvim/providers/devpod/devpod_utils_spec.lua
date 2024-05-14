local remote_nvim = require("remote-nvim")
---@diagnostic disable: missing-fields
local assert = require("luassert.assert")
local utils = require("remote-nvim.providers.devpod.devpod_utils")

describe("Devpod provider options are correctly generated", function()
  it("when there are no options passed", function()
    assert.are.same({
      conn_opts = {},
      devpod_opts = {},
    }, utils.get_devpod_provider_opts({}))
  end)

  it("when devpod source information is present", function()
    assert.are.same(
      {
        conn_opts = {},
        devpod_opts = {
          source = "panda",
        },
      },
      utils.get_devpod_provider_opts({
        devpod_opts = {
          source = "panda",
        },
      })
    )

    assert.are.same(
      {
        host = "panda",
        conn_opts = {},
        devpod_opts = {
          source = "panda",
        },
      },
      utils.get_devpod_provider_opts({
        host = "panda",
      })
    )
  end)

  it("when unique host ID is present", function()
    assert.are.same(
      {
        conn_opts = {},
        unique_host_id = "panda",
        devpod_opts = {},
      },
      utils.get_devpod_provider_opts({
        unique_host_id = "panda",
      })
    )

    assert.are.same(
      {
        conn_opts = {},
        unique_host_id = "panda",
        devpod_opts = {},
      },
      utils.get_devpod_provider_opts({
        unique_host_id = "PANDA",
      })
    )

    assert.are.same(
      {
        conn_opts = {},
        unique_host_id = "panda-panda-panda-panda-panda-panda-panda-panda-",
        devpod_opts = {},
      },
      utils.get_devpod_provider_opts({
        unique_host_id = "panda-panda-panda-panda-panda-panda-panda-panda-panda-panda",
      })
    )
  end)

  describe("while handling configuration", function()
    local remote_nvim_config_copy

    before_each(function()
      remote_nvim_config_copy = vim.deepcopy(remote_nvim.config)
    end)

    after_each(function()
      remote_nvim.config = remote_nvim_config_copy
    end)

    it("for gpg agent forwarding", function()
      remote_nvim.config.devpod.gpg_agent_forwarding = true
      assert.are.same({
        conn_opts = { "--gpg-agent-forwarding" },
        devpod_opts = {},
      }, utils.get_devpod_provider_opts({}))
    end)

    it("for dotfiles", function()
      remote_nvim.config.devpod.dotfiles = {
        path = "https://github.com/amitds1997/dotfiles",
      }
      assert.are.same({
        conn_opts = { "--dotfiles=https://github.com/amitds1997/dotfiles" },
        devpod_opts = {},
      }, utils.get_devpod_provider_opts({}))

      remote_nvim.config.devpod.dotfiles = {
        path = "https://github.com/amitds1997/dotfiles",
        install_script = "install.sh",
      }

      assert.are.same({
        conn_opts = { "--dotfiles=https://github.com/amitds1997/dotfiles", "--dotfiles-script=install.sh" },
        devpod_opts = {},
      }, utils.get_devpod_provider_opts({}))
    end)
  end)

  describe("when devpod provider is passed", function()
    assert.are.same(
      {
        conn_opts = { "--provider=panda" },
        devpod_opts = {
          provider = "panda",
        },
      },
      utils.get_devpod_provider_opts({
        devpod_opts = {
          provider = "panda",
        },
      })
    )
  end)
end)

describe("Correct unique host ID is generated from devcontainer path", function()
  assert.equals(
    "magic-path/project-1/devcontainer-project",
    utils.get_devcontainer_unique_host("/Users/amitsingh/magic-path/project-1/devcontainer-project/")
  )
end)
