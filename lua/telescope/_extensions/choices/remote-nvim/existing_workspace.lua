local previewer_utils = require("telescope.previewers.utils")
local previewers = require("telescope.previewers")
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")

---@param source_config remote-nvim.providers.DevpodSourceOpts
local function get_devpod_description(source_config)
  if source_config.type == "image" then
    return ("This workspace was created from image **%s**"):format(source_config.id)
  elseif source_config.type == "container" then
    return ("This workspace was created using container **%s** (*%s*)"):format(source_config.name, source_config.id)
  elseif source_config.type == "branch" then
    return ("This workspace was created from branch **%s** in repo *%s*"):format(source_config.id, source_config.name)
  elseif source_config.type == "repo" then
    return ("This workspace was created from repo **%s**"):format(source_config.id)
  elseif source_config.type == "pr" then
    return ("This workspace was created from **PR no. %s** on repo *%s*"):format(source_config.id, source_config.name)
  elseif source_config.type == "commit" then
    return ("This workspace was created from commit *%s* in repo *%s*"):format(source_config.id, source_config.name)
  end
end

---Get workspace name for SSH sources
---@param host_id string Host identifier
local function get_ssh_name(host_id)
  local colon_position = host_id:find(":")
  local login_identifier, port
  local name = host_id

  if colon_position then
    login_identifier = host_id:sub(1, colon_position - 1)
    port = host_id:sub(colon_position + 1)
    name = login_identifier .. (" (on port %s)"):format(port)
  end
  name = ("SSH: %s"):format(name)

  return name
end

---Get workspace name for devpod sources
---@param host_id string
---@param source_config remote-nvim.providers.DevpodSourceOpts
local function get_devpod_name(host_id, source_config)
  if source_config.type == "container" then
    return ("%s: %s"):format(string.upper(source_config.type), source_config.name)
  end

  return ("%s: %s"):format(string.upper(source_config.type), host_id)
end

local function remote_nvim_existing_workspace_action(opts)
  opts = opts or {}
  local config_provider = remote_nvim.session_provider:get_config_provider()

  local previewer = previewers.new_buffer_previewer({
    define_preview = function(self, entry)
      ---@type remote-nvim.providers.WorkspaceConfig
      local host_config = entry.value["config"]

      -- Find the longest key length
      local max_key_length = 0
      for key, _ in pairs(host_config) do
        max_key_length = math.max(max_key_length, #key)
      end

      local lines = {}
      for key, value in pairs(host_config) do
        if type(value) ~= "table" then
          local formatted_key =
            string.format("%-" .. max_key_length .. "s", key:gsub("_", " "):gsub("^%l", string.upper))
          table.insert(lines, "  " .. formatted_key .. " : " .. tostring(value))
        end
      end
      table.sort(lines)

      local preview_lines = {
        ("# %s"):format(entry.value["host_id"]),
        "",
        "## Description",
        "",
      }

      local description = ""
      if host_config.devpod_source_opts ~= nil then
        description = get_devpod_description(host_config.devpod_source_opts)
      elseif host_config.provider == "ssh" then
        description = ("This workspace is for SSH host **%s**"):format(entry.value["host_id"])
      end

      preview_lines = vim.list_extend(preview_lines, {
        description,
        "",
        "## Configuration",
        "```yaml",
      })

      preview_lines = vim.list_extend(preview_lines, lines)
      table.insert(preview_lines, "```")

      vim.api.nvim_set_option_value("wrap", true, {
        win = self.state.winid,
      })
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, preview_lines)
      previewer_utils.highlighter(self.state.bufnr, "markdown")
    end,
  })

  local display_name = function(host_id, workspace_config)
    if workspace_config.devpod_source_opts ~= nil then
      return get_devpod_name(host_id, workspace_config.devpod_source_opts)
    elseif workspace_config.provider == "ssh" then
      return get_ssh_name(host_id)
    end
  end

  local picker_dict = {}
  for host_id, workspace_config in pairs(config_provider:get_workspace_config()) do
    table.insert(picker_dict, {
      host_id = host_id,
      display = display_name(host_id, workspace_config),
      config = workspace_config,
    })
  end

  pickers
    .new(opts, {
      prompt_title = "Connect to saved workspace",
      previewer = previewer,
      finder = finders.new_table({
        results = picker_dict,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry["display"],
            ordinal = entry["display"],
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          local host_identifier = selection.value["host_id"]
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
