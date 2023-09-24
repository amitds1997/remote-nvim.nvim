local previewer_utils = require("telescope.previewers.utils")
local previewers = require("telescope.previewers")
local remote_nvim = require("remote-nvim")
local telescope = require("telescope")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")

-- Build host file from parsed hosts from plugin
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

local function select_ssh_host_from_workspace_config(opts)
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
            :get_or_initialize_session("ssh", workspace_data.host, workspace_data.connection_options)
            :launch_neovim()
        end)
        return true
      end,
    })
    :find()
end

local function select_ssh_host_from_ssh_config(opts)
  opts = opts or {}

  local hosts = require("remote-nvim.providers.ssh.ssh_config_parser").parse_ssh_configs(
    remote_nvim.config.ssh_config.ssh_config_file_paths
  )

  -- Build previewer
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
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          local host = selection.value["Host"]
          remote_nvim.session_provider:get_or_initialize_session("ssh", host, ""):launch_neovim()
        end)
        return true
      end,
    })
    :find()
end

local function select_ssh_input_method(opts)
  opts = opts or {}
  local possible_ssh_options = {
    {
      name = "Select already configured workspaces...",
      value = "existing-workspace",
      help = [[Select one of the already configured workspaces. This could be useful for quickly starting any existing workspaces that you configured earlier.

NOTE: You might want to select "Connect to host using connection string" if you want to modify the connection options passed when connecting to the host. Don't worry, if you previously configured the host, saved configuration would be re-used.]],
    },
    {
      name = "Select host from SSH Config file",
      value = "ssh-config",
      help = [[Choosing this will allow you to choose one of the known hosts from your `ssh-config` files. The list used can be configured using the `ssh-config-files` flag.

The current known host parser only deals with exact host matches. If you have specified a regex for host matching, use the 'Connect to host using connection string' option and type the name of the host. If your underlying binary can match the regex, it would work.]],
    },
    {
      name = "Connect to host using connection string",
      value = "manual-ssh-input",
      help = [[Next prompt would allow you to type in your SSH configuration.

| In terminal                 | Type this in next prompt|
| --------------------------- | ----------------------- |
| ssh abc@xyz.com             | abc@xyz.com             |
| ssh known-host              | known-host              |
| ssh -i ~/key.pem known-host | -i ~/key.pem known-host |

You get the gist. Just remove `ssh` from the beginning of what you would normally type, and you should be golden.]],
    },
  }
  if not (#vim.tbl_keys(remote_nvim.session_provider:get_saved_host_configs("ssh")) > 0) then
    table.remove(possible_ssh_options, 1)
  end

  local function adjust_line_for_buffer(self, line)
    local buffer_width = vim.api.nvim_win_get_width(self.state.winid)
    return vim.fn.split(line, "\\%>" .. buffer_width .. "v", true)
  end

  local previewer = previewers.new_buffer_previewer({
    define_preview = function(self, entry)
      local lines = {}
      for _, line in ipairs(vim.fn.split(entry.help, "\n", true)) do
        for _, wrapped_line in ipairs(adjust_line_for_buffer(self, line)) do
          table.insert(lines, wrapped_line)
        end
      end
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      previewer_utils.highlighter(self.state.bufnr, "markdown")
    end,
  })

  pickers
    .new(opts, {
      prompt_title = "Select SSH entry method",
      previewer = previewer,
      finder = finders.new_table({
        results = possible_ssh_options,
        entry_maker = function(entry)
          return {
            display = entry.name,
            ordinal = entry.name,
            value = entry.value,
            help = entry.help,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection.value == "ssh-config" then
            select_ssh_host_from_ssh_config(opts)
          elseif selection.value == "existing-workspace" then
            select_ssh_host_from_workspace_config(opts)
          elseif selection.value == "manual-ssh-input" then
            local ssh_args = vim.fn.input("ssh ")
            if ssh_args == "" then
              return
            end
            local ssh_host = ssh_args:match("%S+@%S+")
            if ssh_host == nil or ssh_host == "" then
              vim.notify("Could not detect host name.")
              ssh_host = vim.fn.input("Host name: ")
            end

            -- If no valid host name has been provided, exit
            if ssh_host == "" then
              return
            end
            remote_nvim.session_provider:get_or_initialize_session("ssh", ssh_host, ssh_args):launch_neovim()
          end
        end)
        return true
      end,
    })
    :find()
end

return telescope.register_extension({
  exports = {
    connect = function(_)
      select_ssh_input_method(_)
    end,
  },
})
