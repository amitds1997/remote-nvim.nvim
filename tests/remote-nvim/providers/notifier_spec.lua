describe("Notifier service", function()
  local Notifier = require("remote-nvim.providers.notifier")

  local notifier
  before_each(function()
    notifier = Notifier()
  end)

  it("should correctly format message", function()
    local message = "test message"
    assert.equals(notifier:_format_msg(message), (" %s"):format(message))
  end)
end)
