describe("Notifier service", function()
  local Notifier = require("remote-nvim.providers.notifier")
  local assert = require("luassert.assert")
  local spy = require("luassert.spy")
  local match = require("luassert.match")

  local notifier
  before_each(function()
    notifier = Notifier()
    require("luassert.mock")(require("notify"), true)
  end)

  it("should correctly format message", function()
    local message = "test message"
    assert.equals(notifier:_format_msg(message), (" %s"):format(message))
  end)

  describe("should handle notification flow correctly", function()
    local start_notification_spy, stop_notification_spy

    before_each(function()
      stop_notification_spy = spy.on(notifier, "_stop_persistent_notification")
      start_notification_spy = spy.on(notifier, "_start_persistent_notification")
    end)

    it("when close is called with no existing persistent notification", function()
      notifier:notify("test message", vim.log.levels.ERROR, true)

      assert.spy(start_notification_spy).was.not_called()
      assert.spy(stop_notification_spy).was.called_with(notifier, "test message", vim.log.levels.ERROR)
    end)

    it("when close is called with existing persistent notification", function()
      notifier:notify("start message")
      assert.spy(stop_notification_spy).was.not_called()
      assert.spy(start_notification_spy).was.called_with(match.is_ref(notifier), "start message", nil)
      start_notification_spy:clear()

      notifier:notify("stop notification", nil, true)
      assert.spy(stop_notification_spy).was.called_with(match.is_ref(notifier), "stop notification", nil)
      assert.spy(start_notification_spy).was.not_called()
    end)

    it("when notify is called with no existing persistent notification", function()
      notifier:notify("start message")
      assert.spy(start_notification_spy).was.called_with(match.is_ref(notifier), "start message", nil)
    end)

    it("when notify is called with an existing persistent notification", function()
      notifier:notify("start message")
      start_notification_spy:clear()
      stop_notification_spy:clear()
      notifier.current_notification = "current_notification"

      notifier:notify("update message")
      assert.spy(start_notification_spy).was.not_called()
      assert.spy(stop_notification_spy).was.not_called()
    end)
  end)
end)
