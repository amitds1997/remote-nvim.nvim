local NuiLine = require("nui.line")
local NuiTree = require("nui.tree")
local Split = require("nui.split")

---@class remote-nvim.ui.ProgressView
---@field private split NuiSplit
---@field private tree NuiTree
---@field private is_visible boolean
---@field private map_options table<string, any>
---@field private help_bufnr number Buffer ID of the keymap help buffer
---@field private _active_section NuiTree.Node?
---@field private _active_run_number number Active run number
---@field private _tree_start_linenr number What line number should the tree be rendered from
local ProgressView = require("remote-nvim.middleclass")("ProgressView")

function ProgressView:init()
  self.split = Split({
    relative = "win",
    position = "right",
    size = "30%",
    win_options = {
      number = false,
      relativenumber = false,
      cursorcolumn = false,
      foldcolumn = "0",
      spell = false,
      list = false,
      signcolumn = "no",
      colorcolumn = "",
      statuscolumn = "",
    },
  })
  self.help_bufnr = vim.api.nvim_create_buf(false, true)
  self.tree = NuiTree({
    winid = self.split.winid,
    bufnr = self.split.bufnr,
    prepare_node = function(node, _)
      local line = NuiLine()

      line:append(string.rep(" ", node:get_depth() - 1))

      if node:has_children() then
        line:append(node:is_expanded() and " " or " ", "SpecialChar")
      else
        line:append(" ")
      end
      line:append(node.text)

      return line
    end,
  })
  self.is_visible = false
  self._active_section = nil
  self._active_run_number = 0
  self._tree_start_linenr = 1
  self.map_options = { noremap = true, nowait = true }
  self:_set_keybindings()
end

function ProgressView:toggle()
  if self.is_visible then
    self.split:hide()
  else
    self.split:show()
  end
  self.is_visible = not self.is_visible
end

function ProgressView:show()
  self.split:show()
  self.is_visible = true
end

function ProgressView:hide()
  self.split:hide()
  self.is_visible = false
end

function ProgressView:start_run()
  self._active_run_number = self._active_run_number + 1

  local title = ("Run number %s"):format(self._active_run_number)
  if self._active_run_number == 1 then
    title = "Initial run"

    local line = NuiLine()
    line:append("Press")
    line:append(" ? ", "DiagnosticInfo")
    line:append("to view possible keybindings")

    vim.bo[self.split.bufnr].readonly = false
    vim.bo[self.split.bufnr].modifiable = true
    line:render(self.split.bufnr, -1, self._tree_start_linenr)
    NuiLine():render(self.split.bufnr, -1, self._tree_start_linenr + 1)
    vim.bo[self.split.bufnr].readonly = true
    vim.bo[self.split.bufnr].modifiable = false
    self._tree_start_linenr = self._tree_start_linenr + 2
  end

  self.run_section = NuiTree.Node({
    text = title,
  }, {})
  self.tree:add_node(self.run_section)

  -- Collapse all nodes, and then expand active run section
  self:_collapse_all_nodes()
  self.run_section:expand()

  self:show()
end

---@private
function ProgressView:_set_keybindings_help(keymaps)
  local keymap_keys = vim.tbl_keys(keymaps)
  local max_length = 0
  for _, v in ipairs(keymap_keys) do
    max_length = math.max(max_length, #v)
  end

  local line_nr = 1
  local line = NuiLine()
  line:append("Keymaps", "DiagnosticInfo")
  line:render(self.help_bufnr, -1, line_nr)
  NuiLine():render(self.help_bufnr, -1, line_nr + 1)
  line_nr = line_nr + 2

  for key, value in vim.spairs(keymaps) do
    line = NuiLine()

    line:append(" " .. key .. string.rep(" ", max_length - #key), "DiagnosticInfo")
    line:append(" - " .. value.desc)
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
  return keymap_keys
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
    L = {
      action = function()
        self:_expand_all_nodes()
      end,
      desc = "Expand all headings",
    },
    H = {
      action = function()
        self:_collapse_all_nodes()
      end,
      desc = "Collapse all headings",
    },
    l = {
      action = function()
        local node = self.tree:get_node()
        assert(node ~= nil, "Node should not be nil")

        if node:expand() then
          self.tree:render(self._tree_start_linenr)
        end
      end,
      desc = "Expand current heading",
    },
    h = {
      action = function()
        local node = self.tree:get_node()
        assert(node ~= nil, "Node should not be nil")

        if node:collapse() then
          self.tree:render(self._tree_start_linenr)
        end
      end,
      desc = "Collapse current heading",
    },
    q = {
      action = function()
        self:hide()
      end,
      desc = "Close log window",
    },
    ["<CR>"] = {
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
      desc = "Toggle expand/collapse state of current heading",
    },
    ["?"] = {
      action = function()
        local switch_to_buf_id = (vim.api.nvim_get_current_buf() == self.help_bufnr and self.split.bufnr)
          or self.help_bufnr
        vim.api.nvim_win_set_buf(self.split.winid, switch_to_buf_id)
        local win_options = {
          number = false,
          relativenumber = false,
          cursorcolumn = false,
          foldcolumn = "0",
          spell = false,
          list = false,
          signcolumn = "no",
          colorcolumn = "",
          statuscolumn = "",
        }
        if switch_to_buf_id == self.help_bufnr then
          for key, value in pairs(win_options) do
            vim.api.nvim_set_option_value(key, value, {
              win = self.split.winid,
            })
          end
        end
      end,
      desc = "Toggle help window",
    },
  }

  for key, val in pairs(keymaps) do
    self.split:map("n", key, val.action, self.map_options)
    local options = vim.deepcopy(self.map_options)
    options["callback"] = val.action
    vim.api.nvim_buf_set_keymap(self.help_bufnr, "n", key, "", options)
  end

  self:_set_keybindings_help(keymaps)
end

---@param title string Title for the section
---@param lines string[]? Lines to add to the section
function ProgressView:start_section(title, lines)
  -- If we were working with a previous active section, collapse it
  assert(self.run_section ~= nil, "Run section should not be nil")
  if self._active_section then
    self._active_section:collapse()
  end

  self._active_section = NuiTree.Node({
    text = ("%s"):format(title),
  }, {})
  self.tree:add_node(self._active_section, self.run_section:get_id())

  for _, line in ipairs(lines or {}) do
    self:add_line(line)
  end

  -- Expand the now active section
  self._active_section:expand()
  self.tree:render(self._tree_start_linenr)
end

--- Add line to the log view
---@param line string Line to insert
function ProgressView:add_line(line)
  assert(self._active_section ~= nil, "Active section should not be nil")
  self.tree:add_node(NuiTree.Node({ text = line }), self._active_section:get_id())
  self.tree:render(self._tree_start_linenr)
end

return ProgressView
