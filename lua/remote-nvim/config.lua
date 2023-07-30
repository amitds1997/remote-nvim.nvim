local utils = require("remote-nvim.utils")

local function create_file_if_not_exists(file_path)
  local file = io.open(file_path, "a")
  if file then
    file:close()
  end
end

local WorkspaceConfig = {}
WorkspaceConfig.__index = WorkspaceConfig

function WorkspaceConfig.new()
  local self = setmetatable({}, WorkspaceConfig)
  self.plugin_name = "remote-nvim.nvim"

  -- Create the plugin dir, if it does not exist
  local plugin_dir = utils.path_join(vim.fn.stdpath('data'), 'remote-nvim.nvim')
  if not vim.loop.fs_stat(plugin_dir) then
    local success, err = vim.loop.fs_mkdir(plugin_dir, 493) -- 493 is the permission mode for directories (0755 in octal)
    if not success then
      print("Failed to create directory:", err)
    end
  end

  self.file_path = utils.path_join(plugin_dir, 'workspace.json')
  create_file_if_not_exists(self.file_path)
  self.data = self:read_file() or {}
  return self
end

function WorkspaceConfig:read_file()
  local file = io.open(self.file_path, "r")
  if file then
    local content = file:read("*all")
    file:close()
    if content and content ~= "" then
      return vim.fn.json_decode(content)
    end
  end
  return nil
end

function WorkspaceConfig:write_file()
  local file = io.open(self.file_path, "w")
  if file then
    local content = vim.fn.json_encode(self.data)
    file:write(content)
    file:close()
    return true
  end
  return false
end

function WorkspaceConfig:get_workspace_config(host_id)
  if not self.data[host_id] then
    self.data[host_id] = {} -- Create a nested table for the host if it doesn't exist
  end

  -- Create a proxy table that synchronizes changes to the JSON file
  local proxy = setmetatable({}, {
    __index = self.data[host_id],
    __newindex = function(_, key, value)
      self.data[host_id][key] = value
      self:write_file()
    end,
  })

  return proxy
end

function WorkspaceConfig:delete_workspace(host_id)
  if self.data[host_id] then
    self.data[host_id] = nil
    self:write_file()
    return true
  end
  return false
end

function WorkspaceConfig:host_exists(host_id)
  return self.data[host_id] ~= nil
end

function WorkspaceConfig:workspace_exists(host_id)
  return self.data[host_id] ~= nil
end

function WorkspaceConfig:get_all_host_ids()
  local host_ids = {}
  for host_id in pairs(self.data) do
    table.insert(host_ids, host_id)
  end
  return host_ids
end

function WorkspaceConfig:add_host_config(host_id, new_config)
  if not self.data[host_id] then
    self.data[host_id] = new_config
    self:write_file()
    return true
  end
  return false
end

function WorkspaceConfig:print_workspace_config()
  print("Workspace Configuration:")
  for host_id, config in pairs(self.data) do
    print("Host ID:", host_id)
    for key, value in pairs(config) do
      print("  " .. key .. ":", value)
    end
    print()
  end
end

return WorkspaceConfig
