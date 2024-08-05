local Connection = require("Connection")
local AccessDatabase = require("AccessDatabase")

local event = require("event")

-- Uses a database of authorized connection IDs
-- has indexed whitelist of operations that won't be rejected (filter)
-- (optional) has a whitelists of operations allowed for each connection ID
-- every connection ID has a set of flags detemining the acces to the database: {read, add, remove, modify}

local SecureConnection = setmetatable({}, {__index = Connection})
SecureConnection.__index = SecureConnection

---@diagnostic disable-next-line: duplicate-set-field
function SecureConnection.new(databaseFile, tunnel)
    local self = Connection.new(tunnel)
    setmetatable(self, SecureConnection)

    self.database = AccessDatabase.new(databaseFile)

    return self
end

local function createPacket(incomingData)
    local out = {}
    out.originID = incomingData[6]
    out.header = incomingData[7]
    out.data = {}
    for i = 8, #incomingData do
        table.insert(out.data, incomingData[i])
    end

    return out
end

function SecureConnection:getMessage(timeout, messageHeader)
    local fullEvent = {event.pullFiltered(timeout, function(eventType, _, _, _, _, remoteID, header)
        return (eventType == "modem_message" and self.database:isPresent(remoteID) and (messageHeader == nil or header == messageHeader)) or eventType == "interrupted"
    end)}

    if fullEvent[1] == "interrupted" then
        return nil
    end
    return createPacket(fullEvent)
end

function SecureConnection:getMessageFrom(timeout, originID, messageHeader)
    local fullEvent = {event.pullFiltered(timeout, function(eventType, _, _, _, _, remoteID, header)
        return (eventType == "modem_message" and remoteID == originID and (messageHeader == nil or header == messageHeader)) or eventType == "interrupted"
    end)}

    if fullEvent[1] == "interrupted" or fullEvent[1] == nil then
        return nil
    end
    return createPacket(fullEvent)
end

function SecureConnection:handleMessage(timeout, headerToActionMap, ...)
    local fullEvent = {event.pullFiltered(timeout, function(eventType, _, _, _, _, remoteID, header)
        return (eventType == "modem_message" and self.database:isPresent(remoteID) and headerToActionMap[header] ~= nil) or eventType == "interrupted"
    end)}
    if fullEvent[1] == "interrupted" or fullEvent[1] == nil then
        return false
    end
    headerToActionMap[fullEvent[7]](..., createPacket(fullEvent))
    return true
end

function SecureConnection:waitForMessageAndHandleDatabaseQuerries()
    while true do
        local message = self:getMessage()

        if message == nil then
            return nil
        end

        if message.header == "DB" then
            local dbReturn = self.database:handleQuerry(message.originID, message.data)
            self:sendMessage(message.originID, "DB-R", dbReturn)
        else
            return message
        end
    end
end

-- UNTESTED
function SecureConnection:remoteDB_getRow(tergetID, rowName)
    self:sendMessage(tergetID, "DB", "getRow", rowName)
    local message = self:getMessageFrom(5, tergetID, "DB-R")
    if message == nil then
        return nil
    end

    return message.data
end

-- UNTESTED
function SecureConnection:remoteDB_removeRow(tergetID, rowName)
    self:sendMessage(tergetID, "DB", "removeRow", rowName)
    local message = self:getMessageFrom(5, tergetID, "DB-R")
    if message == nil then
        return nil
    end

    return message.data
end

-- UNTESTED
function SecureConnection:remoteDB_addRow(tergetID, rowName)
    self:sendMessage(tergetID, "DB", "addRow", rowName)
    local message = self:getMessageFrom(5, tergetID, "DB-R")
    if message == nil then
        return nil
    end

    return message.data
end

-- UNTESTED
function SecureConnection:remoteDB_modifyRow(tergetID, rowName, position, value)
    self:sendMessage(tergetID, "DB", "modifyRow", rowName, position, value)
    local message = self:getMessageFrom(5, tergetID, "DB-R")
    if message == nil then
        return nil
    end

    return message.data
end

return SecureConnection
