local io = require("io")

-- FORMAT:
-- index = name of with access
-- row = {index in a file, read, add, remove, modify(add privleges)}

local AccessDatabase = {}
AccessDatabase.__index = AccessDatabase

function AccessDatabase.new(databaseFile)
    local self = setmetatable({}, AccessDatabase)

    if databaseFile == nil then
        error("AccessDatabase.new: Missing required argument - databaseFile")
    end

    self.databaseFile = databaseFile
    self.data = {}
    self:load()
    self.changes = false

    self.queeryFunctionMap = {
        ["getRow"] = self.getRow,
        ["removeRow"] = self.removeRow,
        ["addRow"] = self.addRow,
        ["modifyRow"] = self.modifyRow,
    }

    return self
end

function AccessDatabase:load()
    local file = io.open(self.databaseFile, "r")
    if file == nil then
        error("AccessDatabase:load: Could not open file " .. self.databaseFile)
    end

    local stringToBoolMap = {
        ["true"] = true,
        ["True"] = true,
        ["TRUE"] = true,
        ["1"] = true,
        ["false"] = false,
        ["False"] = false,
        ["FALSE"] = false,
        ["0"] = false
    }

    self.data = {}
    self.changes = false

    local lineIndex = 1
    for line in file:lines() do
        local values = {}
        for value in line:gmatch("%S+") do
            table.insert(values, value)
        end
        if #values < 5 then
            error("AccessDatabase:load: Invalid number of values in line: " .. line)
        end
        -- values[1] - rowName
        local row = {}
        row[1] = lineIndex
        for i = 2, #values do
            row[i] = stringToBoolMap[values[i]]
            if row[i] == nil then
                error("AccessDatabase:load: Invalid value in line: " .. line)
            end
        end
        self.data[tonumber(values[1])] = row

        lineIndex = lineIndex + 1
    end

    file:close()
end

function AccessDatabase:save()
    if self.changes == false then
        return
    end

    local file = io.open(self.databaseFile, "w")
    if file == nil then
        error("AccessDatabase:save: Could not open file " .. self.databaseFile)
    end

    for key, value in pairs(self.data) do
        file:write(key .. " ")
        for i = 2, #value do
            file:write(tostring(value[i]) .. " ")
        end
        file:write("\n")
    end

    file:close()
    self.changes = false
end

function AccessDatabase:print()
    for key, value in pairs(self.data) do
        print(key, value[1], value[2], value[3], value[4], value[5])
    end
end

function AccessDatabase:isPresent(index)
    return self.data[index] ~= nil
end

local function canRead(self, ID)
    return self.data[ID] ~= nil and self.data[ID][1] == true
end

local function canAdd(self, ID)
    return self.data[ID] ~= nil and self.data[ID][2] == true
end

local function canRemove(self, ID)
    return self.data[ID] ~= nil and self.data[ID][3] == true
end

local function canModify(self, ID)
    return self.data[ID] ~= nil and self.data[ID][4] == true
end

function AccessDatabase:getRow(accessingID, rowID)
    if self:canRead(accessingID) then
        return nil
    end

    return self.data[rowID]
end

function AccessDatabase:removeRow(accessingID, rowID)
    if self:canRemove(accessingID) then
        return false
    end

    self.changes = true
    self.data[rowID] = nil
    return true
end

function AccessDatabase:addRow(accessingID, newRowID)
    if self:canAdd(accessingID) then
        return false
    end

    self.changes = true
    self.data[newRowID] = {nil, false, false, false, false}
    return true
end

function AccessDatabase:modifyRow(accessingID, rowID, position, value)
    if self:canModify(accessingID) then
        return false
    end

    self.changes = true
    self.data[rowID][position] = value
    return true
end

function AccessDatabase:handleQuerry(accessingID, querry)
    if self.queeryFunctionMap[querry[1]] == nil then
        return false
    end

    return self.queeryFunctionMap[querry](self, accessingID, select(2, table.unpack(querry)))
end

return AccessDatabase