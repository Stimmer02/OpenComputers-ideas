local RedstoneServer = require("RedstoneServer")
local SecureConnection = require("SecureConnection")

local connection = SecureConnection.new("./userDatabase.txt")
local server = RedstoneServer.new("./redstone.cfg", connection)

server:run()