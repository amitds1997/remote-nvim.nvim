describe("Provider", function()
  local Provider = require("remote-nvim.providers.provider")

  describe("should handle array-type connections options", function()
    it("when it is not empty", function()
      local provider = Provider("localhost", { "-p", "3011", "-t", "-x" })
      assert.equals(provider.conn_opts, "-p 3011 -t -x")
    end)

    it("when it is an empty array", function()
      local provider = Provider("localhost", {})
      assert.equals(provider.conn_opts, "")
    end)
  end)

  it("should handle missing connection options correctly", function()
    local provider = Provider("localhost")
    assert.equals(provider.conn_opts, "")

    provider = Provider("localhost", nil)
    assert.equals(provider.conn_opts, "")
  end)

  it("should handle string connection options correctly", function()
    local provider = Provider("localhost", "-p 3011 -t -x")
    assert.equals(provider.conn_opts, "-p 3011 -t -x")
  end)
end)
