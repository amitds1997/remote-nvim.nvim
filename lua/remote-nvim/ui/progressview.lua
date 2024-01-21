local NuiLine = require("nui.line")
local NuiTree = require("nui.tree")
local Popup = require("nui.popup")
local Split = require("nui.split")
local utils = require("remote-nvim.utils")
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

---@alias progressview_node_type "run_node"|"section_node"|"command_node"|"stdout_node"|"warning_node"|"info_node"
---@alias progressview_status "running"|"success"|"failed"|"warning"|"no_op"

---@class ProgressViewLine
---@field text string? Text to insert
---@field set_parent_status boolean? Should set parent status
---@field status progressview_status? Status of the node
---@field type progressview_node_type Type of line

---@class remote-nvim.ui.ProgressView
---@field private pv_holder NuiSplit | NuiPopup
---@field private tree NuiTree
---@field private map_options table<string, any>
---@field private help_bufnr number Buffer ID of the keymap help buffer
---@field private pv_holder_opts table
---@field private _active_section NuiTree.Node?
---@field private _run_section NuiTree.Node?
---@field private _tree_start_linenr number What line number should the tree be rendered from
local ProgressView = require("remote-nvim.middleclass")("ProgressView")

function ProgressView:init()
  local pv_config = remote_nvim.config.progress_view
  self.pv_ns = vim.api.nvim_create_namespace("remote_nvim_progressview")
  self.win_options = {
    number = false,
    relativenumber = false,
    cursorline = false,
    cursorcolumn = false,
    foldcolumn = "0",
    spell = false,
    list = false,
    signcolumn = "auto",
    colorcolumn = "",
    statuscolumn = "",
    fillchars = "eob: ",
  }

  if pv_config.type == "split" then
    self.pv_holder_opts = {
      ns_id = self.pv_ns,
      relative = pv_config.relative or "win",
      position = pv_config.position or "right",
      size = pv_config.size or "30%",
      win_options = self.win_options,
    }
    self.pv_holder = Split(self.pv_holder_opts)
  else
    self.pv_holder_opts = {
      ns_id = self.pv_ns,
      relative = pv_config.relative or "win",
      position = pv_config.position or "50%",
      size = pv_config.size or "50%",
      win_options = self.win_options,
      border = pv_config.border or "rounded",
    }
    self.pv_holder = Popup(self.pv_holder_opts)
  end
  self.help_bufnr = vim.api.nvim_create_buf(false, true)
  self.tree = NuiTree({
    ns_id = self.pv_ns,
    winid = self.pv_holder.winid,
    bufnr = self.pv_holder.bufnr,
    prepare_node = function(node, _)
      local line = NuiLine()

      line:append(string.rep(" ", node:get_depth()))

      ---@type progressview_node_type
      local node_type = node.type
      ---@type progressview_status
      local node_status = node.status or "no_op"

      local highlight = nil

      if node_status == "success" then
        highlight = "@namespace"
      elseif node_status == "failed" then
        highlight = "@method"
      elseif node_type == "warning_node" then
        highlight = "@number"
      elseif node_type == "info_node" then
        highlight = "@boolean"
      elseif node_status == "running" then
        highlight = "CmpItemKindInterface"
      elseif node_type == "run_node" then
        highlight = "CursorLineNR"
      elseif node_type == "section_node" then
        highlight = "Conditional"
      elseif node_type == "stdout_node" then
        highlight = "Comment"
      elseif node_type == "command_node" then
        highlight = "TroubleFoldIcon"
      end

      ---@type progressview_node_type[]
      local section_nodes = { "section_node", "run_node" }
      ---@type progressview_node_type[]
      local status_nodes = { "warning_node", "info_node" }
      if utils.contains(section_nodes, node.type) then
        line:append(node:is_expanded() and " " or " ", highlight)
      elseif not utils.contains(status_nodes, node.type) then
        line:append(" ")
      end

      if node_type == "command_node" then
        line:append("Command: ", "CmpItemKindMethod")
      elseif node_type == "warning_node" then
        line:append("⚠︎ ", highlight)
      elseif node_type == "info_node" then
        line:append("ⓘ ", highlight)
      end
      line:append(node.text, highlight)

      if node_type == "run_node" and utils.contains({ "success", "failed" }, node_status) then
        line:append(" (no longer active)", "Comment")
      end

      if node_type == "command_node" then
        return {
          line,
          NuiLine(),
        }
      end
      return line
    end,
  })
  self._active_section = nil
  self.map_options = { noremap = true, nowait = true }
  self:_set_keybindings()
  self:_set_top_line(self.pv_holder.bufnr)
  self._tree_start_linenr = vim.api.nvim_buf_line_count(self.pv_holder.bufnr) + 1
