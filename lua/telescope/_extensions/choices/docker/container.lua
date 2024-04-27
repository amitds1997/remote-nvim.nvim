local nio = require("nio")
---@type remote-nvim.RemoteNeovim
local remote_nvim = require("remote-nvim")

local function show_container_list(container_list)
  if not container_list then
    error("Error: Unable to retrieve Docker container list.")
    return
  end

  local items = {}
  for _, line in ipairs(container_list) do
    table.insert(items, vim.json.decode(line))
  end

  vim.schedule(function()
    vim.ui.select(items, {
      prompt = "Docker containers",
      format_item = function(container_info)
        return container_info.Names .. "(" .. container_info.ID .. ")"
      end,
    }, function(choice)
      if not choice then
        return
      end

      local source = ("container:%s"):format(choice.ID)
      local container_info = nio.process.run({
        cmd = remote_nvim.config.devpod.docker_binary,
        args = { "inspect", "--type", "container", choice.ID, "-f", "'{{ .Name }} {{ .Config.WorkingDir }}'" },
      })

      local name, working_dir =
        unpack(vim.split(container_info and container_info.stdout.read() or "", "%s+", { trimempty = true }))
      name = name:gsub("^/", "")

      remote_nvim.session_provider
        :get_or_initialize_session({
          host = name,
          conn_opts = { "--source", source },
          provider_type = "devpod",
          unique_host_id = choice.ID,
          devpod = {
            provider = "docker",
            working_dir = working_dir,
          },
        })
        :launch_neovim()
    end)
  end)
end

local function docker_container_action()
  local docker_cmd_ls = { "container", "ls" }
  if remote_nvim.config.devpod.container_list == "all" then
    table.insert(docker_cmd_ls, "--all")
  end
  table.insert(docker_cmd_ls, "--format")
  table.insert(docker_cmd_ls, "json")

  local container_list = nio.process.run({
    cmd = remote_nvim.config.devpod.docker_binary,
    args = docker_cmd_ls,
  })
  show_container_list(vim.split(container_list and container_list.stdout.read() or "", "\n", { trimempty = true }))
end

return {
  name = "Remote Docker: Attach to running container",
  value = "remote-docker-attach-container",
  action = docker_container_action,
  priority = 70,
  help = [[
## Description

Attach to one of the already running containers. Through plugin configuration, it is also possible to start a stopped container and attach to it.
]],
}
