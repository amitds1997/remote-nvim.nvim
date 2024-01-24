local NuiLine = require("nui.line")
local NuiTree = require("nui.tree")
local Popup = require("nui.popup")
local Split = require("nui.split")
local utils = require("remote-nvim.utils")
local hl_groups = require("remote-nvim.colors").hl_groups
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

---@alias progressview_node_type "run_node"|"section_node"|"command_node"|"stdout_node"
---@alias session_node_type "local_node"|"remote_node"|"config_node"|"root_node"|"info_node"
---@alias progressview_status "running"|"success"|"failed"|"warning"|"no_op"

---@class ProgressViewLine
---@field text string? Text to insert
---@field set_parent_status boolean? Should set parent status
---@field status progressview_status? Status of the node
---@field type progressview_node_type Type of line

---@class SessionInfoNode
---@field key string? Key for the info
---@field value string Text to insert
---@field holds session_node_type? Type of nodes it contains
---@field type session_node_type Type of the node
---@field last_child_id NuiTree.Node? Last inserted child's ID

---@class remote-nvim.ui.ProgressView
---@field private pv_holder NuiSplit | NuiPopup
---@field private pv_tree NuiTree
---@field private map_options table<string, any>
---@field private help_bufnr integer Buffer ID of the keymap help buffer
---@field private si_bufnr integer Buffer ID of the session info buffer
---@field private pv_holder_opts table
---@field private _active_section NuiTree.Node?
---@field private _run_section NuiTree.Node?
---@field private _pv_tree_start_linenr number What line number should the tree be rendered from
---@field private _session_tree_start_linenr number What line number should the session tree be rendered from
local ProgressView = require("remote-nvim.middleclass")("ProgressView")

function ProgressView:init()
  local pv_config = remote_nvim.config.progress_view
  self.pv_ns = vim.api.nvim_create_namespace("remote_nvim_progressview")
  self.buf_options = {
    bufhidden = "hide",
    buflisted = false,
    buftype = "nofile",
    modifiable = false,
    readonly = true,
    swapfile = false,
    undolevels = 0,
  }
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
  self.si_bufnr = vim.api.nvim_create_buf(false, true)
  self.pv_tree = nil
  self.session_tree = nil
  self._active_section = nil
  self.map_options = { noremap = true, nowait = true }

  self:_setup_progress_view()
  self:_setup_session_info()
  self:_setup_help_window()
end

function ProgressView:_set_buffer(bufnr)
  vim.api.nvim_win_set_buf(self.pv_holder.winid, bufnr)
  if bufnr ~= self.pv_holder.bufnr then
    for key, value in pairs(self.win_options) do
      vim.api.nvim_set_option_value(key, value, {
        win = self.pv_holder.winid,
      })
    end
  end
end

---@param pane "progress_view"|"session_info"|"help"
---@param collapse_nodes boolean?
function ProgressView:switch_to_pane(pane, collapse_nodes)
  collapse_nodes = collapse_nodes or false
  if pane == "progress_view" then
    self:_set_buffer(self.pv_holder.bufnr)
    if collapse_nodes then
      self:_collapse_all_nodes(self.pv_tree, self._pv_tree_start_linenr)
    end
  elseif pane == "session_info" then
    self:_set_buffer(self.si_bufnr)
    if collapse_nodes then
      self:_collapse_all_nodes(self.session_tree, self._session_tree_start_linenr)
    end
  else
    self:_set_buffer(self.help_bufnr)
  end
end

