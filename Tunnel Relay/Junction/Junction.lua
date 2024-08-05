local comp = require("component")
local event = require("event")
local serialization = require("serialization")
local os = require("os")
local thread = require("thread")

local Junction = {}
Junction.__index = Junction

function Junction.new(modem)
    local self = setmetatable({}, Junction)
    self.junctions = {}
    self.connections = {}
    self.channelToID = {}
    self.managerAddr = ""
    self.running = false

    self.pingStartTimes = {}
    self.pingDurations = {}
    self.pingCount = 0
    self.pingResponseCount = 0
    self.pingRequestRetrunThread = nil
    self.pingRequestTimeoutThread = nil

    if modem then
        if modem.type == "string" then
            self.modem = comp.proxy(modem)
        else
            self.modem = modem
        end
    else
        self.modem = comp.getPrimary("modem")
    end

    if self.modem == nil then
        error("No modem found")
    end

    -- table of functions to call based on received header
    self.responseMap = {}
    self.responseMap["junction-send"] = self.passMessageToConnection
    self.responseMap["junction-ping"] = self.pingJunctionResponse
    self.responseMap["junction-ping-response"] = self.pingJunctionMeasure
    self.responseMap["manager-net-table"] = self.initializeNetTable
    self.responseMap["manager-ping"] = self.pingJunctionResponse
    self.responseMap["manager-ping-request"] = self.junctionsPingRequest
    self.responseMap["manager-ping-get"] = self.junctionsPingRequestResponse
    self.responseMap["manager-shutdown"] = self.shutdown
    self.responseMap["connection-send"] = self.passMessageToJunction
    self.responseMap["connection-id-info"] = self.sendConnectionID

    return self
end

--incoming message format: "connection-send" targetID originID message
--throughput message format: "junction-send" targetID originID message
--outgoing message format: originID message

function Junction:start()
    self:initializeThisDevice()
    self:managerHanshake()
    self:monitorIncomingMessages()
end

function Junction:initializeThisDevice()
    self.modem.close()
    self.modem.open(1)
    self.modem.setWakeMessage("junction-wake")
end

function Junction:monitorIncomingMessages()
    self.modem.send(self.managerAddr, 1, "junction-ready")
    self.running = true
    while self.running do
        local fullEvent = {event.pull("modem_message")}
        local remoteAddr = fullEvent[3]
        local message_header = fullEvent[6]
        self.responseMap[message_header](self, remoteAddr, select(7, table.unpack(fullEvent)))
    end
    self.modem.send(self.managerAddr, 1, "junction-shutdown")
end

function Junction:managerHanshake()
    while true do
        local _, _, remoteAddr, port, _, message_header = event.pull("modem_message")
        if port == 1 and message_header == "manager-ping" then
            self.managerAddr = remoteAddr
            break
        end
    end

    local connectionChannels = {}
    local connectionDevices = {}

    for a, v in pairs(comp.list()) do
        if v == "tunnel" then
            table.insert(connectionChannels, comp.proxy(a):getChannel())
            connectionDevices[comp.proxy(a):getChannel()] = comp.proxy(a)
        end
    end

    self.modem.send(self.managerAddr, 1, "junction-connections-initialize", serialization.serialize(connectionChannels))

    while true do
        local _, _, remoteAddr, port, _, message_header, message2 = event.pull("modem_message")
        if port == 1 and message_header == "manager-connections-initialize" and self.managerAddr == remoteAddr then
            self.channelToID = serialization.unserialize(message2)
            break
        end
    end

    for channel, id in pairs(self.channelToID) do
        self.connections[id] = connectionDevices[channel]
    end

    self.modem.send(self.managerAddr, 1, "junction-connections-ready")
end

function Junction:initializeNetTable(remoteAddr, message2)
    if remoteAddr ~= self.managerAddr then
        return
    end
    self.junctions = serialization.unserialize(message2)
    self.modem.send(remoteAddr, 1, "junction-net-table-ready")
end

