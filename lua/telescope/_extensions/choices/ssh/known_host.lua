local previewer_utils = require("telescope.previewers.utils")
local previewers = require("telescope.previewers")
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")

local function build_preview_host(host)
  local lines = {}

  table.insert(lines, "# Config: " .. host["Config"])
  for key, value in pairs(host) do
    if key ~= "Config" then
      table.insert(lines, string.format("\t%s %s", key, value))
    end
  end
  table.insert(lines, "")

  return lines
end

local function ssh_known_host_action(opts)
  opts = opts or {}

  local hosts = require("remote-nvim.providers.ssh.ssh_config_parser").parse_ssh_configs(
    remote_nvim.config.ssh_config.ssh_config_file_paths
  )

  local previewer = previewers.new_buffer_previewer({
    define_preview = function(self, entry)
      local lines = build_preview_host(entry.value)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      previewer_utils.highlighter(self.state.bufnr, "sshconfig")
    end,
  })

  pickers
    .new(opts, {
      prompt_title = "Connect to remote host",
      previewer = previewer,
      finder = finders.new_table({
        results = vim.tbl_values(hosts),
        entry_maker = function(entry)
          return {
            display = entry["Host"],
            ordinal = entry["Host"],
            value = entry,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(bufnr, _)
        actions.select_default:replace(function()
          actions.close(bufnr)
          local selection = action_state.get_selected_entry()
          local host = selection.value["Host"]
          remote_nvim.session_provider
            :get_or_initialize_session({
              host = host,
              provider_type = "ssh",
            })
            :launch_neovim()
        end)
        return true
      end,
    })
    :find()
end

return {
  name = "Remote SSH: Set up configured SSH host",
  value = "remote-ssh-configured-host",
  action = ssh_known_host_action,
  priority = 85,
  help = [[
## Description

Select one of the saved hosts from one of your `ssh_config` files. Recursively parses any `ssh_config` files expressed through `Include` clause.

## Additional notes

If your `ssh_config` hosts do not show up, try adjusting the paths searched using `ssh_config.ssh_config_file_paths` in plugin configuration.
]],
}
