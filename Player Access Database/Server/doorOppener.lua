event = require("event")
component = require("component")
term = require("term")
thread = require("thread")
text = require("text")
serialization = require("serialization")

door = {
    name,
    access,
    redAddr,
    driveAddr,
    lastMedia
}

function door:new(o, name, access ,redAddr, driveAddr)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.name = name
    o.access = access
    o.redAddr = redAddr
    o.driveAddr = driveAddr
    o.lastMedia = nil
    return o;
end

function door:detect()
    local _, addr1, name1 = event.pull(nil, "component_added")
    local _, addr2 = event.pull(nil, "component_added")

    if name1 == "disk_drive" then
        self.driveAddr = addr1
        self.redAddr = addr2
    else
        self.driveAddr = addr2
        self.redAddr = addr1
    end
end

function door:print()
    term.write("name: "..self.name.."\naccess: "..self.access.."\nredAddr: "..self.redAddr.."\ndriveAddr: "..self.driveAddr.."\n")
end

DATABASE = {data}

function DATABASE:new(o)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.data = {}
    return o
end

function DATABASE:add(newDoor)
    table.insert(self.data, newDoor)
end

function DATABASE:save(file)
    local saveFile = io.open(file, "w")
    saveFile:write(serialization.serialize(self.data))
    saveFile:close()
end

function DATABASE:load(file)
    local saveFile = io.open(file, "r")
    local entireFile = saveFile:read()
    saveFile:close()
    self.data = serialization.unserialize(entireFile)
end

function DATABASE:openByContainingMedia(addr)
    for _, v in pairs(self.data) do
        if addr == component.invoke(v.driveAddr, "media") then
            component.invoke(v.redAddr, "setOutput", 1, 15)
            v.lastMedia = addr
            return
        end
    end
    term.write(addr.." not recognised")
end

function DATABASE:closeBylastMedia(addr)
    for _, v in pairs(self.data) do
        if v.lastMedia ~= nil and addr == v.lastMedia then
            v.lastMedia = nil
            component.invoke(v.redAddr, "setOutput", 1, 0)
            return
        else
            term.write(addr.." not recognised\n")
        end
    end
end

function DATABASE:delete(name)
    for i, v in pairs(self.data) do
        if v.name == name then
            table.remove(self.data, i)
            term.write("removed\n")
        end
    end
end

pendingOperation = {
    open,
    mediaAddr,
}

function pendingOperation:new(o, open, mediaAddr)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.open = open
    o.mediaAddr = mediaAddr
    return o
end

function pendingOperation:execute(system, database)
    if open then
        database:findDoorwayContaining(self.mediaAddr)
    else
        database:findDoorwayContained(self.mediaAddr)
    end
end

DB = DATABASE:new(nil)
local runServer = true

function userInput ()
    while runServer do
        term.write(">")
        local userIn = term.read()
        if userIn == "exit\n" then
            runServer = false
            term.write("exiting...\n")
        elseif userIn == "add\n" then
            term.write("name: ")
            local name = term.read()
            term.write("access: ")
            local access = term.read()
            local newDoor = door:new(nil, text.trim(name), text.trim(access))
            term.write("detecting...\n")
            newDoor:detect()
            DB:add(newDoor)
            term.write("added:\n")
            newDoor:print()
        elseif userIn == "delete\n" then
            term.write("name: ")
            local name = term.read()
            DB:delete(text.trim(name))
        elseif userIn == "save\n" then
            DB:save("DB.txt")
            term.write("saved\n")
        end
    end
end

function server ()
    while runServer do
        local eventName, addr = event.pull(nil, "component")
        if eventName == "component_added" then
            DB:openByContainingMedia(addr)
        elseif eventName == "component_removed" then
            DB:closeBylastMedia(addr)
        end
    end
end

DB:load("DB.txt")
serv = thread.create(server)
term.write("active\n")
userInput()
serv:kill()