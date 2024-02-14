local assert = require("luassert.assert")

describe("Deque", function()
  local d

  before_each(function()
    d = require("remote-nvim.structs.deque")()
  end)

  it("should push/pop element to left", function()
    d:pushleft(3)
    d:pushleft(4)
    d:pushleft(5)

    assert.equals(5, d:popleft())
    assert.equals(4, d:popleft())
    assert.equals(3, d:popright())
  end)

  it("should push/pop element to right", function()
    d:pushright(3)
    d:pushright(4)
    d:pushright(5)

    assert.equals(5, d:popright())
    assert.equals(3, d:popleft())
    assert.equals(4, d:popright())
  end)

  it("should correctly report if it is empty", function()
    assert.is_true(d:is_empty())
    d:pushleft(3)
    d:pushright(4)
    assert.is_false(d:is_empty())
    d:clear()
    assert.is_true(d:is_empty())
  end)

  it("should correctly report it's length", function()
    assert.equals(0, d:len())
    d:pushleft(3)
    d:pushleft(4)
    assert.equals(2, d:len())
    d:pushleft(5)
    assert.equals(3, d:len())
  end)

  it("should correct left iterator", function()
    d:pushright(3)
    d:pushright(4)
    d:pushright(5)

    local expected_values = { 3, 4, 5 }
    for index, value in d:ipairs_left() do
      assert.equals(expected_values[index + 1], value)
    end
  end)

  it("should correct right iterator", function()
    d:pushleft(3)
    d:pushleft(4)
    d:pushleft(5)

    local expected_values = { 3, 4, 5 }
    for index, value in d:ipairs_right() do
      assert.equals(expected_values[-index], value)
    end
  end)

  it("should clear itself correctly", function()
    assert.is_true(d:is_empty())
    d:pushleft(3)
    d:pushleft(4)
    d:pushleft(5)
    assert.is_false(d:is_empty())
    d:clear()
    assert.is_true(d:is_empty())
  end)
end)
