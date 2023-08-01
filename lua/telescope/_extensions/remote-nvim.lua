local RemoteNvimSession = require("remote-nvim.session")
local previewer_utils = require("telescope.previewers.utils")
local previewers = require("telescope.previewers")
local remote_nvim = require("remote-nvim")
local remote_ssh = require("remote-nvim.ssh")
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

local function select_ssh_host_from_ssh_config(opts)
  opts = opts or {}

  local hosts = remote_ssh.list_hosts()

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
          remote_nvim.remote_sessions[host] = remote_nvim.remote_sessions[host] or RemoteNvimSession:new(host)
          remote_nvim.remote_sessions[host]:launch()
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
      name = "Remote-Neovim: Select saved SSH Host config",
      value = "ssh-config",
      help = [[Choosing this will allow you to choose one of the known hosts from your `ssh-config` files. The list used can be configured using the `ssh-config-files` flag.

The current known host parser only deals with exact host matches. If you have specified a regex for host matching, use the 'Remote-Neovim: Select saved SSH Host config' option and type the name of the host. If your underlying binary can match the regex, it would work.]],
    },
    {
      name = "Remote-Neovim: Connect to host using passed parameters",
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
          elseif selection.value == "manual-ssh-input" then
            local ssh_args = vim.fn.input("ssh ")
            local ssh_host = ssh_args:match("%S+@%S+")
            if ssh_host == nil then
              ssh_host = vim.fn.input("Please provide host name: ")
            end
            RemoteNvimSession:new(ssh_host, ssh_args):launch()
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
