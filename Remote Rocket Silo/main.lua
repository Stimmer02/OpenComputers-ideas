local SecureConnection = require("SecureConnection")
local SiloAray = require("SiloArray")
local SiloArrayServer = require("SiloArrayServer")

local siloArray = SiloAray.new("siloDatabase.txt")
local connection = SecureConnection.new("userDatabase.txt")
local server = SiloArrayServer.new(siloArray, connection)

server:registerDefaultSalvoFunctions()

server:printGreetings()
server:run()