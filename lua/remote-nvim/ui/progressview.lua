local NuiLine = require("nui.line")
local NuiTree = require("nui.tree")
local Popup = require("nui.popup")
local Split = require("nui.split")
local hl_groups = require("remote-nvim.colors").hl_groups
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

---@alias progress_view_node_type "run_node"|"section_node"|"command_node"|"stdout_node"
---@alias session_node_type "local_node"|"remote_node"|"config_node"|"root_node"|"info_node"
---@alias progress_view_status "running"|"success"|"failed"|"no_op"

---@class remote-nvim.ui.ProgressView.Keymaps: vim.api.keyset.keymap
---@field key string Key which invokes the keymap action
---@field action function Action to apply when the keymap gets invoked

---@class remote-nvim.ui.ProgressView.ProgressInfoNode
---@field text string? Text to insert
---@field set_parent_status boolean? Should set parent status
---@field status progress_view_status? Status of the node
---@field type progress_view_node_type Type of line

---@class remote-nvim.ui.ProgressView.SessionInfoNode
---@field key string? Key for the info
---@field value string? Text to insert
---@field holds session_node_type? Type of nodes it contains
---@field type session_node_type Type of the node
---@field last_child_id NuiTree.Node? Last inserted child's ID

---@class remote-nvim.ui.ProgressView
---@field private progress_view NuiSplit|NuiPopup Progress View UI holder
---@field private progress_view_pane_tree NuiTree Tree used to render "Progress View" pane
---@field private session_info_pane_tree NuiTree Tree used to render "Session Info" pane
---@field private layout_type "split"|"popup" Type of layout we are using for progress view
---@field private progress_view_keymap_options vim.api.keyset.keymap Default keymap options
---@field private help_pane_bufnr integer Buffer ID of the keymap help buffer
---@field private session_info_pane_bufnr integer Buffer ID of the session info buffer
---@field private progress_view_options nui_popup_options|nui_split_options
---@field private active_progress_view_section_node NuiTree.Node?
---@field private active_progress_view_run_node NuiTree.Node?
---@field private progress_view_tree_render_linenr number What line number should the tree be rendered from
---@field private session_info_tree_render_linenr number What line number should the session tree be rendered from
---@field private progress_view_hl_ns integer Namespace for all progress view custom highlights
---@field private progress_view_buf_options table<string, any> Buffer options for Progress View
---@field private progress_view_win_options table<string, any> Window options for Progress View
local ProgressView = require("remote-nvim.middleclass")("ProgressView")

