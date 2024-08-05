local SiloArray = require("SiloArray")
local SecureConnection = require("SecureConnection")

local SiloArrayServer = {}
SiloArrayServer.__index = SiloArrayServer

function SiloArrayServer.new(siloArray, secureConnection)
    if siloArray == nil then
        error("SiloArray cannot be nil")
    end
    if secureConnection == nil then
        error("SecureConnection cannot be nil")
    end

    local self = setmetatable({}, SiloArrayServer)
    self.siloArray = siloArray
    self.connection = secureConnection

    return self
end