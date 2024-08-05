local component = require("component")
local DisplayManager = require("DisplayManager")
local event = require("event")
local term = require("term")
local serial = require("serialization")


proxyDMServer = {
    modem,
    port,
    dm,
}

function proxyDMServer:new(o, modem, port)
    local o = o or {}
    setmetatable(o, {__index = self})

    o.modem = modem
    o.port = port
    o.dm = DisplayManager:new()
    return o
end

function proxyDMServer:start()

    proxyDMServerFunctionMap = {}
    proxyDMServerFunctionMap["term.clear"] = term.clear
    proxyDMServerFunctionMap["gpu.setResolution"] = self.dm.gpu.setResolution
    proxyDMServerFunctionMap["term.write"] = term.write
    proxyDMServerFunctionMap["os.sleep"] = os.sleep

    self.modem.open(self.port)
    local m1, m2, m3
    while m1 ~= 0 do
        _, _, _, _, _, m1, m2, m3 = event.pull("modem_message")
--         print(tostring(m1), tostring(m2), tostring(m3))
        if m1 == 1 then
            self.dm:add(m2)
        elseif m1 == 2 then
            self.dm:autoAdd()
        elseif m1 == 3 then
            self.dm:identify()
        elseif m1 == 4 then
            self.dm:doForAll(proxyDMServerFunctionMap[m2], serial.unserialize(m3))
        elseif m1 == 5 then
            self.dm:doMultipleForAll()
        elseif m1 == 6 then
            self.dm:changeDisplay(m2)
        elseif m1 == 7 then
            self.dm:resetResolution(m2)
        elseif m1 == 8 then
            self.dm:reset(m2)
        elseif m1 == 9 then
            proxyDMServerFunctionMap[m2](table.unpack(serial.unserialize(m3)))
        elseif m1 == 10 then
            proxyDMServerFunctionMap[m2]()
        end
    end

    self.modem.close(self.port)
end