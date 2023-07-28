M = {}

function M.find_binary(binary)
  if type(binary) == "string" and vim.fn.executable(binary) == 1 then
    return binary
  elseif type(binary) == "table" and vim.fn.executable(binary[1]) then
    return vim.deepcopy(binary)
  end
  return nil
end

function M.merge_tables(t1, t2)
  local merged_table = {}

  for key, value in pairs(t1) do
    merged_table[key] = value
  end

  -- Append values from t2 into t1 only if key not already in t1
  for key, value in pairs(t2) do
    if merged_table[key] == nil then
      merged_table[key] = value
    end
  end

  return merged_table
end

function M.path_join(...)
  local parts = { ... }
  return table.concat(parts, vim.loop.os_uname().sysname == "Windows" and "\\" or "/")
end

function M.get_package_root()
  local root_dir
  for dir in vim.fs.parents(debug.getinfo(1).source:sub(2)) do
    if vim.fn.isdirectory(M.path_join(dir, "lua", "remote-nvim-ssh")) == 1 then
      root_dir = dir
    end
  end
  return root_dir
end

function M.generate_random_string(length)
    local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    math.randomseed(os.time()) -- Seed the random number generator with the current time
    local random_string = ""

    for _ = 1, length do
        local rand_index = math.random(1, #charset)
        random_string = random_string .. string.sub(charset, rand_index, rand_index)
    end

    return random_string
end


return M
