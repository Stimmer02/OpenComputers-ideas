local RedstoneDevice = require("RedstoneDevice")

local RedstoneManager = {}
RedstoneManager.__index = RedstoneManager
function RedstoneManager.new(configFilePath)
    local self = setmetatable({}, RedstoneManager)
    self.configFilePath = configFilePath
    self.devices = {}

    self:loadConfig()
    return self
end

function RedstoneManager:loadConfig()
    local file = io.open(self.configFilePath, "r")
    if file then
        local i = 1
        for line in file:lines() do
            if line.sub(line, 1, 1) == "#" then
                goto continue
            end
            local deviceName, address, negate, time = line:match("([^=,]+)=([^=,]+),([01]),([0123456789]+)")
            if deviceName and address then
                deviceName = deviceName:upper():gsub("_", " ")
                self.devices[deviceName] = RedstoneDevice.new(address, negate, time)
                if self.devices[deviceName] == nil then
                    print("Failed to load device:" .. deviceName .. " " .. address)
                end
                self.devices[deviceName].number = i
                i = i + 1
            end
            ::continue::
        end
        file:close()
    end
end

function RedstoneManager:deviceExists(deviceName)
    return self.devices[deviceName] ~= nil
end

function RedstoneManager:setDeviceState(deviceName, state)
    local device = self.devices[deviceName]
    if device == nil then
        return false
    end
    device:setState(state)
end

function RedstoneManager:getDeviceTable()
    local deviceTable = {}
    for deviceName, device in pairs(self.devices) do
        deviceTable[device.number] = {name = deviceName, state = device:getState(), time = device.time}
    end
    return deviceTable
end

function RedstoneManager:setAllDevices(state, ignore)
    ignore = ignore or {}
    for deviceName, device in pairs(self.devices) do
        if ignore[deviceName] == nil then
            device:setState(state)
        end
    end
end

function RedstoneManager:getMaxOperatingTime(ignore)
    ignore = ignore or {}
    local sum = 0
    for deviceName, device in pairs(self.devices) do
        if ignore[deviceName] == nil then
            sum = sum + device.time
        end
    end
    return sum
end

return RedstoneManager