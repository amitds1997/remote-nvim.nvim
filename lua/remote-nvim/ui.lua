local M = {}

function M.float_term(cmd, exit_cb, popup_options)
  popup_options = vim.tbl_deep_extend("force", {
    enter = true,
    focusable = true,
    relative = "editor",
    border = {
      style = "rounded",
    },
    position = "50%",
    size = {
      width = "100%",
      height = "100%",
    },
    zindex = 100,
  }, popup_options or {})

  local popup = require("nui.popup")(popup_options)
  popup:mount()

  -- If we leave the buffer, we close the pop-up
  popup:on("BufLeave", function()
    popup:unmount()
  end, { once = true })

  vim.fn.termopen(cmd, {
    on_exit = function(_, exit_code)
      -- We close the pop-up if we exit successfully
      -- to avoid "Process exited with status code 0" message
      if exit_code == 0 then
        popup:unmount()
      end
      if exit_cb then
        exit_cb(exit_code)
      end
    end,
  })
  vim.cmd.startinsert()
end

return M
