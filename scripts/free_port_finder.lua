local socket = vim.loop.new_tcp()

socket:bind("127.0.0.1", 0)
local success = socket.getsockname(socket)
if success then
  print(vim.inspect(success["port"]))
else
  print("Error getting socket name:", port_or_err)
end

socket:close()
