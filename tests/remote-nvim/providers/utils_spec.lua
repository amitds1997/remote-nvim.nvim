local match = require("luassert.match")
local stub = require("luassert.stub")
local utils = require("remote-nvim.providers.utils")

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
