local nio = require("nio")
local previewer_utils = require("telescope.previewers.utils")
local previewers = require("telescope.previewers")
local telescope = require("telescope")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")

local function choose_launch_option(opts)
  nio.run(function()
    local choices = require("telescope._extensions.choices")()

    local previewer = previewers.new_buffer_previewer({
      define_preview = function(self, entry)
        vim.api.nvim_set_option_value("wrap", true, {
          win = self.state.winid,
        })
        vim.api.nvim_set_option_value("linebreak", true, {
          win = self.state.winid,
        })

        local lines = {}
        for _, line in ipairs(vim.fn.split(entry.preview_text, "\n", true)) do
          table.insert(lines, line)
        end
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        previewer_utils.highlighter(self.state.bufnr, "markdown")
      end,
      title = "Option help",
    })

    pickers
      .new(opts, {
        prompt_title = "Filter launch options",
        previewer = previewer,
        finder = finders.new_table({
          results = choices,
          entry_maker = function(entry)
            return {
              display = entry.name,
              ordinal = entry.name,
              value = entry.value,
              action = entry.action,
              preview_text = entry.help,
            }
          end,
        }),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(bufnr, _)
          actions.select_default:replace(function()
            local selection = action_state.get_selected_entry()
            actions.close(bufnr)
            selection.action(opts)
          end)
          return true
        end,
      })
      :find()
  end)
end

return telescope.register_extension({
  exports = {
    connect = choose_launch_option,
  },
})
