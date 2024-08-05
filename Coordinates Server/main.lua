local Connection = require("Connection")
local event = require("event")
local serialization = require("serialization")
local comp = require("component")

local connection = Connection.new()
local debug = comp.debug


while true do
    local _, _, _, _, _, remoteID, header = event.pull("modem_message")

    local x, y, z = debug.getPlayer(header).getPosition()

    local location = {
        name = header,
        x = x,
        y = y,
        z = z
    }
    connection:send(remoteID, "location", serialization.serialize(location))

    print("Location sent to " .. remoteID .. " - " .. header .. ": " .. x .. ", " .. y .. ", " .. z)
end