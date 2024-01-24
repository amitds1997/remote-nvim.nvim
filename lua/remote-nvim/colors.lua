local M = {}

---@class remote-nvim.ui.colors.HighlightGroup: vim.api.keyset.highlight
---@field name? string Name of the highlight group

---@type table<string, remote-nvim.ui.colors.HighlightGroup>
M.hl_groups = {
  RemoteNvimInfo = { link = "RemoteNvimSuccess" },
  RemoteNvimRunning = { link = "DiagnosticOk" },
  RemoteNvimSuccess = { link = "DiagnosticInfo" },
  RemoteNvimFailure = { link = "ErrorMsg" },
  RemoteNvimHeading = { link = "Title" },
  RemoteNvimActiveHeading = { link = "QuickFixLine" },
  RemoteNvimInactiveHeading = { link = "TabLine" },
  RemoteNvimInfoKey = { link = "@label" },
  RemoteNvimInfoValue = { link = "LspInlayHint" },
  RemoteNvimOutput = { link = "Comment" },
  RemoteNvimSubInfo = { link = "RemoteNvimOutput" },
}

for hl_name, hl_group in pairs(M.hl_groups) do
  hl_group.name = hl_name
end

function M.set_hl()
  for hl_name, hl_values in pairs(M.hl_groups) do
    local hl_opts = vim.deepcopy(hl_values)

    hl_opts.default = true -- If already set, do not override it
    hl_opts.name = nil
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
