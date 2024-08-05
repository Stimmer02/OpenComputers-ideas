local RedstoneManager = require("RedstoneManager")
local serialization = require("serialization")

local RedstoneServer = {}
RedstoneServer.__index = RedstoneServer
function RedstoneServer.new(configFilePath, connection)
    local self = setmetatable({}, RedstoneServer)
    self.redstoneManager = RedstoneManager.new(configFilePath)
    self.connection = connection
    self.running = false
    self.operationMap = {
        ["RS-getDeviceTable"] = self.getDeviceTable,
        ["RS-setDeviceState"] = self.setDeviceState,
        ["RS-setAllDevices"] = self.setAllDevices
    }
    return self
end

function RedstoneServer:getDeviceTable(message)
    local deviceTable = self.redstoneManager:getDeviceTable()
    self.connection:send(message.originID, "RS-getResponse", serialization.serialize(deviceTable))
end

function RedstoneServer:setDeviceState(message)
    if not self.redstoneManager:deviceExists(message.data[1]) then
        self.connection:send(message.originID, "RS-done", false)
    end
    local device = self.redstoneManager.devices[message.data[1]]
    device:setState(message.data[2])
    self.connection:send(message.originID, "RS-done", true)
end

function RedstoneServer:setAllDevices(message)
    local ignore = serialization.unserialize(message.data[2])
    local maxTime = self.redstoneManager:getMaxOperatingTime(ignore)
    self.connection:send(message.originID, "RS-setResponse", maxTime)
    self.redstoneManager:setAllDevices(message.data[1], ignore)
    self.connection:send(message.originID, "RS-done")
end

function RedstoneServer:run()
    self.running = true
    while self.running do
        self.running = self.connection:handleMessage(nil, self.operationMap, self)
    end
end

-- function RedstoneServer:stop()
--     self.running = false
-- end

return RedstoneServer