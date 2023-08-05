local notify = require("notify")

local default_opts = {
  title = "Remote Neovim",
  spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
  hide_from_history = true,
}

---Handle a running notification
---@class Notifier
---@field title string Title of the notification
---@field spinner_frames string[] Spinner frames to use as notification icon
---@field hide_from_history boolean If the notifications generated should be hidden from history
---@field notification table Holds the state of the current shown notification
---@field spinner number Current icon of the notification
local Notifier = {}
Notifier.__index = Notifier

function Notifier:new(host_id, opts)
  assert(host_id ~= nil, "Host ID must be specified")
  opts = vim.tbl_deep_extend("force", default_opts, opts or {})

  local instance = setmetatable({}, Notifier)
  instance.title = opts.title .. ": " .. host_id
  instance.spinner_frames = opts.spinner_frames
  instance.hide_from_history = opts.hide_from_history
  instance.notification = nil
  return instance
end

---Start showing a notification
---@param msg string Message to display in the notification
---@param level? string Level at which the notification should be shown
---@return table Notifier table
function Notifier:start(msg, level)
  self.notification = notify(self:_format_msg(msg), level or "info", {
    title = self.title,
    icon = self.spinner_frames[1],
    timeout = false,
    hide_from_history = self.hide_from_history,
  })
  self.spinner = 1
  self:_update_spinner()
  return self
end

---@private
---Update the shown spinner
function Notifier:_update_spinner()
  if self.spinner then
    self.spinner = (self.spinner + 1) % #self.spinner_frames

    self.notification = notify(nil, nil, {
      hide_from_history = self.hide_from_history,
      icon = self.spinner_frames[self.spinner],
      replace = self.notification,
    })

    vim.defer_fn(function()
      self:_update_spinner()
    end, 100)
  end
end

---Update the shown notification
---@param msg string Message to be updated in the notification
---@param level? string Log level of the notification
function Notifier:notify(msg, level)
  if self.notification == nil then
    return self:start(msg, level)
  end

  self.notification = notify(self:_format_msg(msg), level or "info", {
    replace = self.notification,
    hide_from_history = self.hide_from_history,
  })

  return self
end

---How to format the message received
---@param msg string Message to be formatted
---@return string formatted_msg Formatted message
function Notifier:_format_msg(msg)
  return " " .. msg
end

---Stop showing the notification
---@param msg string Message to show at the very end
---@param level? string Log level of the notification
---@param opts? table Options to pass to the notification
function Notifier:stop(msg, level, opts)
  opts = opts or {}
  opts.replace = nil
  local notif_opts = {
    title = self.title,
    icon = level == "error" and "" or "",
    replace = self.notification,
    timeout = 3000,
  }
  opts = vim.tbl_extend("force", notif_opts, opts)
  self.notification = notify(self:_format_msg(msg), level, opts)
  self.spinner = nil
  self.notification = nil

  return self
end

return Notifier
