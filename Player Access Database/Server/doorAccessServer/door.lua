term = require("term")
event = require("event")

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

function door.setRed(door, value)
    component.invoke(door.redAddr, "setOutput", {value, value, value, value, value, value})
end

function door:print()
    term.write("name: "..self.name.."\naccess: "..self.access.."\nredAddr: "..self.redAddr.."\ndriveAddr: "..self.driveAddr.."\n")
end

return door