local Layout = require("nui.layout")
local NuiLine = require("nui.line")
local NuiTree = require("nui.tree")
local Popup = require("nui.popup")
local remote_nvim = require("remote-nvim")
local logger = require("remote-nvim.utils").logger
local utils = require("remote-nvim.utils")

local M = {}

local function RemoteInfoNodes()
  local neovim_version = vim.version()
  neovim_version = ("%d.%d.%d"):format(neovim_version.major, neovim_version.minor, neovim_version.patch)

  local nodes = {
    NuiTree.Node({ text = "Global info" }, {
      NuiTree.Node({ text = ("Log location: %s"):format(logger.outfile) }),
    }),
    NuiTree.Node({ text = "" }),
  }

  -- Remote OS, Local port, Remote port, Remote Neovim version, workspace ID
  for host_id, session in pairs(remote_nvim.sessions) do
    if session.remote_port_forwarding_job_id ~= nil then
      local general_info = NuiTree.Node({
        text = ("Connection string: nvim --server localhost:%s --remote-ui"):format(session.local_free_port),
      })

      local local_node = NuiTree.Node({ text = "Local" }, {
        NuiTree.Node({ text = ("Port: %s"):format(session.local_free_port) }),
        NuiTree.Node({ text = ("Neovim version: %s"):format(neovim_version) }),
        NuiTree.Node({ text = "" }),
      })
      local remote_node = NuiTree.Node({ text = "Remote" }, {
        NuiTree.Node({ text = ("Port: %s"):format(session.remote_free_port) }),
        NuiTree.Node({ text = ("Neovim version: %s"):format(session.remote_neovim_version) }),
        NuiTree.Node({ text = ("Workspace path: %s"):format(session.remote_workspace_id_path) }),
        NuiTree.Node({ text = ("Remote OS: %s"):format(session.remote_os) }),
      })
      table.insert(
        nodes,
        NuiTree.Node({ text = ("Host ID: %s"):format(host_id) }, {
          general_info,
          local_node,
          remote_node,
          NuiTree.Node({ text = "" }),
        })
      )
    end
  end

  if #nodes <= 2 then
    table.insert(nodes, NuiTree.Node({ text = "No active remote sessions." }))
  end

  return nodes
end

function M.RemoteInfo()
  local info_popup = Popup({
    border = {
      style = "rounded",
      text = {
        top = " Remote Neovim Session Info ",
      },
    },
    enter = true,
    focusable = true,
    relative = "editor",
    win_options = {
      winblend = 0,
      winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    },
  })

  local keymap_popup = Popup({
    border = {
      style = "single",
      text = {
        top = " Keyboard shortcuts ",
      },
    },
    win_options = {
      winblend = 0,
      winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    },
  })

  local info_layout = Layout(
    {
      position = "50%",
      size = {
        width = "60%",
        height = "60%",
      },
    },
    Layout.Box({
      Layout.Box(info_popup, { size = "80%" }),
      Layout.Box(keymap_popup, { size = "20%" }),
    }, { dir = "col" })
  )
  info_layout:mount()

  -- Fill the buffer with data
  local tree = NuiTree({
    bufnr = info_popup.bufnr,
    winid = info_popup.winid,
    nodes = RemoteInfoNodes(),
    prepare_node = function(node)
      local line = NuiLine()

      line:append(string.rep("  ", node:get_depth() - 1))

      if node:has_children() then
        line:append(node:is_expanded() and " " or " ", "SpecialChar")
      else
        line:append("  ")
      end

      line:append(node.text)

      return line
    end,
  })

  tree:render()

  -- Set up necessary keymaps
  local map_options = { noremap = true, nowait = true }

  local keymaps = {
    ["Close window"] = {
      key = "q",
      handler = function()
        info_layout:unmount()
      end,
    },
    ["Expand/collapse node"] = {
      key = "<CR>",
      handler = function()
        local node = tree:get_node()
        assert(node ~= nil, "Node should not be nil")
        if node:collapse() or node:expand() then
          tree:render()
        end
      end,
    },
    ["Expand node"] = {
      key = "l",
      handler = function()
        local node = tree:get_node()
        assert(node ~= nil, "Node should not be nil")

        if node:expand() then
          tree:render()
        end
      end,
    },
    ["Collapse node"] = {
      key = "h",
      handler = function()
        local node = tree:get_node()
        assert(node ~= nil, "Node should not be nil")

        if node:collapse() then
          tree:render()
        end
      end,
    },
    ["Expand all nodes"] = {
      key = "L",
      handler = function()
        local updated = false

        for _, node in pairs(tree.nodes.by_id) do
          updated = node:expand() or updated
        end

        if updated then
          tree:render()
        end
      end,
    },
    ["Collapse all nodes"] = {
      key = "H",
      handler = function()
        local updated = false

        for _, node in pairs(tree.nodes.by_id) do
          updated = node:collapse() or updated
        end

        if updated then
          tree:render()
        end
      end,
    },
  }

  -- Set up keymaps and generate keymap tokens to be printed into the buffer
  local keymap_tokens = {}
  for desc, val in pairs(keymaps) do
    map_options["desc"] = desc
    info_popup:map("n", val.key, val.handler, map_options)
    table.insert(keymap_tokens, "[" .. val.key .. "]")
    table.insert(keymap_tokens, " : " .. desc)
  end

  vim.api.nvim_buf_set_lines(keymap_popup.bufnr, 0, -1, true, utils.generate_equally_spaced_columns(keymap_tokens, 4))

  -- Also set the winblend for the layout window
  vim.api.nvim_set_option_value("winblend", 0, { win = info_layout.winid })
  vim.api.nvim_set_option_value("winhighlight", "Normal:Normal,FloatBorder:FloatBorder", { win = info_layout.winid })

  -- Enable syntax highlighting on buffer
  vim.api.nvim_buf_set_option(info_popup.bufnr, "syntax", "yaml")
end

return M
