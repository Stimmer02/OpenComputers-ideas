event = require("event")
component = require("component")
serialization = require("serialization")
term = require("term")
thread = require("thread")
text = require("text")

function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


user = {
    name,
    passwd,
    access
}

function user:new(o, name, passwd, access)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.passwd = passwd--[[component.data.md5(passwd)]]
    o.name = name
    o.access = shallowcopy(access)
    return o
end

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
--     print(count)
    if count == nil then
        return
    end
    for i = 1, count do
        table.insert(self.data, serialization.unserialize(saveFile:read()))
--         print(self.data[i].passwd)
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
--     print(user.passwd, passwd)
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



UserDatabaseServer = {
    port,
    running,
    modem,
    threads,
    ports,
    UD
}

function UserDatabaseServer:new(o, port, modem)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.port = port
    o.running = false
    o.modem = modem
    o.requests = {}
    o.threads = {}
    o.UD = UserDatabase:new(nil)
    return o
end


function UserDatabaseServer:start()
    self.modem.open(self.port)
    self.running = true
    local managerInterfeaceThread = thread.create(self.threadErrorHandler, self, self.managerInterface)
    while self.running do
        local _, _, remoteAddr, port, _, message1, message2, message3, message4 = event.pull("modem_message")
        if m1 == 0 then
            self:stop()
        else
--             print("request", message1, message2, message3, message4)
            table.insert(self.requests, thread.create(self.threadErrorHandler, self, self.executeRequest, message1, message2, message3, message4, remoteAddr))
        end
    end
    self.modem.close(self.port)
    managerInterfeaceThread:kill()
end

function UserDatabaseServer:stop()
    self.running = false
    for i, v in pairs(self.threads) do
        self.requests[i]:join()
    end
end

function UserDatabaseServer:executeRequest(message1, message2, message3, message4, addr)
    if message1 == 1 then
--         print("exec", message1, message2, message3, message4, addr)
        local access = self.UD:checkCredentials(message2, message3, message4)
        self.modem.send(addr, self.port, access)
    end
end

function UserDatabaseServer:threadErrorHandler(fun, message1, message2, message3, message4, addr)
    local status, err = xpcall(fun, debug.traceback, self, message1, message2, message3, message4, addr)
    if status == false then
        term.write(err)
        term.write("\n")
    end
end



Command = {
    keyword,
    func
}

function Command:new(o, keyword, func)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.keyword = keyword
    o.func = func
    return o
end

function Command:exec(args, object)
    if self.keyword == args[1] then
        self.func(args, object)
        return true
    else
        return false
    end
end

UserInterface = {
    commands,
    object
}

function UserInterface:new(o, object)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.object = object
    o.commands = {}
    return o
end

function UserInterface:add(command)
    table.insert(self.commands, command)
end

function UserInterface:resolveInput(userInput)
    tokenizedInput = text.tokenize(userInput)
    for _,v in pairs(self.commands) do
        if v:exec(tokenizedInput, self.object) then
            return true
        end
    end
    return false
end



function UI_exit(args, userDatabaseServer)
    term.write("exiting...\n")
    userDatabaseServer:stop()
end
function UI_addUser(args, userDatabaseServer)
    if #args < 3 then
        return
    end
    userDatabaseServer.UD:add(user:new(nil, text.trim(args[2]), text.trim(args[3]), userDatabaseServer.UD.emptyAccessMap))
    term.write("added\n")
end
function UI_userAccess(args, userDatabaseServer)
    if #args < 4 then
        return
    end
    local user = userDatabaseServer.UD:get(args[2])
    if user ~= nil then
        if args[3] == "add" then
            for i = 4, #args do
                user.access[args[i]] = true
            end
        elseif args[3] == "remove" then
            for i = 4, #args do
                user.access[args[i]] = false
            end
        else
            term.write("unrecognized: "..args[3].."\n")
            return
        end
    else
        term.write("no user named: "..name.."\n")
        return
    end
    term.write("added\n")
end
function UI_addAccess(args, userDatabaseServer)
    if #args < 2 then
        return
    end
    userDatabaseServer.UD.emptyAccessMap[args[2]] = false
    term.write("added\n")
end
function UI_removeUser(args, userDatabaseServer)
    if #args < 2 then
        return
    end
    userDatabaseServer.UD:delete(args[2])
end
function UI_save(args, userDatabaseServer)
    userDatabaseServer.UD:save("UD.txt")
    term.write("saved\n")
end
function UI_dropUserTable(args, userDatabaseServer)
    userDatabaseServer.UD:userDrop()
    term.write("all users dropped\n")
end
function UI_dropAccessTable(args, userDatabaseServer)
    userDatabaseServer.UD:accessDrop()
    term.write("all access dropped\n")
end


function UserDatabaseServer:managerInterface()
    local userInterface = UserInterface:new(nil, self)
    userInterface:add(Command:new(nil, "exit", UI_exit))
    userInterface:add(Command:new(nil, "uAdd", UI_addUser))
    userInterface:add(Command:new(nil, "uAccess", UI_userAccess))
    userInterface:add(Command:new(nil, "aAdd", UI_addAccess))
    userInterface:add(Command:new(nil, "uRemove", UI_removeUser))
    userInterface:add(Command:new(nil, "save", UI_save))
    userInterface:add(Command:new(nil, "uDrop", UI_dropUserTable))
    userInterface:add(Command:new(nil, "aDrop", UI_dropAccessTable))

    while self.running do
        term.write("\n> ")
        local userIn = term.read()
        if userInterface:resolveInput(userIn) == false then
             term.write("unrecognized command: "..userIn)
        end
    end
end



local UD = UserDatabaseServer:new(nil, 1, component.modem)
UD.UD:load("UD.txt")
UD:start()