---@diagnostic disable: duplicate-set-field
local ProgramPackage = require("ProgramPackage")

local BunkerManagementProgram = ProgramPackage.new()
BunkerManagementProgram.__index = BunkerManagementProgram

function BunkerManagementProgram:description()
    return "BUNKER MANAGEMENT", "Remote for bunker doors and other devices"
end

function BunkerManagementProgram.new(terminalLevel, resources)
    local self = setmetatable(ProgramPackage.new(terminalLevel, resources), BunkerManagementProgram)

    self.requiredResources = {"gpu", "connection"}
    self.bootleg = {serverID = 8}

    return self
end


function BunkerManagementProgram:initStateFunctional()
    local serialization = require("serialization")

    self.functions.getDeviceState = (function (connectionID)
        self.resources.connection:send(connectionID, "RS-getDeviceTable")
        local message = self.resources.connection:getMessageFrom(5, connectionID, "RS-getResponse")
        if message == nil then
            return false, "No response from server"
        end
        return true, serialization.unserialize(message.data[1])
    end)

    self.functions.setDeviceState = (function (connectionID, deviceName, state, time)
        self.resources.connection:send(connectionID, "RS-setDeviceState", deviceName, state)
        local message = self.resources.connection:getMessageFrom(time + 1, connectionID, "RS-done")
        if message == nil then
            return false, "No response from server"
        end
        if not message.data[1] then
            return false, "Device not found"
        end
        return true
    end)

    self.functions.setAllDevices = (function (connectionID, state, ignore)
        self.resources.connection:send(connectionID, "RS-setAllDevices", state, serialization.serialize(ignore))
        local message = self.resources.connection:getMessageFrom(5, connectionID, "RS-setResponse")
        if message == nil then
            return false, "No response from server"
        end
        local maxTime = tonumber(message.data[1])
        message = self.resources.connection:getMessageFrom(maxTime + 2, connectionID, "RS-done")
        if message == nil then
            return false, "No response from server"
        end
        return true
    end)

end


function BunkerManagementProgram:initStateSession()
    self.session = {}

    self.session.devicesTable = {}
    self.session.deviceStates = {}
    self.session.ignoreDevicesIfClose = {LIGHTS = true}
    self.session.ignoreDevicesIfOpen = {LIGHTS = true, ["CONTROL ROOM"] = true}
end


function BunkerManagementProgram:initStateInterface()
    local DisplayElement = require("DisplayElement")
    local ElementGroup = require("ElementGroup")
    local DisplayMatrixTemplates = require("DisplayMatrixTemplates")

    self.elements = {}
    self.groups = {}
    self.displayMatrix = nil

    self.groups.other = ElementGroup.new()
    self.groups.buttons = ElementGroup.new()

    self.elements.title = DisplayElement.new()
    self.elements.errorFrame = DisplayElement.new()
    self.groups.other:addElement(self.elements.title)
    self.groups.other:addElement(self.elements.errorFrame)

    self.elements.openAllButton = DisplayElement.new()
    self.elements.closeAllButton = DisplayElement.new()
    self.elements.getStateButton = DisplayElement.new()
    self.elements.exitButton = DisplayElement.new()
    self.groups.buttons:addElement(self.elements.openAllButton)
    self.groups.buttons:addElement(self.elements.closeAllButton)
    self.groups.buttons:addElement(self.elements.getStateButton)
    self.groups.buttons:addElement(self.elements.exitButton)

    local listBuilder = DisplayMatrixTemplates.new("list")
    listBuilder.numberOfVisibleElements = 20
    listBuilder.elementWidth = 36
    listBuilder:setType("multi_select")
    self.elements.deviceList = listBuilder:build()
    self.groups.other:addElement(self.elements.deviceList.group)
end