---@private
---@param bufnr number Buffer ID
---@param clear_buffer boolean? Should clear buffer
function ProgressView:_set_top_line(bufnr, clear_buffer)
  vim.bo[bufnr].readonly = false
  vim.bo[bufnr].modifiable = true

  local active_hl = hl_groups.ActiveHeading.name
  local inactive_hl = hl_groups.InactiveHeading.name
  local help_hl = (bufnr == self.help_bufnr) and active_hl or inactive_hl
  local progress_hl = (bufnr == self.pv_holder.bufnr) and active_hl or inactive_hl
  local si_hl = (bufnr == self.si_bufnr) and active_hl or inactive_hl

  if clear_buffer then
    vim.api.nvim_buf_set_lines(bufnr, 0, vim.api.nvim_buf_line_count(bufnr) - 1, true, {})
  end
  vim.api.nvim_buf_set_lines(bufnr, 0, 0, true, { "" })
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  local line = NuiLine()
  line:append(" ")
  line:append(" Progress View (P) ", progress_hl)
  line:append(" ")
  line:append(" Session Info (S) ", si_hl)
  line:append(" ")
  line:append(" Help (?) ", help_hl)
  line:render(bufnr, -1, line_count)

  vim.api.nvim_buf_set_lines(bufnr, line_count, line_count, true, { "" })

  vim.bo[bufnr].readonly = true
  vim.bo[bufnr].modifiable = false
end

function ProgressView:show()
  -- Update layout because the pv_holder internally holds the window relative to which
  -- it should create the split/popup. If it no longer exists, it will throw an error.
  -- So, we update the layout to get the latest reference.
  self.pv_holder:update_layout(self.pv_holder_opts)
  self.pv_holder:show()
  vim.api.nvim_set_current_win(self.pv_holder.winid)
end

function ProgressView:hide()
  self.pv_holder:hide()
end

---@private
function ProgressView:_collapse_all_nodes(tree, start_linenr)
  local updated = false

  for _, node in pairs(tree.nodes.by_id) do
    updated = node:collapse() or updated
  end

  if updated then
    tree:render(start_linenr)
  end
end

---@private
function ProgressView:_expand_all_nodes(tree, start_linenr)
  local updated = false

  for _, node in pairs(tree.nodes.by_id) do
    updated = node:expand() or updated
  end

  if updated then
    tree:render(start_linenr)
  end
end

---@param session_info_node SessionInfoNode Node input
function ProgressView:add_session_info(session_info_node)
  ---@return NuiTree.Node?
  local function find_parent_node(node_type)
    local parent_node = nil
    for _, tree_node in ipairs(self.session_tree:get_nodes()) do
      if tree_node.holds == node_type then
        parent_node = tree_node
        break
      end
    end
    return parent_node
  end

  local node = NuiTree.Node({
    key = session_info_node.key,
    value = session_info_node.value,
    holds = session_info_node.holds,
    type = session_info_node.type,
  })
  local parent_node = find_parent_node(node.type)

  if parent_node then
    self.session_tree:add_node(node, parent_node:get_id())
    parent_node.last_child_id = node:get_id()
    parent_node:expand()
  else
    self.session_tree:add_node(node)
  end

  self.session_tree:render(self._session_tree_start_linenr)
end

function ProgressView:start_run(title)
  self:add_progress_node({
    text = title,
    type = "run_node",
  })

  self:_setup_session_info()
end

