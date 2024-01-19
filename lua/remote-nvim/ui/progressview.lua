local NuiLine = require("nui.line")
local NuiTree = require("nui.tree")
local Split = require("nui.split")

---@class remote-nvim.ui.ProgressView
---@field private split NuiSplit
---@field private tree NuiTree
---@field private is_visible boolean
---@field private map_options table<string, any>
---@field private _active_section NuiTree.Node?
---@field private _active_run_number number Active run number
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
  self._active_section = nil
  self.is_visible = false
  self._active_run_number = 0
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
function ProgressView:_collapse_all_nodes()
  local updated = false

  for _, node in pairs(self.tree.nodes.by_id) do
    updated = node:collapse() or updated
  end

  if updated then
    self.tree:render()
  end
end

---@private
function ProgressView:_expand_all_nodes()
  local updated = false

  for _, node in pairs(self.tree.nodes.by_id) do
    updated = node:expand() or updated
  end

  if updated then
    self.tree:render()
  end
end

---@private
function ProgressView:_set_keybindings()
  self.split:map("n", "L", function()
    self:_expand_all_nodes()
  end, self.map_options)

  self.split:map("n", "l", function()
    local node = self.tree:get_node()
    assert(node ~= nil, "Node should not be nil")

    if node:expand() then
      self.tree:render()
    end
  end, self.map_options)

  self.split:map("n", "H", function()
    self:_collapse_all_nodes()
  end, self.map_options)

  self.split:map("n", "h", function()
    local node = self.tree:get_node()
    assert(node ~= nil, "Node should not be nil")

    if node:collapse() then
      self.tree:render()
    end
  end, self.map_options)

  self.split:map("n", "q", function()
    self:toggle()
  end)

  self.split:map("n", "<CR>", function()
    local node = self.tree:get_node()
    assert(node ~= nil, "Node should not be nil")

    if node:is_expanded() then
      node:collapse()
    else
      node:expand()
    end
    self.tree:render()
  end)
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
  self.tree:render()
end

--- Add line to the log view
---@param line string Line to insert
function ProgressView:add_line(line)
  assert(self._active_section ~= nil, "Active section should not be nil")
  self.tree:add_node(NuiTree.Node({ text = line }), self._active_section:get_id())
  self.tree:render()
end

return ProgressView
