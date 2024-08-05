local comp = require("component")
local event = require("event")
local serialization = require("serialization")
local os = require("os")
local thread = require("thread")

local ModemMessageFilter = require("ModemMessageFilter")

local Manager = {}
Manager.__index = Manager

function Manager.new(modem)
    local self = setmetatable({}, Manager)
    self.junctions = {}
    self.connectionMap = {}
    self.serversAddr = {}
    self.running = false

    self.pingStartTimes = {}
    self.pingDurations = {}

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
    self.responseMap["junction-ping-response"] = self.pingJunctionMeasure
    self.responseMap["junction-report"] = self.logMessage
    self.responseMap["junction-shutdown"] = self.logJunctionShutdown
    self.responseMap["junction-id-login"] = self.logConnectionLogin

    return self
end

function Manager:log(message)
    print(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. message)
end

function Manager:initializeThisDevice()
    self.modem.close()
    self.modem.open(1)
    comp.redstone.setWakeThreshold(15)
end

function Manager:loadConfig(location)
    local file = io.open(location, "r")
    if file then
        for line in file:lines() do
            local separetor = string.find(line, ",")
            local string1 = string.sub(line, 1, separetor - 1)
            local num2 = tonumber(string.sub(line, separetor + 1))
            print(string1, num2)
            if string1 and num2 then
                self.connectionMap[string1] = num2
            end
        end
        file:close()
    else
        error("Failed to open file: " .. location)
    end
end

function Manager:start(slow, test)
    self:log("Manager started")

    self:initializeThisDevice()
    self:log("Device initialized")

    self:loadConfig("./connections.csv")
    self:log("Config loaded")

    self:bootJunctions()
    self:log("Junctions boot sequence sent")
    if slow then
        self:slowInitialization()
    else
        self:log("FAST INITIALIZATION NOT IMPLEMENTED")
        return
    end

    self:testJunctionConnectivity()

    thread.create(self.keyboardThread, self)
    self:monitorIncomingMessages()
end

function Manager:bootJunctions()
    self.modem.broadcast(1, "junction-wake")
    os.sleep(5)
    self.modem.broadcast(1, "manager-ping")
end

function Manager:slowInitialization()
    self:log("Slow initialization started")

    local responseCount = 0

    local junctionAddresses = {}
    local responseInTime = true
    while responseInTime do
        local success, _, remoteAddr, _, _, header, message2, message3, message4 = event.pull(5, "modem_message")
        if success == nil then
            responseInTime = false
        elseif header == "junction-connections-initialize" then
            junctionAddresses[remoteAddr] = message2
            self:log(remoteAddr .. " junction connections received")
            responseCount = responseCount + 1
        end
    end

    self:log("Received " .. responseCount .. " junction connections")

    for addr, channels in pairs(junctionAddresses) do
        self:log(addr .. " initializing junction")
        local connectionIDs = {}
        local connectionChannels = serialization.unserialize(channels)
        for _, channel in pairs(connectionChannels) do
            connectionIDs[channel] = self.connectionMap[channel] or 0
        end
        self.modem.send(addr, 1, "manager-connections-initialize", serialization.serialize(connectionIDs))
        local success, _, remoteAddr, _, _, header, message2, message3, message4 = event.pullFiltered(5, function(...)
            return ModemMessageFilter.new("modem_message", nil, addr, 1, nil, nil, "junction-connections-ready"):match(...)
        end)
        if success ~= nil then
            self:log(addr .. " is ready")
            for _, connectionID in pairs(connectionIDs) do
                self.junctions[connectionID] = addr
                self:log(addr .. " connection " .. connectionID)
            end
            table.insert(self.serversAddr, addr)
        else
            self:log(addr .. " failed to initialize")
        end
    end

    self:sendNetTable()

    self:log("Slow initialization complete")
end

function Manager:sendNetTable()
    self:log("Sending net table")
    local serializedJunctions = serialization.serialize(self.junctions)
    for _, addr in pairs(self.serversAddr) do
        self.modem.send(addr, 1, "manager-net-table", serializedJunctions)
        local success, _, remoteAddr, _, _, header, message2, message3, message4 = event.pullFiltered(5, function(...)
            return ModemMessageFilter.new("modem_message", nil, addr, 1, nil, nil, "junction-net-table-ready"):match(...)
        end)
        if success ~= nil then
            self:log(addr .. "net table sent")
        else
            self:log(addr .. "net table failed to sent")
        end
    end
    self:log("Net table sent")