function ProgressView:init()
  local progress_view_config = remote_nvim.config.progress_view
  self.layout_type = progress_view_config.type
  self.progress_view_hl_ns = vim.api.nvim_create_namespace("remote_nvim_progressview_ns")
  self.progress_view_buf_options = {
    bufhidden = "hide",
    buflisted = false,
    buftype = "nofile",
    modifiable = false,
    readonly = true,
    swapfile = false,
    undolevels = 0,
  }
  self.progress_view_win_options = {
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

  if self.layout_type == "split" then
    self.progress_view_options = {
      ns_id = self.progress_view_hl_ns,
      relative = progress_view_config.relative or "editor",
      position = progress_view_config.position or "right",
      size = progress_view_config.size or "30%",
      win_options = self.progress_view_win_options,
    }
    ---@diagnostic disable-next-line:param-type-mismatch
    self.progress_view = Split(self.progress_view_options)
  else
    self.progress_view_options = {
      ns_id = self.progress_view_hl_ns,
      relative = progress_view_config.relative or "editor",
      position = progress_view_config.position or "50%",
      size = progress_view_config.size or "50%",
      win_options = self.progress_view_win_options,
      border = progress_view_config.border or "rounded",
      anchor = progress_view_config.anchor,
    }
    ---@diagnostic disable-next-line:param-type-mismatch
    self.progress_view = Popup(self.progress_view_options)
  end
  self.help_pane_bufnr = vim.api.nvim_create_buf(false, true)
  self.session_info_pane_bufnr = vim.api.nvim_create_buf(false, true)
  self.progress_view_pane_tree = nil
  self.session_info_pane_tree = nil
  self.active_progress_view_section_node = nil
  self.progress_view_keymap_options = { noremap = true, nowait = true }

  self:_setup_progress_view_pane()
  self:_setup_session_info_pane()
  self:_setup_help_pane()
end

---@private
---@param bufnr integer Buffer ID
function ProgressView:_set_buffer(bufnr)
  vim.api.nvim_win_set_buf(self.progress_view.winid, bufnr)
  if bufnr ~= self.progress_view.bufnr then
    for key, value in pairs(self.progress_view_win_options) do
      vim.api.nvim_set_option_value(key, value, {
        win = self.progress_view.winid,
      })
    end
  end
end

---Switch to one of the pane in Progress View window
---@param pane "progress_view"|"session_info"|"help"
---@param collapse_nodes boolean?
function ProgressView:switch_to_pane(pane, collapse_nodes)
  collapse_nodes = collapse_nodes or false
  if pane == "progress_view" then
    self:_set_buffer(self.progress_view.bufnr)
    if collapse_nodes then
      self:_collapse_all_nodes(self.progress_view_pane_tree, self.progress_view_tree_render_linenr)
    end
  elseif pane == "session_info" then
    self:_set_buffer(self.session_info_pane_bufnr)
    if collapse_nodes then
      self:_collapse_all_nodes(self.session_info_pane_tree, self.session_info_tree_render_linenr)
    end
  else
    self:_set_buffer(self.help_pane_bufnr)
  end
end

---@private
---Set top line for each of the buffer
---@param bufnr number Buffer ID
---@param clear_buffer boolean? Should clear buffer
function ProgressView:_set_top_line(bufnr, clear_buffer)
  vim.bo[bufnr].readonly = false
  vim.bo[bufnr].modifiable = true

  local active_hl = hl_groups.RemoteNvimActiveHeading.name
  local inactive_hl = hl_groups.RemoteNvimInactiveHeading.name
  local help_hl = (bufnr == self.help_pane_bufnr) and active_hl or inactive_hl
  local progress_hl = (bufnr == self.progress_view.bufnr) and active_hl or inactive_hl
  local si_hl = (bufnr == self.session_info_pane_bufnr) and active_hl or inactive_hl

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

---Show the progress viewer
function ProgressView:show()
  -- Update layout because progressview internally holds the window ID relative to which
  -- it should create the split/popup in case of rel="win". If it no longer exists, it
  -- will throw an error. So, we update the layout to get the latest window ID.
  if self.layout_type == "split" then
    self.progress_view:update_layout(self.progress_view_options)
  end
  self.progress_view:show()
  vim.api.nvim_set_current_win(self.progress_view.winid)
end

---Hide the progress viewer
function ProgressView:hide()
  self.progress_view:hide()
end

---@private
---Collapse all nodes for a tree
---@param tree NuiTree The tree whose all nodes should be collapsed
---@param start_linenr integer On which line should tree start rendering
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
---Expand all nodes for a tree
---@param tree NuiTree The tree whose all nodes should be expanded
---@param start_linenr integer On which line should tree start rendering
function ProgressView:_expand_all_nodes(tree, start_linenr)
  local updated = false

  for _, node in pairs(tree.nodes.by_id) do
    updated = node:expand() or updated
  end

  if updated then
    tree:render(start_linenr)
  end
end

---Add a session node
---@param session_info_node remote-nvim.ui.ProgressView.SessionInfoNode Node input
function ProgressView:add_session_node(session_info_node)
  ---Find the parent node
  ---@param node_type session_node_type The type of the session node
  ---@return NuiTree.Node? node Parent node. If parent node does not exist, return nil
  local function find_parent_node(node_type)
    local parent_node = nil
    for _, tree_node in ipairs(self.session_info_pane_tree:get_nodes()) do
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
    self.session_info_pane_tree:add_node(node, parent_node:get_id())
    parent_node.last_child_id = node:get_id()
    parent_node:expand()
  else
    self.session_info_pane_tree:add_node(node)
  end

  self.session_info_pane_tree:render(self.session_info_tree_render_linenr)
end

---Start progress view with a new run
---@param title string Title for the run
function ProgressView:start_run(title)
  self:add_progress_node({
    text = title,
    type = "run_node",
  })

  self:_setup_session_info_pane()
end

---@private
---Set up progress view pane
function ProgressView:_setup_progress_view_pane()
  self.progress_view_pane_tree = NuiTree({
    ns_id = self.progress_view_hl_ns,
    winid = self.progress_view.winid,
    bufnr = self.progress_view.bufnr,
    prepare_node = function(node, _)
      local line = NuiLine()

      line:append(string.rep(" ", node:get_depth()))

      ---@type progress_view_node_type
      local node_type = node.type
      ---@type progress_view_status
      local node_status = node.status or "no_op"

      local highlight = nil

      if node_status == "success" then
        highlight = hl_groups.RemoteNvimSuccess
      elseif node_status == "failed" then
        highlight = hl_groups.RemoteNvimFailure
      elseif node_status == "running" then
        highlight = hl_groups.RemoteNvimRunning
      elseif vim.tbl_contains({ "run_node", "section_node" }, node_type) then
        highlight = hl_groups.RemoteNvimHeading
      elseif node_type == "stdout_node" then
        highlight = hl_groups.RemoteNvimOutput
      elseif node_type == "command_node" then
        highlight = hl_groups.RemoteNvimInfoValue
      end
      highlight = highlight and highlight.name

      ---@type progress_view_node_type[]
      local section_nodes = { "section_node", "run_node" }
      if vim.tbl_contains(section_nodes, node.type) then
        line:append(node:is_expanded() and " " or " ", highlight)
      else
        line:append(" ")
      end

      if node_type == "command_node" then
        line:append("Command: ", hl_groups.RemoteNvimInfoKey.name)
      end
      line:append(node.text, highlight)

      if node_type == "run_node" and vim.tbl_contains({ "success", "failed" }, node_status) then
        line:append(" (no longer active)", hl_groups.RemoteNvimSubInfo.name)
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
  self:_set_top_line(self.progress_view.bufnr)
  self.progress_view_tree_render_linenr = vim.api.nvim_buf_line_count(self.progress_view.bufnr) + 1

  -- Set up key bindings
  local keymaps = self:_get_progressview_keymaps()
  local tree_keymaps = self:_get_tree_keymaps(self.progress_view_pane_tree, self.progress_view_tree_render_linenr)
  keymaps = vim.list_extend(keymaps, tree_keymaps)
  self:_set_buffer_keymaps(self.progress_view.bufnr, keymaps)
end

---@private
---Initialize session tree
function ProgressView:_initialize_session_info_tree()
  self.session_info_pane_tree = NuiTree({
    ns_id = self.progress_view_hl_ns,
    winid = self.progress_view.winid,
    bufnr = self.session_info_pane_bufnr,
    prepare_node = function(node, parent_node)
      local line = NuiLine()

      line:append(string.rep(" ", node:get_depth()))

      ---@type session_node_type
      local node_type = node.type

      if node_type == "root_node" then
        line:append((node:is_expanded() and " " or " ") .. node.value, hl_groups.RemoteNvimHeading.name)
      else
        line:append(" ")

        local node_value_hl = hl_groups.RemoteNvimInfo.name
        if node.key ~= nil then
          line:append(node.key .. ": ", hl_groups.RemoteNvimInfoKey.name)
          node_value_hl = hl_groups.RemoteNvimInfoValue.name
        end
        line:append(node.value or "<not-provided>", node_value_hl)
      end

      if
        (parent_node and parent_node.last_child_id == node:get_id())
        or (node.holds == "remote_node" and not node:is_expanded())
        or (node.type == "root_node" and node:is_expanded())
      then
        return {
          line,
          NuiLine(),
        }
      end

      return line
    end,
  })

  self:add_session_node({
    value = "Config",
    holds = "config_node",
    type = "root_node",
  })
  self:add_session_node({
    value = "Local config",
    holds = "local_node",
    type = "root_node",
  })
  self:add_session_node({
    value = "Remote config",
    holds = "remote_node",
    type = "root_node",
  })
end

---@private
---Set up "Session Info" pane
function ProgressView:_setup_session_info_pane()
  self:_set_top_line(self.session_info_pane_bufnr, true)
  self.session_info_tree_render_linenr = vim.api.nvim_buf_line_count(self.session_info_pane_bufnr) + 1
  self:_initialize_session_info_tree()

  -- Set up key bindings
  local keymaps = self:_get_progressview_keymaps()
  local tree_keymaps = self:_get_tree_keymaps(self.session_info_pane_tree, self.session_info_tree_render_linenr)
  keymaps = vim.list_extend(keymaps, tree_keymaps)
  self:_set_buffer_keymaps(self.session_info_pane_bufnr, keymaps)

  for key, val in pairs(self.progress_view_buf_options) do
    vim.api.nvim_set_option_value(key, val, {
      buf = self.session_info_pane_bufnr,
    })
  end

  self.session_info_pane_tree:render(self.session_info_tree_render_linenr)
end

---@private
---Keymaps to apply on the buffer
---@param bufnr integer Buffer ID on which the keymap should be set
---@param keymaps remote-nvim.ui.ProgressView.Keymaps[] List of keymaps to set up on the buffer
function ProgressView:_set_buffer_keymaps(bufnr, keymaps)
  for _, val in ipairs(keymaps) do
    local options = vim.deepcopy(self.progress_view_keymap_options)
    options["callback"] = val.action
    vim.api.nvim_buf_set_keymap(bufnr, "n", val.key, "", options)
  end
end

---@private
---Set up "Help" pane
function ProgressView:_setup_help_pane()
  self:_set_top_line(self.help_pane_bufnr)
  local line_nr = vim.api.nvim_buf_line_count(self.help_pane_bufnr) + 1

  local keymaps = self:_get_progressview_keymaps()
  self:_set_buffer_keymaps(self.help_pane_bufnr, keymaps)

  -- Get tree keymaps (we use this to set help and do not set up any extra keybindings)
  local tree_keymaps = self:_get_tree_keymaps(self.progress_view_pane_tree, self.progress_view_tree_render_linenr)
  vim.list_extend(keymaps, tree_keymaps)

  local max_length = 0
  for _, v in ipairs(keymaps) do
    max_length = math.max(max_length, #v.key)
  end

  vim.bo[self.help_pane_bufnr].readonly = false
  vim.bo[self.help_pane_bufnr].modifiable = true

  -- Add Keyboard shortcuts heading
  local line = NuiLine()
  line:append(" Keyboard shortcuts", hl_groups.RemoteNvimHeading.name)
  line:render(self.help_pane_bufnr, -1, line_nr)
  vim.api.nvim_buf_set_lines(self.help_pane_bufnr, line_nr, line_nr, true, { "" })
  line_nr = line_nr + 2

  for _, v in ipairs(keymaps) do
    line = NuiLine()

    line:append("  " .. v.key .. string.rep(" ", max_length - #v.key), hl_groups.RemoteNvimInfoKey.name)
    line:append(" " .. v.desc, hl_groups.RemoteNvimInfoValue.name)
    line:render(self.help_pane_bufnr, -1, line_nr)
    line_nr = line_nr + 1
  end

  for key, val in pairs(self.progress_view_buf_options) do
    vim.api.nvim_set_option_value(key, val, {
      buf = self.help_pane_bufnr,
    })
  end
end

---@private
---@param tree NuiTree Tree on which keymaps will be set
---@param start_linenr number What line number on the buffer should the tree be rendered from
---@return remote-nvim.ui.ProgressView.Keymaps[]
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

---@private
---Get keymaps that apply to all panes
---@return remote-nvim.ui.ProgressView.Keymaps[]
function ProgressView:_get_progressview_keymaps()
  return {
    {
      key = "P",
      action = function()
        self:_set_buffer(self.progress_view.bufnr)
      end,
      desc = "Switch to Progress view",
    },
    {
      key = "S",
      action = function()
        self:_set_buffer(self.session_info_pane_bufnr)
      end,
      desc = "Switch to Session Info view",
    },
    {
      key = "?",
      action = function()
        local switch_to_bufnr = (vim.api.nvim_win_get_buf(self.progress_view.winid) == self.help_pane_bufnr)
            and self.progress_view.bufnr
          or self.help_pane_bufnr
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

---Add a node to the progress view pane
---@param node remote-nvim.ui.ProgressView.ProgressInfoNode Node to insert into progress view tree
---@param parent_node NuiTree.Node? Node under which the new node should be inserted
---@return NuiTree.Node created_node The node that was created and inserted into the progress tree
function ProgressView:add_progress_node(node, parent_node)
  ---@type progress_view_status
  local status = node.status or "no_op"

  ---@type NuiTree.Node
  local created_node
  if node.text ~= nil then
    if node.type == "section_node" then
      created_node = self:_add_progress_view_section(node, parent_node)
    elseif node.type == "run_node" then
      created_node = self:_add_progress_view_run_section(node)
    else
      created_node = self:_add_progress_view_output_node(node, parent_node)
    end
  end

  self:update_status(status, node.set_parent_status, created_node)

  return created_node
end

---Update status of the node and if needed, it's parent nodes
---@param status progress_view_status Status to apply on the node
---@param should_update_parent_status boolean? Should all parent nodes of the node being updated be updated as well
---@param node NuiTree.Node?
function ProgressView:update_status(status, should_update_parent_status, node)
  node = node or self.active_progress_view_section_node or self.active_progress_view_run_node
  assert(node ~= nil, "Node should not be nil")
  node.status = status

  -- Update parent node's status as well
  if should_update_parent_status then
    local parent_node_id = node:get_parent_id()
    while parent_node_id ~= nil do
      local parent_node = self.progress_view_pane_tree:get_node(parent_node_id)
      parent_node.status = status
      ---@diagnostic disable-next-line:need-check-nil
      parent_node_id = parent_node:get_parent_id()
    end

    if self.session_info_pane_tree then
      -- Delete all info_node from session info tree (since they are from a previous run)
      local updated = false
      for _, si_node in ipairs(self.session_info_pane_tree:get_nodes()) do
        if si_node.type == "info_node" then
          updated = true
          self.session_info_pane_tree:remove_node(si_node:get_id())
        end
      end

      if updated then
        self.session_info_pane_tree:render(self.session_info_tree_render_linenr)
      end
    end
  end

  if not vim.tbl_contains({ "success", "warning" }, node.status) then
    node:expand()
  end

  -- If it is a successful node, we close it
  if status == "success" then
    node:collapse()
  end
  self.progress_view_pane_tree:render(self.progress_view_tree_render_linenr)
end

---@private
---Add new progress view section to an active run
---@param node remote-nvim.ui.ProgressView.ProgressInfoNode Section node to be inserted into progress view
---@param parent_node NuiTree.Node? Node under which the new node should be inserted
---@return NuiTree.Node section_node The created section node
function ProgressView:_add_progress_view_section(node, parent_node)
  parent_node = parent_node or self.active_progress_view_run_node
  assert(parent_node ~= nil, "Run section node should not be nil")

  -- If we were working with a previous active section, collapse it
  if self.active_progress_view_section_node then
    self.active_progress_view_section_node:collapse()
  end

  local section_node = NuiTree.Node({
    text = node.text,
    ---@type progress_view_node_type
    type = node.type,
  }, {})
  self.progress_view_pane_tree:add_node(section_node, parent_node:get_id())
  self.active_progress_view_section_node = section_node
  self.active_progress_view_section_node:expand()

  return section_node
end

---@private
---Add new progress view run section
---@param node remote-nvim.ui.ProgressView.ProgressInfoNode Run node to insert into progress view
---@return NuiTree.Node created_node Created run node
function ProgressView:_add_progress_view_run_section(node)
  self.active_progress_view_run_node = NuiTree.Node({
    text = node.text,
    type = node.type,
  }, {})
  self.progress_view_pane_tree:add_node(self.active_progress_view_run_node)

  -- Collapse all nodes, and then expand current run section
  self:_collapse_all_nodes(self.progress_view_pane_tree, self.progress_view_tree_render_linenr)
  self.active_progress_view_run_node:expand()

  return self.active_progress_view_run_node
end

---@private
---Add output node to the progress view tree
---@param node remote-nvim.ui.ProgressView.ProgressInfoNode Output to be inserted
---@param parent_node NuiTree.Node? Node to which the output node should be attached
---@return NuiTree.Node created_node Created output node
function ProgressView:_add_progress_view_output_node(node, parent_node)
  parent_node = parent_node or self.active_progress_view_section_node
  assert(parent_node ~= nil, "Parent node should not be nil")

  local created_node = NuiTree.Node({
    text = node.text,
    type = node.type,
  })
  self.progress_view_pane_tree:add_node(created_node, parent_node:get_id())

  return created_node
end

return ProgressView
