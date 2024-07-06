vim.env.LAZY_STDPATH = ".repro"
load(vim.fn.system("curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"))()

require("lazy.minit").repro({
  spec = {
    { "amitds1997/remote-nvim.nvim", version = "*", config = true },
  },
})

-- do anything else you need to do to reproduce the issue
