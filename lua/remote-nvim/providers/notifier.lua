local notify = require("notify")

---@class remote-nvim.providers.Notifier
---@field title string Title of the notification box
---@field spinner_frames string[] Spinner frames to use as notification icon
---@field hide_from_history boolean Notifications generated should be hidden from history
---@field current_notification table Current notification object
---@field current_spinner_idx number Current icon index in spinner frame
---@field close_icons remote-nvim.providers.Notifier.NotificationCloseIcons Notification close icons
local Notifier = require("remote-nvim.middleclass")("Notifier")

---@class remote-nvim.providers.Notifier.NotificationCloseIcons
---@field success string Icon for success
---@field failure string Icon for failure

---@class remote-nvim.providers.Notifier.NotifierOpts
---@field title string Title of the notification box
---@field spinner_frames string[] Spinner icons to cycle through
---@field hide_from_history boolean Should hide notification from notification history?
---@field close_icons remote-nvim.providers.Notifier.NotificationCloseIcons Closing icons
local default_notification_opts = {
  title = "Remote Neovim",
  spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
  hide_from_history = true,
  close_icons = {
    success = "",
    failure = "",
  },
}

---@private
---Initialize a notification handler
---@param opts remote-nvim.providers.Notifier.NotifierOpts Notification options
function Notifier:init(opts)
  opts = vim.tbl_deep_extend("force", default_notification_opts, opts or {})

  self.title = opts.title
  self.spinner_frames = opts.spinner_frames
  self.hide_from_history = opts.hide_from_history
  self.close_icons = opts.close_icons

  self:_reset()
end

---@private
---Reset the notifitier state
function Notifier:_reset()
  self.current_spinner_idx = nil
  self.current_notification = nil
end

---@private
---Format the message correctly in the notification window
---@param msg string Message to be formatted
---@return string formatted_msg Formatted message
function Notifier:_format_msg(msg)
  return " " .. msg
end

---@private
---Update the notification
function Notifier:_update_notification()
  if self.current_spinner_idx then
    self.current_spinner_idx = (self.current_spinner_idx + 1) % #self.spinner_frames

    self.current_notification = notify(nil, nil, {
      hide_from_history = self.hide_from_history,
      icon = self.spinner_frames[self.current_spinner_idx],
      replace = self.current_notification,
    })

    vim.defer_fn(function()
      self:_update_notification()
    end, 100)
  end
end

---@private
---Start a persistent notification
---@param msg string Message to display in the notification
---@param level number? Level at which the notification should be shown
function Notifier:_start_persistent_notification(msg, level)
  self.current_spinner_idx = 1
  self.current_notification = notify(self:_format_msg(msg), level or vim.log.levels.INFO, {
    title = self.title,
    icon = self.spinner_frames[self.current_spinner_idx],
    timeout = false,
    hide_from_history = self.hide_from_history,
  })
  self:_update_notification()
end

---@private
---Stop the persistent notification
---@param msg string Message to show at the very end
---@param level number? Log level of the notification
function Notifier:_stop_persistent_notification(msg, level)
  local is_error = (level == vim.log.levels.ERROR)
  local opts = {
    title = self.title,
    icon = is_error and self.close_icons.failure or self.close_icons.success,
    replace = self.current_notification,
    timeout = 3000,
  }
  self.current_notification = notify(self:_format_msg(msg), level, opts)
  self:_reset()
end

---Show notification
---@param msg string Message for the notification
---@param level number? Log level of the notification
---@param stop_notification boolean? Stop the persistent notification
function Notifier:notify(msg, level, stop_notification)
  stop_notification = stop_notification or false

  if stop_notification then
    self:_stop_persistent_notification(msg, level)
  elseif self.current_notification ~= nil then
    self.current_notification = notify(self:_format_msg(msg), level or vim.log.levels.INFO, {
      replace = self.current_notification,
      hide_from_history = self.hide_from_history,
    })
  else
    self:_start_persistent_notification(msg, level)
  end
end

---Show notification once and be done
---@param msg string Message to display in the notification
---@param level number? Logging level
function Notifier:notify_once(msg, level)
  notify(self:_format_msg(msg), level or vim.log.levels.INFO, {
    title = self.title,
  })
end

return Notifier
