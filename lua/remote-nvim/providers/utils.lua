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
---@return table<string, string>[] valid_neovim_versions Valid Neovim versions supported by the plugin
function M.get_valid_neovim_versions()
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
  local resp = vim.json.decode(res.body)

  local valid_versions = {}
  local nightly_commit_id = ""
  table.insert(valid_versions, { tag = "stable" })
  for _, version in ipairs(resp) do
    local version_name = version["tag_name"]

    if not vim.tbl_contains({ "stable", "nightly" }, version_name) then
      table.insert(valid_versions, { tag = version_name, commit = version["target_commitish"] })
    elseif version_name == "nightly" then
      nightly_commit_id = version["target_commitish"]
    elseif version_name == "stable" then
      valid_versions[1].commit = version["target_commitish"]
    end
  end
  table.insert(valid_versions, { tag = "nightly", commit = nightly_commit_id })

  return valid_versions
end

---Get an ephemeral free port on the local machine
---@return string port A free ephemeral port available for TCP connections
function M.find_free_port()
  local socket = require("remote-nvim.utils").uv.new_tcp()

  socket:bind("127.0.0.1", 0)
  local result = socket.getsockname(socket)
  socket:close()

  if not result then
    error("Failed to find a free port")
  end

  return tostring(result["port"])
end

function M.is_greater_neovim_version(version1, version2)
  -- Order would be as follows
  -- 1. Stable
  -- 2. Any recognized Neovim version of format vX.Y.Z
  -- 3. Nightly
  local specialVersions = { ["nightly"] = 1, ["stable"] = 2 }

  if specialVersions[version1] then
    if specialVersions[version2] then
      return specialVersions[version1] > specialVersions[version2]
    else
      return version1 == "stable"
    end
  elseif specialVersions[version2] then
    return version2 ~= "stable"
  else
    local pattern = "v(%d+)%.(%d+)%.(%d+)"

    local major1, minor1, patch1 = version1:match(pattern)
    local major2, minor2, patch2 = version2:match(pattern)

    major1, minor1, patch1 = tonumber(major1), tonumber(minor1), tonumber(patch1)
    major2, minor2, patch2 = tonumber(major2), tonumber(minor2), tonumber(patch2)

    assert(patch1 ~= nil, ("Invalid version passed '%s'"):format(version1))
    assert(patch2 ~= nil, ("Invalid version passed '%s'"):format(version2))

    if major1 == major2 then
      if minor1 == minor2 then
        return patch1 > patch2
      else
        return minor1 > minor2
      end
    else
      return major1 > major2
    end
  end
end

---@param os os_type OS name
---@param version string Release version
function M.get_offline_neovim_release_name(os, version)
  if os == "Linux" then
    return ("nvim-%s-linux.appimage"):format(version)
  elseif os == "macOS" then
    return ("nvim-%s-macos.tar.gz"):format(version)
  else
    error(("Unsupported OS: %s"):format(os))
  end
end

---@param kernel_name os_type Name of the kernel
---@param arch string Arch platforms
function M.is_binary_release_available(kernel_name, arch)
  if kernel_name == "macOS" or kernel_name == "Windows" then
    return true
  end

  local unsupported_archs = { "arm", "risc" }

  -- Neovim currently does not provide binaries for ARM or RISC
  return (
    kernel_name == "Linux"
    and vim.tbl_isempty(vim.tbl_filter(function(unsupported_arch)
      return string.find(arch, unsupported_arch) ~= nil
    end, unsupported_archs))
  )
end

return M
