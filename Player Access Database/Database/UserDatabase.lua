component = require("component")
serialization = require("serialization")

UserDatabase = {
    emptyAccessMap,
    data
}

function UserDatabase:new(o)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.emptyAccessMap = {}
    o.data = {}
    return o
end

function UserDatabase:add(newUser)
    table.insert(self.data, newUser)
end

function UserDatabase:save(file)
    local saveFile = io.open(file, "wb")
    saveFile:write(serialization.serialize(#self.data).."\n")
    saveFile:write(serialization.serialize(self.emptyAccessMap).."\n")
    for i, v in pairs(self.data) do
        saveFile:write(serialization.serialize(v).."\n")
    end
    saveFile:close()
end

function UserDatabase:load(file)
    local saveFile = io.open(file, "rb")
    local count = tonumber(serialization.unserialize(saveFile:read() or "0"))
    self.emptyAccessMap = serialization.unserialize(saveFile:read() or "{}") or {}
    print(count)
    if count == nil then
        return
    end
    for i = 1, count do
        table.insert(self.data, serialization.unserialize(saveFile:read()))
        print(self.data[i].passwd)
    end
    saveFile:close()
end

function UserDatabase:get(name)
    for i, v in pairs(self.data) do
        if v.name == name then
            return v
        end
    end
    return nil
end

function UserDatabase:checkCredentials(name, passwd, access)
    local user = self:get(name)
    print(user.passwd, passwd)
    if user ~= nil and user.passwd == passwd then
        return user.access[access] or false
    end
    return false
end

function UserDatabase:remove(name)
    for i, v in pairs(self.data) do
        if v.name == name then
            table.remove(self.data, i)
        end
    end
end

function UserDatabase:userDrop()
    self.data = {}
end

function UserDatabase:accessDrop()
    self.emptyAccessMap = {}
end

function UserDatabase:createKey(userName)
    local user = self:get(userName)
    if userName == nil then
        return
    end
    local media = component.disk_drive.media()
    local mediaSub = string.sub(media, 1, 3)
    local file = io.open("/mnt/"..mediaSub.."/USERDATA", "wb")
    file:write(serialization.serialize(user.name).."\n")
    file:write(serialization.serialize(user.passwd).."\n")

    file:close()
end


return UserDatabase