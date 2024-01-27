local function gen_choices()
  local choices = {}

  local curr_path = vim.fs.dirname(debug.getinfo(1).source:sub(2))
  assert(curr_path ~= nil, "File path to the current file should not be nil")

  local files = vim.fs.find(function(name, _)
    return name ~= "init.lua"
  end, {
    type = "file",
    limit = math.huge,
    path = curr_path,
  })

  local base_path
  for dir in vim.fs.parents(curr_path) do
    if vim.fs.basename(dir) == "lua" then
      base_path = vim.fs.normalize(dir)
      break
    end
  end

  for _, filename in ipairs(files) do
    filename = filename:sub(#base_path + 2, -5)
    table.insert(choices, require(filename))
  end

  return choices
end

return function()
  local choices = gen_choices()
  if not require("remote-nvim.providers.devpod.devpod_helper").get_devcontainer_root() then
    choices = vim.tbl_filter(function(entry)
      return entry.value ~= "devpod-launch-devcontainer"
    end, choices)
  end

  if #vim.tbl_keys(require("remote-nvim").session_provider:get_saved_host_configs()) == 0 then
    choices = vim.tbl_filter(function(entry)
      return entry.value ~= "remote-nvim-known-workspace"
    end, choices)
  end

  table.sort(choices, function(a, b)
    return a.priority > b.priority
  end)

  return choices
end