end

function Manager:monitorIncomingMessages()
    self:log("Monitoring incoming messages")
    self.running = true
    while self.running do
        local fullEvent = {event.pullMultiple("modem_message", "interrupted")}
        local remoteAddr = fullEvent[3]
        local message_header = fullEvent[6]

        if fullEvent[1] == "modem_message" then
            self.responseMap[message_header](self, remoteAddr, select(7, table.unpack(fullEvent)))
        end
    end
    self:log("Shutting down")
    self:stopAllJunctions()
    self:log("Shut down complete")
end

function Manager:pingJunction(addr)
    local start = os.time()
    self.modem.send(addr, 1, "manager-ping")
    self.pingStartTimes[addr] = start
end

function Manager:pingJunctionMeasure(remoteAddr, message2, message3, message4)
    local diff = (os.time() - self.pingStartTimes[remoteAddr]) / 72
    self.pingDurations[remoteAddr] = diff
    self.pingStartTimes[remoteAddr] = nil
    self:log(remoteAddr .. " pinged in " .. string.format("%.2f", diff) .. " seconds")
end

function Manager:logMessage(remoteAddr, message2, message3, ...)
    self:log("Message from " .. message3 .. " to " .. message2 .. ":")
    print("", ...)
end

function Manager:stop()
    self.running = false
    event.push("interrupted")
end

function Manager:stopAllJunctions()
    for _, addr in pairs(self.serversAddr) do
        self:log("Shutting down " .. addr)
        self.modem.send(addr, 1, "manager-shutdown")
    end
end

function Manager:keyboardThread()
    while true do
        local _ = event.pull("key_down")
        if self.running then
            self:stop()
            break
        end
    end
end

function Manager:testJunctionConnectivity(timeout)
    timeout = timeout or 4
    self:log("Testing junction connectivity")
    local correctResponses = 0
    local junctionCount = #self.serversAddr
    for _, addr in pairs(self.serversAddr) do
        self.modem.send(addr, 1, "manager-ping-request", timeout)
        -- os.sleep(1)
        -- self.modem.send(addr, 1, "manager-ping-get")
        local success, _, remoteAddr, _, _, header, message2, message3, message4 = event.pullFiltered(timeout + 1, function(...)
            return ModemMessageFilter.new("modem_message", nil, addr, 1, nil, nil, "junctions-ping-response"):match(...)
        end)
        if success ~= nil then
            self:log(addr .. " pinged")
            local pingTable = serialization.unserialize(message2)
            
            local junctionCorrectResponses = 0
            for junctionAddr, ping in pairs(pingTable) do
                if ping == -1 then
                    print("", junctionAddr, "no response")
                else
                    print("", junctionAddr, string.format("%.2f", ping / 72) .. " seconds")
                    junctionCorrectResponses = junctionCorrectResponses + 1
                end
            end
            if junctionCorrectResponses == junctionCount - 1 then
                correctResponses = correctResponses + 1
            end
            self:log(addr .. " " .. junctionCorrectResponses .. " / " .. junctionCount - 1)
        else
            self:log(addr .. " failed to ping")
        end
    end
    self:log("Correct responses: " .. correctResponses .. " / " .. junctionCount)
end

function Manager:pingJunctions()
    for _, addr in pairs(self.serversAddr) do
        self:pingJunction(addr)
        local success, _, remoteAddr, _, _, header, message2, message3, message4 = event.pullFiltered(5, function(...)
            return ModemMessageFilter.new("modem_message", nil, addr, 1, nil, nil, "junction-ping-response"):match(...)
        end)
        if success ~= nil then
            self:pingJunctionMeasure(remoteAddr, message2, message3, message4)
        else
            self:log(addr .. " failed to ping")
        end
    end
end

function Manager:logJunctionShutdown(remoteAddr)
    self:log(remoteAddr .. " has shut down")
    -- self.serversAddr[remoteAddr] = nil -- it will be better if Manager had a list of connection states
end

function Manager:logConnectionLogin(_, ID)
    self:log("Connection(" .. ID .. ") has logged in")
end

return Manager