local M = {}

function M.root(root)
  local f = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(f, ":p:h:h") .. "/" .. (root or "")
end

---@param plugin string
function M.load(plugin)
  local name = plugin:match(".*/(.*)")
  local package_root = M.root(".tests/site/pack/deps/start/")
  local uv = vim.fn.has("0.10") and vim.uv or vim.loop
  if not uv.fs_stat(package_root .. name) then
    print("Installing " .. plugin)
    vim.fn.mkdir(package_root, "p")
    vim.fn.system({
      "git",
      "clone",
      "--depth=1",
      "https://github.com/" .. plugin .. ".git",
      package_root .. "/" .. name,
    })
  end
end

function M.setup()
  vim.cmd([[set runtimepath=$VIMRUNTIME]])
  vim.opt.runtimepath:append(M.root())
  vim.opt.packpath = { M.root(".tests/site") }
  vim.opt.termguicolors = true

  M.load("MunifTanjim/nui.nvim")
  M.load("nvim-lua/plenary.nvim")
  M.load("rcarriga/nvim-notify")
  M.load("nvim-telescope/telescope.nvim")

  require("remote-nvim").setup()
  require("notify").setup({
    background_colour = "#000000",
  })
end

M.setup()
