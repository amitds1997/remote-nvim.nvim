local assert = require("luassert.assert")
local utils = require("remote-nvim.utils")

describe("Common parent is correctly determined", function()
  it("when no paths are passed", function()
    local parent, sub_dirs = utils.find_common_parent({})

    assert.equals("", parent)
    assert.are.same({}, sub_dirs)
  end)

  it("when only single path is passed", function()
    local parent, sub_dirs = utils.find_common_parent({ "first/second/third" })
    assert.equals("first/second", parent)
    assert.are.same({ "third" }, sub_dirs)
  end)

  describe("when more than 1 paths are provided", function()
    it("when there are no common parents", function()
      local parent, sub_dirs = utils.find_common_parent({
        "first-path/second-path/third-path",
        "1st-path/2nd-path/3rd-path",
      })
      assert.equals("", parent)
      assert.are.same({
        "first-path/second-path/third-path",
        "1st-path/2nd-path/3rd-path",
      }, sub_dirs)
    end)

    it("when there are common parents", function()
      local parent, sub_dirs = utils.find_common_parent({
        "first-path/second-path/third-path",
        "first-path/second-path/3rd-path",
      })

      assert.equals("first-path/second-path", parent)
      assert.are.same({
        "third-path",
        "3rd-path",
      }, sub_dirs)
    end)
  end)
end)

describe("Plain string substitution works", function()
  it("when an empty string is passed", function()
    assert.equals("", utils.plain_substitute("", "a", "b"))
  end)

  it("on a non-empty string", function()
    assert.equals("bakagamai", utils.plain_substitute("akagamai", "aka", "baka"))
  end)

  it("when replacement substring has special characters", function()
    assert.equals("b*k/gamai", utils.plain_substitute("akagamai", "aka", "b*k/"))
  end)

  it("when there are multiple substrings to replace", function()
    assert.equals("baka/baka", utils.plain_substitute("aka/aka", "aka", "baka", 2))
  end)
end)
