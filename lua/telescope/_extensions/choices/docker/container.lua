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
      require("remote-nvim.utils").run_cmd(remote_nvim.config.devpod.docker_binary, {
        "inspect",
        "--type",
        "container",
        choice.ID,
        "-f",
        '{"name": "{{ .Name }}", "working_dir": "{{ .Config.WorkingDir }}"}',
      }, function(stdout)
        local container_info = vim.json.decode(stdout[1])
        local name = container_info.name:gsub("^/", "")

        vim.schedule(function()
          remote_nvim.session_provider
            :get_or_initialize_session({
              host = name,
              conn_opts = { "--source", source },
              provider_type = "devpod",
              unique_host_id = choice.ID,
              devpod_opts = {
                provider = "docker",
                working_dir = container_info.working_dir,
                source_opts = {
                  type = "container",
                  name = name,
                  id = choice.ID,
                },
              },
            })
            :launch_neovim()
        end)
      end)
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

  require("remote-nvim.utils").run_cmd(remote_nvim.config.devpod.docker_binary, docker_cmd_ls, function(container_lst)
    if vim.tbl_isempty(container_lst) then
      vim.notify("No running containers discovered.")
    end
    show_container_list(container_lst)
  end)
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
