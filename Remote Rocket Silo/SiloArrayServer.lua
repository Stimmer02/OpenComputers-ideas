local SiloArray = require("SiloArray")
local SecureConnection = require("SecureConnection")
local serialization = require("serialization")

local SiloArrayServer = {}
SiloArrayServer.__index = SiloArrayServer

function SiloArrayServer.new(siloArray, secureConnection)
    if siloArray == nil then
        error("SiloArray cannot be nil")
    end
    if secureConnection == nil then
        error("SecureConnection cannot be nil")
    end

    local self = setmetatable({}, SiloArrayServer)
    self.siloArray = siloArray
    self.connection = secureConnection
    self.salvoFunctions = {}
    self.operationMap = {
        ["MA-getMissileTable"] = self.getMissileTable,
        ["MA-getSalvoTypes"] = self.getSalvoTypes,
        ["MA-launchMissile"] = self.launchMissile,
        ["MA-launchSalvo"] = self.launchSalvo,
        ["MA-scanStorage"] = self.scanStorage
    }
    self.running = false
    self.operatingOnSilos = false
    return self
end

function SiloArrayServer:registerSalvoFunction(name, func)
    self.salvoFunctions[name] = func
end

function SiloArrayServer:registerDefaultSalvoFunctions()
    self:registerSalvoFunction("random", SiloArray.launchSalvo_random)
    self:registerSalvoFunction("circle", SiloArray.launchSalvo_circle)
    self:registerSalvoFunction("square", SiloArray.launchSalvo_square)
end

function SiloArrayServer:getMissileTable(message)
    local missileTable = self.siloArray:getMissiles()
    self.connection:send(message.originID, "MA-getResponse", serialization.serialize(missileTable))
end

function SiloArrayServer:getSalvoTypes(message)
    self.connection:send(message.originID, "MA-getResponse", serialization.serialize(self.salvoFunctions))
end

function SiloArrayServer:launchMissile(message)
    -- message.data[1] = x, z coordinate
    -- message.data[2] = missile type
    self.operationOnSilos = true
    local coordinates = serialization.unserialize(message.data[1])
    if coordinates == nil or coordinates.x == nil or coordinates.z == nil or message.data[2] == nil then
        self.connection:send(message.originID, "MA-done", false)
        return
    end
    print("Received launch request: " .. math.modf(coordinates.x) .. ", " .. math.modf(coordinates.z) .. " type: " .. message.data[2])

    local success, error = self.siloArray:launchSingleMissile(message.data[2], coordinates.x, coordinates.z)
    if success ~= true then
        print("Failed to launch missile:")
        print(error)
        self.connection:send(message.originID, "MA-done", false, error)
    else
        print("Request successful")
        self.connection:send(message.originID, "MA-done", true)
    end
    self.operationOnSilos = false
end

function SiloArrayServer:launchSalvo(message)
    -- message.data[1] = x, z coordinate
    -- message.data[2] = missile type
    -- message.data[3] = salvo type
    -- message.data[4] = count
    -- message.data[5] = radius/separation
    if self.operationOnSilos then
        self.connection:send(message.originID, "MA-done", false, "Already operating on silos")
        return
    end
    self.operationOnSilos = true
    local coordinates = serialization.unserialize(message.data[1])
    if coordinates == nil or coordinates.x == nil or coordinates.z == nil or message.data[2] == nil or message.data[3] == nil or message.data[4] == nil or message.data[5] == nil then
        self.connection:send(message.originID, "MA-done", false)
        self.operationOnSilos = false
        return
    end
    print("Received salvo request: " .. math.modf(coordinates.x) .. ", " .. math.modf(coordinates.z) .. " type: " .. message.data[2] .. " salvo type: " .. message.data[3] .. " count: " .. message.data[4] .. " radius/separation: " .. message.data[5])

    if self.salvoFunctions[message.data[3]] == nil then
        self.connection:send(message.originID, "MA-done", false, "Salvo function not found")
        print("Salvo function not found")
        self.operationOnSilos = false
        return
    end

    local successCount, errorArr = self.salvoFunctions[message.data[3]](message.data[2], coordinates.x, coordinates.z, message.data[4], message.data[5])

    if successCount == 0 then
        print("Failed to launch salvo:")
        for i = 1, #errorArr do
            print(errorArr[i])
        end
        self.connection:send(message.originID, "MA-done", false, serialization.serialize(errorArr))
    elseif successCount < message.data[4] then
        print("Failed to launch all missiles in salvo:")
        for i = 1, #errorArr do
            print(errorArr[i])
        end
        self.connection:send(message.originID, "MA-done", false, serialization.serialize(errorArr))
    else
        print("Request successful")
        self.connection:send(message.originID, "MA-done", true)
    end
    self.operationOnSilos = false
end

function SiloArrayServer:scanStorage(message)
    self.connection:send(message.originID, "MA-scanTime", self.siloArray.storageScanningTime)
    self.siloArray:scanStorage()
    self.connection:send(message.originID, "MA-done", true)
end

function SiloArrayServer:run()
    self.running = true
    while self.running do
        self.running = self.connection:handleMessageThreaded(self.operationMap, self)
    end
end


