local component = require("component")
local serial = require("serialization")

ProxyDMClient = {
    modem,
    addr,
    port,
}

function ProxyDMClient:new(o, modem, addr, port)
    local o = o or {}
    setmetatable(o, {__index = self})

    o.modem = modem
    o.addr = addr
    o.port = port
    return o
end

function ProxyDMClient:terminate()
    self.modem.send(self.addr, self.port, 0)
end

function ProxyDMClient:add(screenAddr)
    self.modem.send(self.addr, self.port, 1, screenAddr)
end

function ProxyDMClient:autoAdd()
    self.modem.send(self.addr, self.port, 2)
end

function ProxyDMClient:identify()
    self.modem.send(self.addr, self.port, 3)
end

function ProxyDMClient:doForAll(fun , args)
    self.modem.send(self.addr, self.port, 4, fun, serial.serialize(args))
end

function ProxyDMClient:doMultipleForAll(funTable, argsTable)
    self.modem.send(self.addr, self.port, 5, serial.serialize(funTable), serial.serialize(argsTable))
end

function ProxyDMClient:changeDisplay(displayIndex)
    self.modem.send(self.addr, self.port, 6, displayIndex)
end

function ProxyDMClient:resetResolution()
    self.modem.send(self.addr, self.port, 7)
end

function ProxyDMClient:reset(clearAll)
    self.modem.send(self.addr, self.port, 8, clearAll)
end

function ProxyDMClient:exec(fun , args)
    self.modem.send(self.addr, self.port, 9, fun, serial.serialize(args))
end
