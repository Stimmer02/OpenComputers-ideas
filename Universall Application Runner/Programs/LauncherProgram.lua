---@diagnostic disable: duplicate-set-field
local ProgramPackage = require("ProgramPackage")

local LauncherProgram = ProgramPackage.new()
LauncherProgram.__index = LauncherProgram

function LauncherProgram:description()
    return "ROCKET SILO REMOTE CONTROL", "Simple remote control for rocket silo"
end

function LauncherProgram.new(terminalLevel, resources)
    local self = setmetatable(ProgramPackage.new(terminalLevel, resources), LauncherProgram)
    
    self.requiredResources = {"gpu", "connection"}

    self.depNames[2] = {"CompassProgram"}

    return self
end


function LauncherProgram:initStateFunctional()
    local serialization = require("serialization")

    self.functions.requestLaunch = (function (connectionID, targetX, targetZ, missileName)
        self.resources.connection:send(connectionID, "launch", serialization.serialize({x = targetX, z = targetZ}), missileName)
        local response = self.resources.connection:getMessageFrom(5, connectionID, "launch")
        if response ~= nil then
            if response.data[1] == "confirmed" then
                return true
            else
                return false, serialization.unserialize(response.data[2])
            end
        else
            return false, "No response from server"
        end
    end)

    self.functions.getMissiles = (function (connectionID)
        self.resources.connection:send(connectionID, "getMissiles")
        local response = self.resources.connection:getMessageFrom(5, connectionID, "missiles")
        if response ~= nil then
            return true, serialization.unserialize(response.data[1])
        else
            return false, "No response from server"
        end
    end)
end


function LauncherProgram:initStateSession()
    self.session = {}

    self.session.listContetnt = {}
    self.session.missileTable = {}
    self.session.target = {}
    self.session.selectedMissileIndex = nil
end


function LauncherProgram:initStateInterface()
    local DisplayElement = require("DisplayElement")
    local ElementGroup = require("ElementGroup")
    local DisplayMatrixTemplates = require("DisplayMatrixTemplates")

    self.elements = {}
    self.groups = {}
    self.displayMatrix = nil

    self.groups.target = ElementGroup.new()
    self.groups.buttons = ElementGroup.new()
    self.groups.missile = ElementGroup.new()
    self.groups.other = ElementGroup.new()

    self.elements.title = DisplayElement.new()
    self.elements.errorFrame = DisplayElement.new()
    self.groups.other:addElement(self.elements.title)
    self.groups.other:addElement(self.elements.errorFrame)

    self.elements.positionFrame = DisplayElement.new()
    self.elements.positionTitle = DisplayElement.new()
    self.elements.positionDesctiption = DisplayElement.new()
    self.elements.positionX = DisplayElement.new()
    self.elements.positionZ = DisplayElement.new()
    self.groups.target:addElement(self.elements.positionFrame)
    self.groups.target:addElement(self.elements.positionTitle)
    self.groups.target:addElement(self.elements.positionDesctiption)
    self.groups.target:addElement(self.elements.positionX)
    self.groups.target:addElement(self.elements.positionZ)

    self.elements.missileTableTitle = DisplayElement.new()
    self.groups.missile:addElement(self.elements.missileTableTitle)

    self.elements.getPositionButton = DisplayElement.new()
    self.elements.getMissilesButton = DisplayElement.new()
    self.elements.launchButton = DisplayElement.new()
    self.elements.exitButton = DisplayElement.new()
    self.groups.buttons:addElement(self.elements.getPositionButton)
    self.groups.buttons:addElement(self.elements.getMissilesButton)
    self.groups.buttons:addElement(self.elements.launchButton)
    self.groups.buttons:addElement(self.elements.exitButton)

    local listBuilder = DisplayMatrixTemplates.new("list")
    listBuilder.numberOfVisibleElements = 12
    listBuilder.elementWidth = 39
    listBuilder:setType("single_select")
    self.elements.missileList = listBuilder:build()
    self.groups.missile:addElement(self.elements.missileList.group)
end


