local M = {}

---Get user input
---@param input_label string Label for the input box
---@param input_type prompt_type? What kind of value would be typed as input
---@return string response User response
function M.get_input(input_label, input_type)
  input_type = input_type or "plain"

  if input_type == "secret" then
    return vim.fn.inputsecret(input_label)
  else
    return vim.fn.input(input_label)
  end
end

---Get selection handling coroutines
---@param choices string[]
---@param selection_opts table
---@return string? selected_choice Selected choice
function M.get_selection(choices, selection_opts)
  local co = coroutine.running()
  local selection_made = false
  local selected_choice = nil

  vim.schedule(function()
    vim.ui.select(choices, selection_opts, function(choice)
      selection_made = true
      selected_choice = choice
      if co then
        coroutine.resume(co)
      end
    end)
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
      local target_major, target_minor, target_patch =
        require("remote-nvim.constants").MIN_NEOVIM_VERSION:match("v(%d+)%.(%d+)%.(%d+)")

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