end

---@private
function ProgressView:_set_top_line(bufnr)
  vim.bo[bufnr].readonly = false
  vim.bo[bufnr].modifiable = true

  local is_help_bufr = (bufnr == self.help_bufnr)
  local active_hl = "CurSearch"
  local inactive_hl = "CursorLine"
  local help_hl = is_help_bufr and active_hl or inactive_hl
  local progress_hl = is_help_bufr and inactive_hl or active_hl

  vim.api.nvim_buf_set_lines(bufnr, 0, 0, true, { "" })
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  local line = NuiLine()
  line:append(" ")
  line:append(" Progress View (P) ", progress_hl)
  line:append(" ")
  line:append(" Help (?) ", help_hl)
  line:render(bufnr, -1, line_count)

  vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, true, { "" })

  vim.bo[bufnr].readonly = true
  vim.bo[bufnr].modifiable = false
end

function ProgressView:show()
  self.pv_holder:update_layout(self.pv_holder_opts)
  self.pv_holder:show()
  vim.api.nvim_set_current_win(self.pv_holder.winid)
end

function ProgressView:hide()
  self.pv_holder:hide()
end

---@private
function ProgressView:_set_keybindings_help(keymaps)
  self:_set_top_line(self.help_bufnr)
  local line_nr = vim.api.nvim_buf_line_count(self.help_bufnr) + 1

  vim.bo[self.help_bufnr].readonly = false
  vim.bo[self.help_bufnr].modifiable = true

  -- Add Keyboard shortcuts heading
  local line = NuiLine()
  line:append(" Keyboard shortcuts")
  line:render(self.help_bufnr, -1, line_nr)
  vim.api.nvim_buf_set_lines(self.help_bufnr, line_nr, line_nr, true, { "" })
  line_nr = line_nr + 2

  local max_length = 0
  for _, v in ipairs(keymaps) do
    max_length = math.max(max_length, #v.key)
  end

  for _, v in ipairs(keymaps) do
    line = NuiLine()

    line:append("  " .. v.key .. string.rep(" ", max_length - #v.key), "DiagnosticInfo")
    line:append(" - " .. v.desc)
    line:render(self.help_bufnr, -1, line_nr)
    line_nr = line_nr + 1
  end

  local buf_options = {
    bufhidden = "hide",
    buflisted = false,
    buftype = "nofile",
    modifiable = false,
    readonly = true,
    swapfile = false,
    undolevels = 0,
  }
  for key, val in pairs(buf_options) do
    vim.api.nvim_set_option_value(key, val, {
      buf = self.help_bufnr,
    })
  end
end

---@private
function ProgressView:_collapse_all_nodes()
  local updated = false

  for _, node in pairs(self.tree.nodes.by_id) do
    updated = node:collapse() or updated
  end

  if updated then
    self.tree:render(self._tree_start_linenr)
  end
end

---@private
function ProgressView:_expand_all_nodes()
  local updated = false

  for _, node in pairs(self.tree.nodes.by_id) do
    updated = node:expand() or updated
  end

  if updated then
    self.tree:render(self._tree_start_linenr)
  end
end

---@private
function ProgressView:_set_keybindings()
  local keymaps = {
    {
      key = "l",
      action = function()
        local node = self.tree:get_node()
        assert(node ~= nil, "Node should not be nil")

        if node:expand() then
          self.tree:render(self._tree_start_linenr)
        end
      end,
      desc = "Expand current heading",
    },
    {
      key = "h",
      action = function()
        local node = self.tree:get_node()
        assert(node ~= nil, "Node should not be nil")

        if node:collapse() then
          self.tree:render(self._tree_start_linenr)
        end
      end,
      desc = "Collapse current heading",
    },
    {
      key = "<CR>",
      action = function()
        local node = self.tree:get_node()
        assert(node ~= nil, "Node should not be nil")

        if node:is_expanded() then
          node:collapse()
        else
          node:expand()
        end
        self.tree:render(self._tree_start_linenr)
      end,
      desc = "Toggle current heading",
    },
    {
      key = "L",
      action = function()
        self:_expand_all_nodes()
      end,
      desc = "Expand all headings",
    },
    {
      key = "H",
      action = function()
        self:_collapse_all_nodes()
      end,
      desc = "Collapse all headings",
    },
    {
      key = "P",
      action = function()
        vim.api.nvim_win_set_buf(self.pv_holder.winid, self.pv_holder.bufnr)
      end,
      desc = "Switch to Progress view",
    },
    {
      key = "?",
      action = function()
        local switch_to_bufnr = (vim.api.nvim_win_get_buf(self.pv_holder.winid) == self.help_bufnr)
            and self.pv_holder.bufnr
          or self.help_bufnr
        vim.api.nvim_win_set_buf(self.pv_holder.winid, switch_to_bufnr)
        if switch_to_bufnr == self.help_bufnr then
          for key, value in pairs(self.win_options) do
            vim.api.nvim_set_option_value(key, value, {
              win = self.pv_holder.winid,
            })
          end
        end
      end,
      desc = "Toggle help window",
    },
    {
      key = "q",
      action = function()
        self:hide()
      end,
      desc = "Close Progress view",
    },
  }

  for _, val in ipairs(keymaps) do
    self.pv_holder:map("n", val.key, val.action, self.map_options)
    local options = vim.deepcopy(self.map_options)
    options["callback"] = val.action
    vim.api.nvim_buf_set_keymap(self.help_bufnr, "n", val.key, "", options)
  end

  self:_set_keybindings_help(keymaps)
end

---@param node ProgressViewLine Line to insert into progress view
function ProgressView:add_node(node)
  ---@type progressview_status
  local status = "no_op"

  if node.type == "warning_node" then
    status = "warning"
  elseif node.type == "stdout_node" then
    status = "running"
  elseif utils.contains({ "run_node", "section_node" }, node.type) then
    status = node.status
  end

  if node.text ~= nil then
    if utils.contains({ "section_node", "warning_node", "info_node" }, node.type) then
      self:_add_section(node)
    elseif node.type == "run_node" then
      self:_add_run_section(node)
    else
      self:_add_line(node)
    end
  end

  self:update_status(status, node.set_parent_status)
end

function ProgressView:get_active_section()
  return self._active_section
end

---@param status progressview_status?
---@param should_update_parent_status boolean?
---@param node NuiTree.Node?
function ProgressView:update_status(status, should_update_parent_status, node)
  node = node or self._active_section or self._run_section
  assert(node ~= nil, "Node should not be nil")
  node.status = status

  -- Update parent node's status as well
  if should_update_parent_status then
    local parent_node_id = node:get_parent_id()
    while parent_node_id ~= nil do
      local parent_node = self.tree:get_node(parent_node_id)
      parent_node.status = status
      ---@diagnostic disable-next-line:need-check-nil
      parent_node_id = parent_node:get_parent_id()
    end
  end

  if not utils.contains({ "success", "warning" }, node.status) then
    node:expand()
  end

  -- If it is a successful node, we close it
  if status == "success" then
    node:collapse()
  end
  self.tree:render(self._tree_start_linenr)
end

---@param node ProgressViewLine Section to insert into progress view
function ProgressView:_add_section(node)
  assert(self._run_section ~= nil, "Run section should not be nil")
  -- If we were working with a previous active section, collapse it
  if self._active_section then
    self._active_section:collapse()
  end

  local section_node = NuiTree.Node({
    text = node.text,
    ---@type progressview_node_type
    type = node.type,
  })
  self.tree:add_node(section_node, self._run_section:get_id())

  if node.type == "section_node" then
    self._active_section = section_node
  end
end

---@param node ProgressViewLine Run node to insert into progress view
function ProgressView:_add_run_section(node)
  self._run_section = NuiTree.Node({
    text = node.text,
    type = node.type,
  }, {})
  self.tree:add_node(self._run_section)

  -- Collapse all nodes, and then expand current run section
  self:_collapse_all_nodes()
  self._run_section:expand()
end

--- Add line to the log view
---@param node ProgressViewLine Line to insert into progress view
function ProgressView:_add_line(node)
  assert(self._active_section ~= nil, "Active section should not be nil")
  self.tree:add_node(
    NuiTree.Node({
      text = node.text,
      type = node.type,
    }),
    self._active_section:get_id()
  )
end

return ProgressView