function LauncherProgram:initStateInitialized()
    self.groups.target:setPosition(2, 3)
    self.groups.buttons:setPosition(1, 8)
    self.groups.missile:setPosition(21, 3)
    self.groups.other:setPosition(1, 1)

    self.elements.title:setPosition(2, 1)
    self.elements.title:setWidth(60)
    self.elements.title:setHeight(1)
    self.elements.title.drawFrame = true
    self.elements.title:setContent({
        "ROCKET SILO REMOTE CONTROLL"
    })

    self.elements.errorFrame:setPosition(2, 18)
    self.elements.errorFrame:setWidth(60)
    self.elements.errorFrame:setHeight(1)
    self.elements.errorFrame.drawFrame = true
    self.elements.errorFrame.centeredWidth = false
    self.elements.errorFrame.normal = {fg = 0xFF0000, bg = 0x000000}
    self.elements.errorFrame:setContent({
        ""
    })

    self.elements.positionFrame:setPosition(1, 1)
    self.elements.positionFrame:setWidth(18)
    self.elements.positionFrame:setHeight(4)
    self.elements.positionFrame.drawFrame = true

    self.elements.positionTitle:setPosition(1, 1)
    self.elements.positionTitle:setWidth(18)
    self.elements.positionTitle:setHeight(1)
    self.elements.positionTitle.drawFrame = true
    self.elements.positionTitle:setContent({
        "Position:"
    })

    self.elements.positionDesctiption:setPosition(1, 3)
    self.elements.positionDesctiption:setWidth(1)
    self.elements.positionDesctiption:setHeight(2)
    self.elements.positionDesctiption.centeredWidth = false
    self.elements.positionDesctiption:setContent({
        "X",
        "Z"
    })

    self.elements.positionX:setPosition(3, 3)
    self.elements.positionX:setWidth(16)
    self.elements.positionX:setHeight(1)
    self.elements.positionX:setContent({
        tostring(self.session.target.x or "---")
    })

    self.elements.positionZ:setPosition(3, 4)
    self.elements.positionZ:setWidth(16)
    self.elements.positionZ:setHeight(1)
    self.elements.positionZ:setContent({
        tostring(self.session.target.z or "---")
    })

    self.elements.missileTableTitle:setPosition(1, 1)
    self.elements.missileTableTitle:setWidth(41)
    self.elements.missileTableTitle:setHeight(1)
    self.elements.missileTableTitle.drawFrame = true
    self.elements.missileTableTitle:setContent({
        "Missiles:"
    })

    self.elements.getPositionButton:setPosition(2, 1)
    self.elements.getPositionButton:setWidth(17)
    self.elements.getPositionButton:setHeight(3)
    self.elements.getPositionButton.normal = {fg = 0x9090FF, bg = 0x0000F0}
    self.elements.getPositionButton.active = {fg = 0x000000, bg = 0x9090FF}
    self.elements.getPositionButton:setContent({
        "",
        "GET POSITION"
    })

    self.elements.getMissilesButton:setPosition(2, 4)
    self.elements.getMissilesButton:setWidth(17)
    self.elements.getMissilesButton:setHeight(3)
    self.elements.getMissilesButton.normal = {fg = 0x9090FF, bg = 0x0000F0}
    self.elements.getMissilesButton.active = {fg = 0x000000, bg = 0x9090FF}
    self.elements.getMissilesButton:setContent({
        "",
        "GET MISSILES"
    })

    self.elements.launchButton:setPosition(2, 7)
    self.elements.launchButton:setWidth(9)
    self.elements.launchButton:setHeight(3)
    self.elements.launchButton.normal = {fg = 0x00FF00, bg = 0x007000}
    self.elements.launchButton.active = {fg = 0x000000, bg = 0x00FF00}
    self.elements.launchButton:setContent({
        "",
        "LAUNCH"
    })

    self.elements.exitButton:setPosition(11, 7)
    self.elements.exitButton:setWidth(8)
    self.elements.exitButton:setHeight(3)
    self.elements.exitButton.normal = {fg = 0xFF0000, bg = 0x700000}
    self.elements.exitButton.active = {fg = 0x000000, bg = 0xFF0000}
    self.elements.exitButton:setContent({
        "",
        "EXIT"
    })

    self.elements.missileList.group:setPosition(1, 3)
    self.elements.missileList:setContent(self.session.listContetnt)
end


