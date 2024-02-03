local previewer_utils = require("telescope.previewers.utils")
local previewers = require("telescope.previewers")
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")

---Generate preview for the telescope picker
---@param host remote-nvim.ssh.SSHConfigHost
---@return string[] rendered_lines Lines to render
local function build_preview_host(host)
  local lines = {}

  table.insert(lines, "# Config: " .. host.source_file)
  table.insert(lines, "")
  for key, value in vim.spairs(host.parsed_config) do
    table.insert(lines, string.format("  %s %s", key, value))
  end

  return lines
end

local function ssh_known_host_action(opts)
  opts = opts or {}

  ---@type remote-nvim.ssh.SSHConfigParser
  local ssh_config_parser = require("remote-nvim.providers.ssh.ssh_config_parser")()
  for _, file_path in ipairs(remote_nvim.config.ssh_config.ssh_config_file_paths) do
    ssh_config_parser = ssh_config_parser:parse_config_file(file_path)
  end
  local hosts = ssh_config_parser:get_config()

  local previewer = previewers.new_buffer_previewer({
    define_preview = function(self, entry)
      local lines = build_preview_host(hosts[entry.value])
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      previewer_utils.highlighter(self.state.bufnr, "sshconfig")
    end,
  })

  pickers
    .new(opts, {
      prompt_title = "Connect to remote host",
      previewer = previewer,
      finder = finders.new_table({
        results = vim.tbl_keys(hosts),
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(bufnr, _)
        actions.select_default:replace(function()
          actions.close(bufnr)
          local selection = action_state.get_selected_entry()
          local host = selection.value
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

1. If your `ssh_config` hosts do not show up, try adjusting the paths searched using `ssh_config.ssh_config_file_paths` in plugin configuration.
2. Wildcard pattern based hosts will not show up here. Use `manual input` and pass the host name. SSH config file parameters will automatically be applied.
3. `Match` directive is ignored to build this preview. Use SSH manual input to pass any directive based on that
]],
}
