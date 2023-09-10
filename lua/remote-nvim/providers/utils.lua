local remote_neovim = require("remote-nvim")
local M = {}

---Get selection handling coroutines
---@param choices string[]
---@param selection_opts table
---@return string|nil selected_choice Selected choice
function M.get_selection(choices, selection_opts)
  local co = coroutine.running()
  local selection_made = false
  local selected_choice = nil

  vim.ui.select(choices, selection_opts, function(choice)
    selection_made = true
    selected_choice = choice
    if co then
      coroutine.resume(co)
    end
  end)

  if co and not selection_made then
    coroutine.yield()
  end
  return selected_choice
end

---Get Neovim versions that satisfy the minimum neovim version constraint
function M.get_neovim_versions()
  local res
  local co = coroutine.running()
  if co then
    require("plenary.curl").get("https://api.github.com/repos/neovim/neovim/releases", {
      headers = {
        accept = "application/vnd.github+json",
      },
      callback = function(out)
        res = out
        coroutine.resume(co)
      end,
    })
    coroutine.yield()
  else
    res = require("plenary.curl").get("https://api.github.com/repos/neovim/neovim/releases", {
      headers = {
        accept = "application/vnd.github+json",
      },
    })
  end

  local available_versions = { "stable" }
  for _, version_info in ipairs(vim.json.decode(res.body)) do
    local version = version_info["tag_name"]

    if version ~= "stable" and version ~= "nightly" then
      local major, minor, patch = version:match("v(%d+)%.(%d+)%.(%d+)")
      local target_major, target_minor, target_patch = remote_neovim.MIN_NEOVIM_VERSION:match("v(%d+)%.(%d+)%.(%d+)")

      major = tonumber(major)
      minor = tonumber(minor)
      patch = tonumber(patch)

      target_major = tonumber(target_major)
      target_minor = tonumber(target_minor)
      target_patch = tonumber(target_patch)

      if
        major > target_major
        or (major == target_major and minor > target_minor)
        or (major == target_major and minor == target_minor and patch >= target_patch)
      then
        table.insert(available_versions, version)
      end
    end
  end
  table.insert(available_versions, "nightly")
  return available_versions
end

---Run code in a coroutine
---@param fn function Function to run inside the coroutine
---@param err_fn? function Error handling function
function M.run_code_in_coroutine(fn, err_fn)
  local co = coroutine.create(fn)
  local success, err = coroutine.resume(co)
  if not success then
    if err_fn ~= nil then
      err_fn(err)
    else
      error("Coroutine failed with error " .. err)
    end
  end
end

---Get an ephemeral free port on the local machine
---@return string port A free ephemeral port available for TCP connections
function M.find_free_port()
  local socket = vim.loop.new_tcp()

  socket:bind("127.0.0.1", 0)
  local result = socket.getsockname(socket)
  socket:close()

  if not result then
    error("Failed to find a free port")
  end

  return tostring(result["port"])
end

return M
