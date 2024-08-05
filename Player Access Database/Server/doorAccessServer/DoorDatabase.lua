serialization = require("serialization")
component = require("component")
term = require("term")
door = require("door")

DoorDatabase = {data}

function DoorDatabase:new(o)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.data = {}
    return o
end

function DoorDatabase:add(newDoor)
    table.insert(self.data, newDoor)
end

function DoorDatabase:save(file)
    local saveFile = io.open(file, "w")
    saveFile:write(serialization.serialize(self.data))
    saveFile:close()
end

function DoorDatabase:load(file)
    local saveFile = io.open(file, "r")
    local entireFile = saveFile:read()
    saveFile:close()
    self.data = serialization.unserialize(entireFile)
end

function DoorDatabase:findByCurrentMedia(addr)
    for i, v in pairs(self.data) do
        if addr == component.invoke(v.driveAddr, "media") then
            return self.data[i]
        end
    end
    term.write(addr.." not recognised\n")
end

function DoorDatabase:findByLastMedia(addr)
    for i, v in pairs(self.data) do
        if v.lastMedia ~= nil and addr == v.lastMedia then
            return self.data[i]
        end
    end
    term.write(addr.." not recognised\n")
end

function DoorDatabase:remove(name)
    for i, v in pairs(self.data) do
        if v.name == name then
            table.remove(self.data, i)
            term.write("removed\n")
        end
    end
end

function DoorDatabase:drop()
    self.data = {}
end

return DoorDatabase