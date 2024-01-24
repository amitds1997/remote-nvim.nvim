local M = {}

M.hl_groups = {
  Running = {
    link = "CmpItemKindInterface",
  },
  Success = {
    link = "@markup.heading.4.markdown",
  },
  Failure = {
    link = "@method",
  },
  CommandHeading = {
    link = "Conditional",
  },
  CommandOutput = {
    link = "Comment",
  },
  InfoKey = {
    link = "TroubleFoldIcon",
  },
  InfoValue = {
    link = "CmpItemKindMethod",
  },
  SubInfo = {
    link = "Comment",
  },
  ActiveHeading = {
    link = "CurSearch",
  },
  InactiveHeading = {
    link = "CursorLine",
  },
}

for hl_group, _ in pairs(M.hl_groups) do
  M.hl_groups[hl_group].name = "RemoteNvim" .. hl_group
end

function M.set_hl()
  for _, hl_values in pairs(M.hl_groups) do
    --- If already set, do not override it
    local hl_opts = vim.deepcopy(hl_values)
    local hl_name = hl_values.name

    hl_opts.default = true
    hl_opts["name"] = nil
    vim.api.nvim_set_hl(0, hl_name, hl_opts)
  end
end

function M.setup()
  M.set_hl()
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
      M.set_hl()
    end,
  })
end

return M
