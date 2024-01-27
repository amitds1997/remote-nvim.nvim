local previewer_utils = require("telescope.previewers.utils")
local previewers = require("telescope.previewers")
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")

local function remote_nvim_existing_workspace_action(opts)
  opts = opts or {}
  local config_provider = remote_nvim.session_provider:get_config_provider()

  local previewer = previewers.new_buffer_previewer({
    define_preview = function(self, entry)
      local host_config = config_provider:get_workspace_config(entry.value)

      -- Find the longest key length
      local max_key_length = 0
      for key, _ in pairs(host_config) do
        max_key_length = math.max(max_key_length, #key)
      end

      local lines = {}
      for key, value in pairs(host_config) do
        local formatted_key = string.format("%-" .. max_key_length .. "s", key:gsub("_", " "):gsub("^%l", string.upper))
        table.insert(lines, "  " .. formatted_key .. " : " .. tostring(value))
      end
      table.sort(lines)

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      previewer_utils.highlighter(self.state.bufnr, "yaml")
    end,
  })

  pickers
    .new(opts, {
      prompt_title = "Connect to saved workspace",
      previewer = previewer,
      finder = finders.new_table({
        results = vim.tbl_keys(config_provider:get_workspace_config()),
        entry_maker = function(entry)
          return {
            display = function(input)
              ---@type string
              ---@diagnostic disable-next-line:assign-type-mismatch
              local host_identifier = input.value
              local colon_position = host_identifier:find(":")

              local login_identifier, port
              if colon_position then
                login_identifier = host_identifier:sub(1, colon_position - 1)
                port = host_identifier:sub(colon_position + 1)
                return login_identifier .. " on port " .. port
              else
                return host_identifier
              end
            end,
            ordinal = entry,
            value = entry,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          local host_identifier = selection.value
          ---@type remote-nvim.providers.WorkspaceConfig
          local workspace_data = config_provider:get_workspace_config(host_identifier)
          remote_nvim.session_provider
            :get_or_initialize_session({
              host = workspace_data.host,
              provider_type = workspace_data.provider,
              unique_host_id = host_identifier,
              conn_opts = { workspace_data.connection_options },
            })
            :launch_neovim()
        end)
        return true
      end,
    })
    :find()
end

return {
  name = "Remote Neovim: Connect to existing workspace",
  value = "remote-nvim-known-workspace",
  action = remote_nvim_existing_workspace_action,
  priority = 90,
  help = [[
## Description

Allows you to select any workspaces that you have previously configured using this plugin. Remembers workspace-specific settings so you do not need to configure it again.
]],
}
