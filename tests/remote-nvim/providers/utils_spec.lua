local assert = require("luassert.assert")
local stub = require("luassert.stub")
local utils = require("remote-nvim.providers.utils")
local is_greater_version = utils.is_greater_neovim_version

describe("Input is handled correctly", function()
  local input_stub, secret_input_stub

  before_each(function()
    input_stub = stub(vim.fn, "input")
    secret_input_stub = stub(vim.fn, "inputsecret")
  end)

  it("when input type is unspecified", function()
    local input_label = "Input label"
    utils.get_input(input_label)

    assert.stub(secret_input_stub).was.not_called()
    assert.stub(input_stub).was.called_with(input_label)
  end)

  it("when input type is secret", function()
    local input_label = "Input label"
    utils.get_input(input_label, "secret")

    assert.stub(input_stub).was.not_called()
    assert.stub(secret_input_stub).was.called_with(input_label)
  end)

  it("when input type is plain", function()
    local input_label = "Input label"
    utils.get_input(input_label, "plain")

    assert.stub(secret_input_stub).was.not_called()
    assert.stub(input_stub).was.called_with(input_label)
  end)
end)

describe("Greater version finder should", function()
  it("return nightly greater than stable", function()
    assert.is_false(is_greater_version("nightly", "nightly"))
    assert.is_false(is_greater_version("nightly", "stable"))
    assert.is_false(is_greater_version("nightly", "v0.9.5"))
  end)
  it("return stable greater than any version", function()
    assert.is_true(is_greater_version("stable", "nightly"))
    assert.is_false(is_greater_version("stable", "stable"))
    assert.is_true(is_greater_version("stable", "v0.9.5"))
  end)
  it("handle regular comparison", function()
    assert.is_true(is_greater_version("v0.9.4", "v0.9.3"))
    assert.is_false(is_greater_version("v0.9.4", "v0.9.4"))
    assert.is_false(is_greater_version("v0.9.3", "v0.9.4"))
    assert.is_true(is_greater_version("v0.9.4", "nightly"))
    assert.is_false(is_greater_version("v0.9.4", "stable"))
  end)

  it("raise assert when invalid versions are passed", function()
    assert.error_matches(function()
      is_greater_version("v0.9", "v0.9.3")
    end, "Invalid version passed 'v0.9'")
    assert.error_matches(function()
      is_greater_version("v0.9.4", "v0.11")
    end, "Invalid version passed 'v0.11'")
  end)
end)

describe("Offline revision names are correct", function()
  it("for source release", function()
    assert.equals(
      "nvim-stable-source.tar.gz",
      utils.get_offline_neovim_release_name("Linux", "stable", "x86_64", "source")
    )
    assert.equals(
      "nvim-nightly-source.tar.gz",
      utils.get_offline_neovim_release_name("Linux", "nightly", "x86_64", "source")
    )
    assert.equals(
      "nvim-v0.9.5-source.tar.gz",
      utils.get_offline_neovim_release_name("macOS", "v0.9.5", "x86_64", "source")
    )
  end)

  it("for macOS", function()
    assert.equals(
      "nvim-stable-macos-x86_64.tar.gz",
      utils.get_offline_neovim_release_name("macOS", "stable", "x86_64", "binary")
    )
    assert.equals(
      "nvim-nightly-macos-x86_64.tar.gz",
      utils.get_offline_neovim_release_name("macOS", "nightly", "x86_64", "binary")
    )
    assert.equals(
      "nvim-v0.9.5-macos.tar.gz",
      utils.get_offline_neovim_release_name("macOS", "v0.9.5", "x86_64", "binary")
    )
    assert.equals(
      "nvim-v0.10.1-macos-arm64.tar.gz",
      utils.get_offline_neovim_release_name("macOS", "v0.10.1", "arm64", "binary")
    )
  end)

  it("for Linux", function()
    assert.equals(
      "nvim-stable-linux-x86_64.appimage",
      utils.get_offline_neovim_release_name("Linux", "stable", "x86_64", "binary")
    )
    assert.equals(
      "nvim-nightly-linux-x86_64.appimage",
      utils.get_offline_neovim_release_name("Linux", "nightly", "x86_64", "binary")
    )
    assert.equals(
      "nvim-v0.9.5-linux.appimage",
      utils.get_offline_neovim_release_name("Linux", "v0.9.5", "x86_64", "binary")
    )
    assert.equals(
      "nvim-v0.10.4-linux-x86_64.appimage",
      utils.get_offline_neovim_release_name("Linux", "v0.10.4", "x86_64", "binary")
    )
  end)
end)

describe("Binary release is available for", function()
  it("macOS and Windows", function()
    assert.is_true(utils.is_binary_release_available("macOS", "anything_goes"))
    assert.is_true(utils.is_binary_release_available("Windows", "anything_goes"))
  end)

  it("Linux but not for RISC and ARM", function()
    assert.is_true(utils.is_binary_release_available("Linux", "x86_64"))
    assert.is_false(utils.is_binary_release_available("Linux", "arm64"))
    assert.is_false(utils.is_binary_release_available("Linux", "armv7l"))
    assert.is_false(utils.is_binary_release_available("Linux", "riscv64"))
  end)
end)
