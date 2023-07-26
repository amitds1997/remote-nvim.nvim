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

return M
