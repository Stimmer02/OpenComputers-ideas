local comp = require("component")
local event = require("event")

local Connection = {}
Connection.__index = Connection

function Connection.new(tunnel)
    local self = setmetatable({}, Connection)
    self.id = nil

    if tunnel then
        if tunnel.type == "string" then
            self.tunnel = comp.proxy(tunnel)
        else
            self.tunnel = tunnel
        end
    else
        for addr, name in comp.list() do
            if name == "tunnel" then
                self.tunnel = comp.proxy(addr)
                break
            end
        end
    end

    if self.tunnel == nil then
        error("No modem found")
    end

    self:registerID()
    
    return self
end

function Connection:registerID()
    self.tunnel.send("connection-id-info", self.tunnel:getChannel())
    local eventType, _, _, _, _, _, id = event.pullFiltered(5, function(eventType, _, _, _, _, header, _)
        return header == "junction-id-response" and eventType == "modem_message"
    end)

    if eventType == nil then
        error("No ID received")
    end

    self.id = id
end

function Connection:send(targetID, ...)
    self.tunnel.send("connection-send", targetID, self.id, ...)
end

return Connection