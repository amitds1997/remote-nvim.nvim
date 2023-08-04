local previewer_utils = require("telescope.previewers.utils")
local previewers = require("telescope.previewers")
local remote_nvim = require("remote-nvim")
local telescope = require("telescope")
local conf = require("telescope.config").values
local RemoteNeovimSSHProvider = require("remote-nvim.providers.ssh.ssh_provider")
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local remote_nvim_utils = require("remote-nvim.utils")

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
  local workspace_config = require("remote-nvim").host_workspace_config

  local previewer = previewers.new_buffer_previewer({
    define_preview = function(self, entry)
      local host_config = workspace_config:get_workspace_config_data(entry.value)
      host_config["Host ID"] = entry.value

      local max_key_length = 0

      -- Find the longest key length
      for key, _ in pairs(host_config) do
        max_key_length = math.max(max_key_length, #key)
      end

      local lines = {}
      for key, value in pairs(host_config) do
        local formatted_key = string.format("%-" .. max_key_length .. "s", key:gsub("_", " "):gsub("^%l", string.upper))
        table.insert(lines, "  " .. formatted_key .. " = " .. value)
      end
      table.sort(lines)

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      previewer_utils.highlighter(self.state.bufnr, "toml")
    end,
  })

  pickers
    .new(opts, {
      prompt_title = "Connect to saved workspace",
      previewer = previewer,
      finder = finders.new_table({
        results = workspace_config:get_all_host_ids(),
        entry_maker = function(entry)
          return {
            display = function(input)
              local host_identifier = input.value
              local at_position = host_identifier:find("@")
              local colon_position = host_identifier:find(":")

              local username, hostname, port
              if at_position and colon_position then
                username = host_identifier:sub(1, at_position - 1)
                hostname = host_identifier:sub(at_position + 1, colon_position - 1)
                port = host_identifier:sub(colon_position + 1)
                return "User '" .. username .. "' at " .. hostname .. " on port " .. port
              elseif colon_position then
                hostname = host_identifier:sub(1, colon_position - 1)
                port = host_identifier:sub(colon_position + 1)
                return hostname .. " on port " .. port
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
          local workspace_data = workspace_config:get_workspace_config_data(host_identifier)
          remote_nvim.sessions[host_identifier] = remote_nvim.sessions[host_identifier]
            or RemoteNeovimSSHProvider:new(workspace_data.host, workspace_data.connection_options)
          remote_nvim.sessions[host_identifier]:set_up_remote()
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
          remote_nvim.sessions[host] = remote_nvim.sessions[host] or RemoteNeovimSSHProvider:new(host)
          remote_nvim.sessions[host]:set_up_remote()
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

            local host_identifier = remote_nvim_utils.get_host_identifier(ssh_host, ssh_args)
            remote_nvim.sessions[host_identifier] = remote_nvim.sessions[host_identifier]
              or RemoteNeovimSSHProvider:new(ssh_host, ssh_args)
            remote_nvim.sessions[host_identifier]:set_up_remote()
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
