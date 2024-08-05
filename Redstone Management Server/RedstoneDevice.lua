local component = require("component")
local thread = require("thread")

local RedstoneDevice = {}
RedstoneDevice.__index = RedstoneDevice
function RedstoneDevice.new(deviceAddress, negate, time)
    local self = setmetatable({}, RedstoneDevice)

    local device = component.proxy(deviceAddress)
    if device == nil or device.type ~= "redstone" then
        return nil
    end

    self.address = deviceAddress
    self.device = device
    self.negate = (negate == "1")
    self.state = (device.getOutput(1) ~= 0)
    self.time = tonumber(time)
    self.waitingThread = nil
    self.operating = false

    return self
end

function RedstoneDevice:waitingThreadFunction()
    self.operating = true
---@diagnostic disable-next-line: undefined-field
    os.sleep(self.time)
    self.operating = false
end

function RedstoneDevice:setState(state)
    if component.proxy(self.address) == nil then -- could be expensive but it is safer
        return
    end
    state = state ~= self.negate
    if state == self.state then
        return
    end
    if self.operating then
        self.waitingThread:join()
    end

    if state then
        self.device.setOutput({15, 15, 15, 15, 15, 15})
    else
        self.device.setOutput({0, 0, 0, 0, 0, 0})
    end
    self.state = state
    self.waitingThread = thread.create(self.waitingThreadFunction, self)
end

function RedstoneDevice:getState()
    return self.state ~= self.negate
end

return RedstoneDevice