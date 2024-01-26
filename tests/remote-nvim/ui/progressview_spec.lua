---@diagnostic disable
local NuiLine = require("nui.line")
local NuiTree = require("nui.tree")
local assert = require("luassert.assert")
local match = require("luassert.match")
local stub = require("luassert.stub")

describe("Progress view should ensure that", function()
  ---@type remote-nvim.ui.ProgressView
  local progress_view
  local temp_buf_id

  before_each(function()
    progress_view = require("remote-nvim.ui.progressview")()
    progress_view:show()
  end)

  it("buffer is assigned correctly to the progress view", function()
    temp_buf_id = vim.api.nvim_create_buf(false, true)

    -- We set one of the properties to opposite of what set buffer would do to
    -- ensure that it is set
    vim.api.nvim_set_option_value("number", true, {
      win = progress_view.progress_view.winid,
    })
    progress_view:_set_buffer(temp_buf_id)

    assert.equals(temp_buf_id, vim.api.nvim_win_get_buf(progress_view.progress_view.winid))
    assert.is_false(vim.api.nvim_get_option_value("number", {
      win = progress_view.progress_view.winid,
    }))
  end)

  it("buffer has the correct top line set", function()
    temp_buf_id = vim.api.nvim_create_buf(false, true)
    progress_view:_set_top_line(temp_buf_id)

    assert.are.same(
      { "", "  Progress View (P)   Session Info (S)   Help (?) " },
      vim.api.nvim_buf_get_lines(temp_buf_id, 0, vim.api.nvim_buf_line_count(temp_buf_id) - 1, true)
    )
  end)

  it("correct window is shown", function()
    progress_view:show()
    assert.equals(progress_view.progress_view.winid, vim.api.nvim_get_current_win())
  end)

  describe("all nodes are", function()
    local node_b, node_c, tree
    before_each(function()
      temp_buf_id = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, temp_buf_id)

      node_b = NuiTree.Node({ text = "b" }, {
        NuiTree.Node({ text = "b-1" }),
        NuiTree.Node({ text = "b-2" }, {
          NuiTree.Node({ text = "b-1-a" }),
          NuiTree.Node({ text = "b-2-b" }),
        }),
      })
      node_c = NuiTree.Node({ text = "c" }, {
        NuiTree.Node({ text = "c-1" }),
        NuiTree.Node({ text = "c-2" }),
      })

      tree = NuiTree({
        winid = vim.api.nvim_get_current_win(),
        bufnr = temp_buf_id,
        nodes = {
          NuiTree.Node({ text = "a" }),
          node_b,
          node_c,
        },
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
    end)

    it("all nodes are collapsed when needed", function()
      node_b:expand()
      node_c:expand()
      assert.is_true(node_b:is_expanded())
      assert.is_true(node_c:is_expanded())

      progress_view:_collapse_all_nodes(tree, 1)
      assert.is_false(node_b:is_expanded())
      assert.is_false(node_c:is_expanded())
    end)

    it("all nodes are expanded when needed", function()
      node_b:collapse()
      node_c:collapse()
      assert.is_false(node_b:is_expanded())
      assert.is_false(node_c:is_expanded())

      progress_view:_expand_all_nodes(tree, 1)
      assert.is_true(node_b:is_expanded())
      assert.is_true(node_c:is_expanded())
    end)
  end)

  describe("we can add a session node correctly", function()
    ---@type NuiTree
    local session_tree
    before_each(function()
      session_tree = progress_view.session_info_pane_tree
    end)

    it("when there is a parent node", function()
      ---@type NuiTree.Node
      local config_holder_node
      for _, node in ipairs(session_tree:get_nodes()) do
        if node.holds == "config_node" then
          config_holder_node = node
          break
        end
      end

      local node = progress_view:add_session_node({
        type = "config_node",
        value = "<temp-value>",
        key = "<temp-key>",
      })
      assert.is_not_nil(session_tree:get_node(node:get_id()))
      assert.equals(config_holder_node:get_id(), node:get_parent_id())
    end)

    it("when there is no parent node", function()
      local node = progress_view:add_session_node({
        type = "random_node",
        value = "<temp-value>",
        key = "<temp-key>",
      })

      assert.is_not_nil(session_tree:get_node(node:get_id()))
      assert.is_nil(node:get_parent_id())
    end)
  end)

  it("start run gets initialized correctly", function()
    local add_progress_node_stub = stub(progress_view, "add_progress_node")
    local title = "Fantastic Series Run 1"

    progress_view:start_run(title)
    assert.stub(add_progress_node_stub).was.called_with(match.is_ref(progress_view), {
      text = title,
      type = "run_node",
    })
  end)

  describe("updating node status works correctly", function()
    ---@type NuiTree.Node
    local run_node
    ---@type NuiTree.Node
    local section_node
    ---@type NuiTree.Node
    local output_node

    before_each(function()
      run_node = progress_view:start_run("Test run")
      section_node = progress_view:add_progress_node({
        type = "section_node",
        text = "Test section",
        status = "running",
      }, run_node)
      output_node = progress_view:add_progress_node({
        type = "stdout_node",
        status = "running",
        text = "Temp output",
      }, section_node)
    end)

    it("when only updating the node with no children", function()
      assert.equals("running", output_node.status)
      progress_view:update_status("success", false, output_node)
      assert.equals("success", output_node.status)
    end)

    describe("when only updating the node with children", function()
      it("with status success", function()
        section_node:collapse()
        progress_view:update_status("success", false, section_node)

        assert.equals("success", section_node.status)
        assert.is_false(section_node:is_expanded())
      end)
      it("with any other status", function()
        section_node:collapse()
        progress_view:update_status("failed", false, section_node)

        assert.equals("failed", section_node.status)
        assert.is_true(section_node:is_expanded())
      end)
    end)

    it("when updating node and its parents", function()
      assert.equals("running", output_node.status)
      assert.equals("running", section_node.status)

      progress_view:update_status("success", true, output_node)

      assert.equals("success", output_node.status)
      assert.equals("success", section_node.status)
      assert.equals("success", run_node.status)
    end)
  end)

  it("adding new section to the active run works correctly", function()
    progress_view:start_run("Test run")
    local node = progress_view:_add_progress_view_section_heading({
      type = "section_node",
      text = "Test section 1",
    })

    assert.is_not_nil(progress_view.progress_view_pane_tree:get_node(node:get_id()))
    assert.is_true(progress_view.active_progress_view_section_node:is_expanded())
  end)

  it("adding new run node works correctly", function()
    local run_node_1 = progress_view:start_run("Test run")
    assert.is_not_nil(progress_view.progress_view_pane_tree:get_node(run_node_1:get_id()))
    assert.is_true(run_node_1:is_expanded())

    local run_node_2 = progress_view:start_run("Test run 2")
    assert.is_false(run_node_1:is_expanded())
    assert.is_true(run_node_2:is_expanded())
  end)

  it("adding output node works correctly", function()
    progress_view:start_run("Test run")
    local section_node = progress_view:_add_progress_view_section_heading({
      type = "section_node",
      text = "Test section",
    })
    local node = progress_view:_add_progress_view_output_node({
      type = "run_node",
      text = "Output 1",
    }, section_node)
    assert.is_not_nil(progress_view.progress_view_pane_tree:get_node(node:get_id()))
  end)
end)