function BunkerManagementProgram:initStateInitialized()
    self.groups.other:setPosition(1, 1)
    self.groups.buttons:setPosition(42, 3)

    self.elements.title:setPosition(2, 1)
    self.elements.title:setWidth(60)
    self.elements.title:setHeight(1)
    self.elements.title.drawFrame = true
    self.elements.title:setContent({
        "BUNKER MANAGEMENT"
    })

    self.elements.errorFrame:setPosition(1, 25)
    self.elements.errorFrame:setWidth(61)
    self.elements.errorFrame:setHeight(1)
    self.elements.errorFrame.drawFrame = true
    self.elements.errorFrame.centeredWidth = false
    self.elements.errorFrame.normal = {fg = 0xFF0000, bg = 0x000000}
    self.elements.errorFrame:setContent({
        ""
    })

    self.elements.openAllButton:setPosition(1, 1)
    self.elements.openAllButton:setWidth(20)
    self.elements.openAllButton:setHeight(3)
    self.elements.openAllButton.normal = {fg = 0x9090FF, bg = 0x0000F0}
    self.elements.openAllButton.active = {fg = 0x000000, bg = 0x9090FF}
    self.elements.openAllButton:setContent({
        "",
        "OPEN ALL"
    })
    
    self.elements.closeAllButton:setPosition(1, 4)
    self.elements.closeAllButton:setWidth(20)
    self.elements.closeAllButton:setHeight(3)
    self.elements.closeAllButton.normal = {fg = 0x9090FF, bg = 0x0000F0}
    self.elements.closeAllButton.active = {fg = 0x000000, bg = 0x9090FF}
    self.elements.closeAllButton:setContent({
        "",
        "CLOSE ALL"
    })

    self.elements.getStateButton:setPosition(1, 7)
    self.elements.getStateButton:setWidth(20)
    self.elements.getStateButton:setHeight(3)
    self.elements.getStateButton.normal = {fg = 0x9090FF, bg = 0x0000F0}
    self.elements.getStateButton.active = {fg = 0x000000, bg = 0x9090FF}
    self.elements.getStateButton:setContent({
        "",
        "UPDATE STATE"
    })

    self.elements.exitButton:setPosition(1, 10)
    self.elements.exitButton:setWidth(20)
    self.elements.exitButton:setHeight(3)
    self.elements.exitButton.normal = {fg = 0xFF0000, bg = 0x700000}
    self.elements.exitButton.active = {fg = 0x000000, bg = 0xFF0000}
    self.elements.exitButton:setContent({
        "",
        "EXIT"
    })

    self.elements.deviceList.group:setPosition(2, 3)
end


function BunkerManagementProgram:initStateOperational()
    local DisplayMatrix = require("DisplayMatrix")

    self.functions.downloadDeviceTable = (function()
        local success, response = self.functions.getDeviceState(self.bootleg.serverID)
        if not success then
            self.elements.errorFrame:setContent({
                response
            })
            self.elements.errorFrame:drawNormal(self.resources.gpu)
            return
        end
        self.session.deviceStates = response
        self.session.devicesTable = {}
        for i, device in pairs(self.session.deviceStates) do
            self.session.devicesTable[i] = {device.name}
        end
    end)

    self.functions.updateDeviceList = (function()
        self.elements.deviceList:setContent(self.session.devicesTable)
        self.elements.deviceList.activeElements = {}
        for i, key in pairs(self.session.devicesTable) do
            if self.session.deviceStates[i].state then
                self.elements.deviceList.activeElements[i] = true
            end
        end
        for i = 1, self.elements.deviceList.numberOfVisibleElements do
            self.elements.deviceList:drawElement(i, self.resources.gpu)
        end
    end)

    local program = self
    self.elements.getStateButton.action = (function(self, displayMatrix)
        program.functions.downloadDeviceTable()
        program.functions.updateDeviceList()
        self:drawNormal(displayMatrix.gpu)
    end)

    self.elements.openAllButton.action = (function(self, displayMatrix)
        local success, response = program.functions.setAllDevices(program.bootleg.serverID, false, program.session.ignoreDevicesIfOpen)
        if not success then
            program.elements.errorFrame:setContent({
                response
            })
            program.elements.errorFrame:drawNormal(program.resources.gpu)
            return
        end
        program.functions.downloadDeviceTable()
        program.functions.updateDeviceList()
        self:drawNormal(displayMatrix.gpu)
    end)

    self.elements.closeAllButton.action = (function(self, displayMatrix)
        local success, response = program.functions.setAllDevices(program.bootleg.serverID, true, program.session.ignoreDevicesIfClose)
        if not success then
            program.elements.errorFrame:setContent({
                response
            })
            program.elements.errorFrame:drawNormal(program.resources.gpu)
            return
        end
        program.functions.downloadDeviceTable()
        program.functions.updateDeviceList()
        self:drawNormal(displayMatrix.gpu)
    end)

    self.elements.exitButton.action = (function(self, displayMatrix)
        displayMatrix:exit()
    end)

    self.elements.deviceList.onListInteractionFunction = (function (list, elementIndex, element, displayMatrix)
        local deviceName = program.session.devicesTable[elementIndex][1]
        local deviceState = program.session.deviceStates[elementIndex].state
        local success, response = program.functions.setDeviceState(program.bootleg.serverID, deviceName, not deviceState, 2)
        if not success then
            program.elements.errorFrame:setContent({
                response
            })
            program.elements.errorFrame:drawNormal(program.resources.gpu)
            return
        end
        program.session.deviceStates[elementIndex].state = not deviceState
    end)

    self.displayMatrix = DisplayMatrix.new(self.resources.gpu)
    for _, group in pairs(self.groups) do
        self.displayMatrix:addGroup(group)
    end
end


function BunkerManagementProgram:initStateRunning()
    self.displayMatrix:setDims(62, 25)
    self.displayMatrix:draw()
    if self.session.devicesTable == nil or #self.session.devicesTable == 0 then
        self.functions.downloadDeviceTable()
    end
    self.functions.updateDeviceList()
    self.displayMatrix:main()
end

return BunkerManagementProgram