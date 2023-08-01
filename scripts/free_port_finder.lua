local socket = vim.loop.new_tcp()

socket:bind("127.0.0.1", 0)
local result = socket.getsockname(socket)
socket:close()

if result then
  print(result["port"])
end