function Junction:passMessageToJunction(remoteAddr, targetID, originID, ...)
    if targetID == nil or originID == nil then
        return
    end

    self:reportMessageToManager(targetID, originID, ...)
    if self.connections[targetID] ~= nil then
        self:passMessageToConnection(remoteAddr, targetID, originID, ...)
        return
    end
    local targetAddr = self.junctions[targetID]
    if targetAddr == nil then
        -- self.modem.send(remoteAddr, 1, "junction-not-found", targetID)
    else
        self.modem.send(targetAddr, 1, "junction-send", targetID, originID, ...)
        -- self.modem.send(remoteAddr, 1, "junction-send-ack")
    end
end

function Junction:passMessageToConnection(remoteAddr, targetID, originID, ...)
    local tunnel = self.connections[targetID]
    if tunnel == nil then
        self.modem.send(remoteAddr, 1, "connection-not-found", targetID, originID)
    else
        tunnel.send(originID, ...)
        -- self.modem.send(remoteAddr, 1, "connection-send-ack")
    end
end

function Junction:pingJunction(addr)
    local start = os.time()
    self.modem.send(addr, 1, "junction-ping")
    self.pingDurations[addr] = nil
    self.pingStartTimes[addr] = start
end

function Junction:pingJunctionResponse(remoteAddr)
    self.modem.send(remoteAddr, 1, "junction-ping-response")
end

function Junction:pingJunctionMeasure(remoteAddr)
    local start = self.pingStartTimes[remoteAddr]
    if start == nil then
        return
    end
    local diff = os.time() - start
    self.pingDurations[remoteAddr] = diff
    self.pingStartTimes[remoteAddr] = nil
    self.pingResponseCount = self.pingResponseCount + 1
    if self.pingCount == self.pingResponseCount and self.pingRequestTimeoutThread:status() ~= "dead" then
        self.pingRequestTimeoutThread:kill()
        self.pingRequestRetrunThread:join()
    end
end

function Junction:junctionsPingRequest(remoteAddr, maxResponseTime)
    self.pingRequestTimeoutThread = thread.create(function()
        os.sleep(maxResponseTime)
    end)
    self.pingRequestRetrunThread = thread.create(function()
        self.pingRequestTimeoutThread:join()
        self:junctionsPingRequestResponse(remoteAddr)
        self.pingCount = 0
        self.pingResponseCount = 0
    end)
    local thisThread = thread.create(function()
        self.pingResponseCount = 0
        self.pingCount = 0
        local toPing = {}
        
        for k, v in pairs(self.junctions) do
            if self.modem.address ~= v then
                toPing[v] = true
            end
        end
        local pingCountTemp = 0
        for v, _ in pairs(toPing) do
            self:pingJunction(v)
            pingCountTemp = pingCountTemp + 1
        end
        self.pingCount = pingCountTemp
        if self.pingCount == self.pingResponseCount and self.pingRequestTimeoutThread:status() ~= "dead" then
            self.pingRequestTimeoutThread:kill()
            self.pingRequestRetrunThread:join()
        end
    end)
end

function Junction:junctionsPingRequestResponse(remoteAddr)
    local pingTable = {}
    for k, v in pairs(self.pingDurations) do
        pingTable[k] = v
    end
    for k, v in pairs(self.pingStartTimes) do
        pingTable[k] = -1
    end
    table.sort(pingTable)
    self.modem.send(remoteAddr, 1, "junctions-ping-response", serialization.serialize(pingTable))
end

function Junction:reportMessageToManager(targetID, originID, ...)
    self.modem.send(self.managerAddr, 1, "junction-report", targetID, originID, ...)
end

function Junction:shutdown(remoteAddr)
    if remoteAddr ~= self.managerAddr then
        return
    end
    self.running = false
end

function Junction:sendConnectionID(_, connectionChannel)
    local originID = self.channelToID[connectionChannel]
    local tunnel = self.connections[originID]

    if tunnel ~= nil then
        tunnel.send("junction-id-response", originID)
        self.modem.send(self.managerAddr, 1, "junction-id-login", originID)
    else
        self.modem.send(self.managerAddr, 1, "junction-id-login", "NOT FOUND")
    end
end

return Junction