function LauncherProgram:initStateOperational()
    local DisplayMatrix = require("DisplayMatrix")
    local os = require("os")

    self.functions.checkIfAllSet = (function()
        return self.session.target.x ~= nil and self.session.selectedMissileIndex ~= nil
    end)

    self.functions.colorLaunchButton = (function()
        if self.functions.checkIfAllSet() then
            self.elements.launchButton.normal = {fg = 0x00FF00, bg = 0x007000}
            self.elements.launchButton.active = {fg = 0x000000, bg = 0x00FF00}
        else
            self.elements.launchButton.normal = {fg = 0x707070, bg = 0x303030}
            self.elements.launchButton.active = {fg = 0x000000, bg = 0xFF00000}
        end
        self.elements.launchButton:drawNormal(self.resources.gpu)
    end)


    local program = self
    self.elements.getPositionButton.action = (function(self, displayMatrix)
        program.elements.positionZ:setContent({
            "downloading"
        })
        program.elements.positionX:setContent({
            "downloading"
        })
        program.elements.positionZ:drawNormal(displayMatrix.gpu)
        program.elements.positionX:drawNormal(displayMatrix.gpu)

        local success, response = program.dep.CompassProgram.getPosition()

        if success then
            program.elements.positionZ:setContent({
                tostring(response.z)
            })
            program.elements.positionX:setContent({
                tostring(response.x)
            })
            program.session.target = {x = response.x, z = response.z}
        else
            program.elements.positionZ:setContent({
                "---"
            })
            program.elements.positionX:setContent({
                "---"
            })
            program.elements.errorFrame:setContent({
                "Server not responding"
            })
            program.elements.errorFrame:drawNormal(displayMatrix.gpu)
        end

        program.elements.positionZ:drawNormal(displayMatrix.gpu)
        program.elements.positionX:drawNormal(displayMatrix.gpu)
        program.functions.colorLaunchButton()
        self:drawNormal(displayMatrix.gpu)
    end)

    self.elements.getMissilesButton.action = (function(self, displayMatrix)
        local success, response = program.functions.getMissiles(3)
        if success then
            program.session.listContetnt = {}
            program.session.missileTable = {}
            for missileName, count in pairs(response) do
                table.insert(program.session.listContetnt, {tostring(missileName).." x "..tostring(count)})
                table.insert(program.session.missileTable, missileName)
            end

            program.elements.missileList:setContent(program.session.listContetnt)
            program.elements.missileList.activeElement = nil
            program.session.selectedMissileIndex = nil
            program.elements.missileList.topElementIndex = 1
            program.elements.missileList.group:drawNormal(displayMatrix.gpu, true)
            program.functions.colorLaunchButton()
        else
            program.elements.errorFrame:setContent({
                response[1] or response or "ERROR"
            })
            program.elements.errorFrame:drawNormal(displayMatrix.gpu)
        end
        self:drawNormal(displayMatrix.gpu)
    end)

    self.elements.launchButton.action = (function(self, displayMatrix)
        if program.functions.checkIfAllSet() then
            local success, errorMessage = program.functions.requestLaunch(3, program.session.target.x, program.session.target.z, program.session.missileTable[program.session.selectedMissileIndex])
            if not success then
                program.elements.launchButton.normal = {fg = 0x000000, bg = 0xFF00000}
                self:drawNormal(displayMatrix.gpu)
                program.elements.errorFrame:setContent({
                    errorMessage or "ERROR"
                })
                program.elements.errorFrame:drawNormal(displayMatrix.gpu)
                os.sleep(1)
                program.elements.launchButton.normal = {fg = 0x00FF00, bg = 0x007000}
            end
        end
        self:drawNormal(displayMatrix.gpu)
    end)

    self.elements.exitButton.action = (function(self, displayMatrix)
        displayMatrix:exit()
    end)

    self.elements.missileList.onListInteractionFunction = (function (list, elementIndex, element, displayMatrix)
        if list.activeElement == nil then
            program.session.selectedMissileIndex = nil
        else
            program.session.selectedMissileIndex = list.activeElement
        end
        program.functions.colorLaunchButton()
    end)


    self.displayMatrix = DisplayMatrix.new(self.resources.gpu)
    for _, group in pairs(self.groups) do
        self.displayMatrix:addGroup(group)
    end
end


function LauncherProgram:initStateRunning()
    self.displayMatrix:setDims(62, 19)
    self.displayMatrix:draw()
    self.functions.colorLaunchButton()
    self.displayMatrix:main()
end

function LauncherProgram:revertStateRunning()
    self.session.selectedMissileIndex = nil
end


return LauncherProgram