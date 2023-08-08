local M = {}

---@class FloatWindowWindowOpts
---@field winblend number A value b/w 0 and 100 indicating the pseudo-transparency, 0 being opaque

---@class FloatWindowBorderOpts
---@field topleft string
---@field topright string
---@field top string
---@field left string
---@field right string
---@field botleft string
---@field botright string
---@field bot string

---@class FloatWindowOpts
---@field col_percent? number A value b/w 0 and 1 indicating how much pct of editor should be used
---@field row_percent? number A value b/w 0 and 1 indicating how much pct of editor should be used
---@field win_opts? FloatWindowWindowOpts Options available for floating window
---@field border_opts? FloatWindowBorderOpts Options available for floating window border
local float_default_opts = {
  col_percent = 0.9,
  row_percent = 0.9,
  win_opts = {
    winblend = 5,
  },
  border_opts = {
    topleft = "╭",
    topright = "╮",
    top = "─",
    left = "│",
    right = "│",
    botleft = "╰",
    botright = "╯",
    bot = "─",
  },
}

---Run command in a floating window
---@param cmd string Command to be run in the floating terminal
---@param float_opts? FloatWindowOpts Options related to the floating window
---@param cmd_opts? table Options related to the term that would be launched in the window
M.float_term = function(cmd, float_opts, cmd_opts)
  cmd_opts = cmd_opts or {}
  local _ = M.float(float_opts)
  vim.fn.termopen(cmd, vim.tbl_isempty(cmd_opts) and vim.empty_dict() or cmd_opts)
  if cmd_opts.interactive ~= false then
    vim.cmd.startinsert()
  end
end

---Launches a minimal float window given the window opts
---@param float_opts? FloatWindowOpts Configuration for the floating window
M.float = function(float_opts)
  float_opts = vim.tbl_deep_extend("force", float_default_opts, float_opts or {})
  return require("plenary.window.float").percentage_range_window(
    float_opts.col_percent,
    float_opts.row_percent,
    float_opts.win_opts,
    float_opts.border_opts
  )
end

return M