function ProgressView:_setup_progress_view()
  self.pv_tree = NuiTree({
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
        highlight = hl_groups.Success
      elseif node_status == "failed" then
        highlight = hl_groups.Failure
      elseif node_status == "running" then
        highlight = hl_groups.Running
      elseif utils.contains({ "run_node", "section_node" }, node_type) then
        highlight = hl_groups.CommandHeading
      elseif node_type == "stdout_node" then
        highlight = hl_groups.CommandOutput
      elseif node_type == "command_node" then
        highlight = hl_groups.InfoValue
      end
      highlight = highlight and highlight.name

      ---@type progressview_node_type[]
      local section_nodes = { "section_node", "run_node" }
      if utils.contains(section_nodes, node.type) then
        line:append(node:is_expanded() and " " or " ", highlight)
      else
        line:append(" ")
      end

      if node_type == "command_node" then
        line:append("Command: ", hl_groups.InfoKey.name)
      end
      line:append(node.text, highlight)

      if node_type == "run_node" and utils.contains({ "success", "failed" }, node_status) then
        line:append(" (no longer active)", hl_groups.SubInfo.name)
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
  self:_set_top_line(self.pv_holder.bufnr)
  self._pv_tree_start_linenr = vim.api.nvim_buf_line_count(self.pv_holder.bufnr) + 1

  -- Set up key bindings
  local keymaps = self:_get_section_keymaps()
  local tree_keymaps = self:_get_tree_keymaps(self.pv_tree, self._pv_tree_start_linenr)
  keymaps = vim.list_extend(keymaps, tree_keymaps)
  self:_set_buffer_keymaps(self.pv_holder.bufnr, keymaps)
end

function ProgressView:_initialize_session_info_tree()
  -- Initialize session info tree
  self.session_tree = NuiTree({
    ns_id = self.pv_ns,
    winid = self.pv_holder.winid,
    bufnr = self.si_bufnr,
    prepare_node = function(node, parent_node)
      local line = NuiLine()

      line:append(string.rep(" ", node:get_depth()))

      ---@type session_node_type
      local node_type = node.type
      ---@type progressview_status

      if node_type == "root_node" then
        line:append(node:is_expanded() and " " or " ", hl_groups.CommandHeading.name)
      else
        line:append(" ")
      end

      if node.key ~= nil then
        line:append(node.key .. ": ", hl_groups.InfoKey.name)
      end
      line:append(node.value or "nil", hl_groups.InfoValue.name)

      if
        (parent_node and parent_node.last_child_id == node:get_id())
        or (node.holds == "remote_node" and not node:is_expanded())
      then
        return {
          line,
          NuiLine(),
        }
      end

      return line
    end,
  })

  self:add_session_info({
    value = "Config",
    holds = "config_node",
    type = "root_node",
  })
  self:add_session_info({
    value = "Local config",
    holds = "local_node",
    type = "root_node",
  })
  self:add_session_info({
    value = "Remote config",
    holds = "remote_node",
    type = "root_node",
  })
end

function ProgressView:_setup_session_info()
  self:_set_top_line(self.si_bufnr, true)
  self._session_tree_start_linenr = vim.api.nvim_buf_line_count(self.si_bufnr) + 1
  self:_initialize_session_info_tree()

  -- Set up key bindings
  local keymaps = self:_get_section_keymaps()
  local tree_keymaps = self:_get_tree_keymaps(self.session_tree, self._session_tree_start_linenr)
  keymaps = vim.list_extend(keymaps, tree_keymaps)
  self:_set_buffer_keymaps(self.si_bufnr, keymaps)

  for key, val in pairs(self.buf_options) do
    vim.api.nvim_set_option_value(key, val, {
      buf = self.si_bufnr,
    })
  end

  self.session_tree:render(self._session_tree_start_linenr)
end

---@private
function ProgressView:_set_buffer_keymaps(bufnr, keymaps)
  for _, val in ipairs(keymaps) do
    local options = vim.deepcopy(self.map_options)
    options["callback"] = val.action
    vim.api.nvim_buf_set_keymap(bufnr, "n", val.key, "", options)
  end
end

---@private
function ProgressView:_setup_help_window()
  self:_set_top_line(self.help_bufnr)
  local line_nr = vim.api.nvim_buf_line_count(self.help_bufnr) + 1

  local keymaps = self:_get_section_keymaps()
  self:_set_buffer_keymaps(self.help_bufnr, keymaps)

  -- Get tree keymaps (we use this to set help and do not set up any extra keybindings)
  local tree_keymaps = self:_get_tree_keymaps(self.pv_tree, self._pv_tree_start_linenr)
  vim.list_extend(keymaps, tree_keymaps)

  local max_length = 0
  for _, v in ipairs(keymaps) do
    max_length = math.max(max_length, #v.key)
  end

  vim.bo[self.help_bufnr].readonly = false
  vim.bo[self.help_bufnr].modifiable = true

  -- Add Keyboard shortcuts heading
  local line = NuiLine()
  line:append(" Keyboard shortcuts")
  line:render(self.help_bufnr, -1, line_nr)
  vim.api.nvim_buf_set_lines(self.help_bufnr, line_nr, line_nr, true, { "" })
  line_nr = line_nr + 2

  for _, v in ipairs(keymaps) do
    line = NuiLine()

    line:append("  " .. v.key .. string.rep(" ", max_length - #v.key), hl_groups.InfoKey.name)
    line:append(" " .. v.desc, hl_groups.InfoValue.name)
    line:render(self.help_bufnr, -1, line_nr)
    line_nr = line_nr + 1
  end

  for key, val in pairs(self.buf_options) do
    vim.api.nvim_set_option_value(key, val, {
      buf = self.help_bufnr,
    })
  end
end

---@param tree NuiTree Tree on which keymaps will be set
---@param start_linenr number What line number on the buffer should the tree be rendered from
function ProgressView:_get_tree_keymaps(tree, start_linenr)
  if tree == nil or start_linenr == nil then
    return {}
  end
  return {
    {
      key = "l",
      action = function()
        local node = tree:get_node()

        if node and node:expand() then
          tree:render(start_linenr)
        else
          vim.api.nvim_feedkeys("l", "n", true)
        end
      end,
      desc = "Expand current heading",
    },
    {
      key = "h",
      action = function()
        local node = tree:get_node()

        if node and node:collapse() then
          tree:render(start_linenr)
        else
          vim.api.nvim_feedkeys("h", "n", true)
        end
      end,
      desc = "Collapse current heading",
    },
    {
      key = "<CR>",
      action = function()
        local node = tree:get_node()

        if node then
          if node:is_expanded() then
            node:collapse()
          else
            node:expand()
          end
          tree:render(start_linenr)
        else
          vim.api.nvim_feedkeys("<CR>", "n", true)
        end
      end,
      desc = "Toggle current heading",
    },
    {
      key = "L",
      action = function()
        self:_expand_all_nodes(tree, start_linenr)
      end,
      desc = "Expand all headings",
    },
    {
      key = "H",
      action = function()
        self:_collapse_all_nodes(tree, start_linenr)
      end,
      desc = "Collapse all headings",
    },
  }
end

function ProgressView:_get_section_keymaps()
  return {
    {
      key = "P",
      action = function()
        self:_set_buffer(self.pv_holder.bufnr)
      end,
      desc = "Switch to Progress view",
    },
    {
      key = "S",
      action = function()
        self:_set_buffer(self.si_bufnr)
      end,
      desc = "Switch to Session Info view",
    },
    {
      key = "?",
      action = function()
        local switch_to_bufnr = (vim.api.nvim_win_get_buf(self.pv_holder.winid) == self.help_bufnr)
            and self.pv_holder.bufnr
          or self.help_bufnr
        self:_set_buffer(switch_to_bufnr)
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
end

---@param node ProgressViewLine Line to insert into progress view
function ProgressView:add_progress_node(node)
  ---@type progressview_status
  local status = "no_op"

  if node.type == "stdout_node" then
    status = "running"
  elseif utils.contains({ "run_node", "section_node" }, node.type) then
    status = node.status
  end

  if node.text ~= nil then
    if node.type == "section_node" then
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
      local parent_node = self.pv_tree:get_node(parent_node_id)
      parent_node.status = status
      ---@diagnostic disable-next-line:need-check-nil
      parent_node_id = parent_node:get_parent_id()
    end

    if self.session_tree then
      -- Delete all info_node from session info tree (since they are from a previous run)
      local updated = false
      for _, si_node in ipairs(self.session_tree:get_nodes()) do
        if si_node.type == "info_node" then
          updated = true
          self.session_tree:remove_node(si_node:get_id())
        end
      end

      if updated then
        self.session_tree:render(self._session_tree_start_linenr)
      end
    end
  end

  if not utils.contains({ "success", "warning" }, node.status) then
    node:expand()
  end

  -- If it is a successful node, we close it
  if status == "success" then
    node:collapse()
  end
  self.pv_tree:render(self._pv_tree_start_linenr)
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
  self.pv_tree:add_node(section_node, self._run_section:get_id())

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
  self.pv_tree:add_node(self._run_section)

  -- Collapse all nodes, and then expand current run section
  self:_collapse_all_nodes(self.pv_tree, self._pv_tree_start_linenr)
  self._run_section:expand()
end

--- Add line to the log view
---@param node ProgressViewLine Line to insert into progress view
function ProgressView:_add_line(node)
  assert(self._active_section ~= nil, "Active section should not be nil")
  self.pv_tree:add_node(
    NuiTree.Node({
      text = node.text,
      type = node.type,
    }),
    self._active_section:get_id()
  )
end

return ProgressView
