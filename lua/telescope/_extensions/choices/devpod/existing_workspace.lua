---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

local function show_workspace_list(workspace_list)
  if not workspace_list then
    error("Error: Unable to retrieve Docker container list.")
    return
  end

  local items = {}
  for _, line in ipairs(workspace_list) do
    table.insert(items, line)
  end

  vim.schedule(function()
    vim.ui.select(items, {
      prompt = "Devpod workspaces",
      format_item = function(workspace_info)
        return workspace_info.id
      end,
    }, function(choice)
      if not choice then
        return
      end
      remote_nvim.session_provider
        :get_or_initialize_session({
          provider_type = "devpod",
          host = choice.id,
          unique_host_id = vim.tbl_values(choice.source)[1],
          devpod_opts = {},
        })
        :launch_neovim()
    end)
  end)
end

local function devpod_existing_workspace_action()
  local devpod_workspace_cmd = ("%s list --output json"):format(remote_nvim.config.devpod.binary)

  local json_output = vim.json.decode(vim.fn.system(devpod_workspace_cmd))
  show_workspace_list(json_output)
end

return {
  name = "DevPod: Attach to existing devpod workspace",
  value = "devpod-attach-existing-workspace",
  action = devpod_existing_workspace_action,
  priority = 10,
  help = [[
## Description

Devpod allows a lot more options in terms of providers where dev containers can be lauched. The entire range is currently not supported by this plugin. So, once you configure it through DevPod CLI/UI, you can use this plugin to launch Neovim in that workspace, be it docker or k8s.
]],
}
