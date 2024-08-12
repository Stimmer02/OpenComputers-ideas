---@diagnostic disable: duplicate-set-field
local ProgramPackage = require("ProgramPackage")

local DisplayElement = require("DisplayElement")
local ElementGroup = require("ElementGroup")
local DisplayMatrixTemplates = require("DisplayMatrixTemplates")
local serialization = require("serialization")
local DisplayMatrix = require("DisplayMatrix")
local os = require("os")

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
    self.functions.getSiloID = (function ()
        return 1
    end)

    self.functions.requestLaunch = (function (connectionID, targetX, targetZ, missileName)
        self.resources.connection:send(connectionID, "MA-launchMissile", serialization.serialize({x = targetX, z = targetZ}), missileName)
        local response = self.resources.connection:getMessageFrom(5, connectionID, "MA-done")
        if response ~= nil then
            if response.data[1] then
                return true
            else
                return false, serialization.unserialize(response.data[2])
            end
        else
            return false, "No response from server"
        end
    end)

    self.functions.getMissiles = (function (connectionID)
        self.resources.connection:send(connectionID, "MA-getMissileTable")
        local response = self.resources.connection:getMessageFrom(5, connectionID, "MA-getResponse")
        if response ~= nil then
            return true, serialization.unserialize(response.data[1])
        else
            return false, "No response from server"
        end
    end)

    self.functions.getScanStorageTime = (function (connectionID)
        self.resources.connection:send(connectionID, "MA-getScanStorageTime")
        local response = self.resources.connection:getMessageFrom(5, connectionID, "MA-scanTime")
        if response ~= nil then
            return true, response.data[1]
        else
            return false, "No response from server"
        end
    end)

    self.functions.scanStorage = (function (connectionID, scanTime)
        self.resources.connection:send(connectionID, "MA-scanStorage")
        local response = self.resources.connection:getMessageFrom(scanTime, connectionID, "MA-done")
        if response ~= nil and response.data[1] then
            return true
        else
            return false, "No response from server"
        end
    end)

    self.functions.getSalvoTypes = (function (connectionID)
        self.resources.connection:send(connectionID, "MA-getSalvoTypes")
        local response = self.resources.connection:getMessageFrom(5, connectionID, "MA-getResponse")
        if response ~= nil then
            return true, serialization.unserialize(response.data[1])
        else
            return false, "No response from server"
        end
    end)

    self.functions.requestSalvo = (function (connectionID, targetX, targetZ, missileType, salvoType, count, radiusOrSeparation)
        self.resources.connection:send(connectionID, "MA-launchSalvo", serialization.serialize({x = targetX, z = targetZ}), missileType, serialization.serialize({salvoType, count, radiusOrSeparation}))
        local response = self.resources.connection:getMessageFrom(5, connectionID, "MA-salvoTime")
        if response == nil then
            return false, "No response from server"
        end
        response = self.resources.connection:getMessageFrom(response.data[1], connectionID, "MA-done")
        if response ~= nil then
            if response.data[1] then
                return true
            else
                return false, serialization.unserialize(response.data[2])
            end
        else
            return false, "No response from server"
        end
    end)
end


function LauncherProgram:initStateSession()
    self.session = {}

    self.session.missileListContetnt = {}
    self.session.missileTable = {}
    self.session.selectedMissileIndex = nil

    self.session.salvoListContent = {}
    self.session.salvoTable = {}
    self.session.selectedSalvoIndex = nil

    self.session.salvoCount = 10
    self.session.salvoSeparation = 85

    self.session.target = {}
    self.session.oryginalTarget = {}
    self.session.maxOryginalTargetDistance = 100
end


function LauncherProgram:initStateInterface()
    self.elements = {}
    self.groups = {}
    self.displayMatrix = nil

    self.groups.target = ElementGroup.new()
    self.groups.buttons = ElementGroup.new()
    self.groups.missile = ElementGroup.new()
    self.groups.salvos = ElementGroup.new()
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

    self.elements.salvoTableTitle = DisplayElement.new()
    self.elements.salvoCountDescription = DisplayElement.new()
    self.elements.salvoCount = DisplayElement.new()
    self.elements.salvoSeparationDescription = DisplayElement.new()
    self.elements.salvoSeparation = DisplayElement.new()
    self.groups.salvos:addElement(self.elements.salvoTableTitle)
    self.groups.salvos:addElement(self.elements.salvoCountDescription)
    self.groups.salvos:addElement(self.elements.salvoCount)
    self.groups.salvos:addElement(self.elements.salvoSeparationDescription)
    self.groups.salvos:addElement(self.elements.salvoSeparation)

    self.elements.getPositionButton = DisplayElement.new()
    self.elements.getMissilesButton = DisplayElement.new()
    self.elements.scanStorageButton = DisplayElement.new()
    self.elements.getSalvoTypesButton = DisplayElement.new()
    self.elements.launchButton = DisplayElement.new()
    self.elements.exitButton = DisplayElement.new()
    self.groups.buttons:addElement(self.elements.getPositionButton)
    self.groups.buttons:addElement(self.elements.getMissilesButton)
    self.groups.buttons:addElement(self.elements.scanStorageButton)
    self.groups.buttons:addElement(self.elements.getSalvoTypesButton)
    self.groups.buttons:addElement(self.elements.launchButton)
    self.groups.buttons:addElement(self.elements.exitButton)

    local listBuilder = DisplayMatrixTemplates.new("list")
    listBuilder.numberOfVisibleElements = 8
    listBuilder.elementWidth = 39
    listBuilder:setType("single_select")
    self.elements.missileList = listBuilder:build()
    self.groups.missile:addElement(self.elements.missileList.group)

    listBuilder = DisplayMatrixTemplates.new("list")
    listBuilder.numberOfVisibleElements = 5
    listBuilder.elementWidth = 39
    listBuilder:setType("single_select")
    self.elements.salvoList = listBuilder:build()
    self.groups.salvos:addElement(self.elements.salvoList.group)
end


function LauncherProgram:initStateInitialized()
    self.groups.target:setPosition(2, 3)
    self.groups.buttons:setPosition(1, 8)
    self.groups.missile:setPosition(21, 3)
    self.groups.salvos:setPosition(21, 14)
    self.groups.other:setPosition(1, 1)

    self.elements.title:setPosition(2, 1)
    self.elements.title:setWidth(60)
    self.elements.title:setHeight(1)
    self.elements.title.drawFrame = true
    self.elements.title:setContent({
        "ROCKET SILO REMOTE CONTROLL"
    })

    self.elements.errorFrame:setPosition(2, 24)
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

    self.elements.salvoTableTitle:setPosition(1, 1)
    self.elements.salvoTableTitle:setWidth(41)
    self.elements.salvoTableTitle:setHeight(1)
    self.elements.salvoTableTitle.drawFrame = true
    self.elements.salvoTableTitle.normal = {fg = 0xFFFFFF, bg = 0x000000}
    self.elements.salvoTableTitle.active = {fg = 0x000000, bg = 0xFFFFFF}
    self.elements.salvoTableTitle:setContent({
        "Salvo:"
    })

    self.elements.salvoCountDescription:setPosition(1, 3)
    self.elements.salvoCountDescription:setWidth(14)
    self.elements.salvoCountDescription:setHeight(1)
    self.elements.salvoCountDescription.drawFrame = true
    self.elements.salvoCountDescription.centeredWidth = false
    self.elements.salvoCountDescription:setContent({
        "Count:"
    })

    self.elements.salvoCount:setPosition(9, 3)
    self.elements.salvoCount:setWidth(5)
    self.elements.salvoCount:setHeight(1)
    self.elements.salvoCount.centeredWidth = false
    self.elements.salvoCount:setContent({
        tostring(self.session.salvoCount)
    })

    self.elements.salvoSeparationDescription:setPosition(16, 3)
    self.elements.salvoSeparationDescription:setWidth(26)
    self.elements.salvoSeparationDescription:setHeight(1)
    self.elements.salvoSeparationDescription.drawFrame = true
    self.elements.salvoSeparationDescription.centeredWidth = false
    self.elements.salvoSeparationDescription:setContent({
        "Separation/Radius:"
    })

    self.elements.salvoSeparation:setPosition(36, 3)
    self.elements.salvoSeparation:setWidth(5)
    self.elements.salvoSeparation:setHeight(1)
    self.elements.salvoSeparation.centeredWidth = false
    self.elements.salvoSeparation:setContent({
        tostring(self.session.salvoSeparation)
    })

    self.elements.getPositionButton:setPosition(2, 1)
    self.elements.getPositionButton:setWidth(17)
    self.elements.getPositionButton:setHeight(1)
    self.elements.getPositionButton.normal = {fg = 0x9090FF, bg = 0x0000F0}
    self.elements.getPositionButton.active = {fg = 0x000000, bg = 0x9090FF}
    self.elements.getPositionButton:setContent({
        "GET POSITION"
    })

    self.elements.getMissilesButton:setPosition(2, 3)
    self.elements.getMissilesButton:setWidth(17)
    self.elements.getMissilesButton:setHeight(1)
    self.elements.getMissilesButton.normal = {fg = 0x9090FF, bg = 0x0000F0}
    self.elements.getMissilesButton.active = {fg = 0x000000, bg = 0x9090FF}
    self.elements.getMissilesButton:setContent({
        "GET MISSILES"
    })

    self.elements.scanStorageButton:setPosition(2, 5)
    self.elements.scanStorageButton:setWidth(17)
    self.elements.scanStorageButton:setHeight(1)
    self.elements.scanStorageButton.normal = {fg = 0x9090FF, bg = 0x0000F0}
    self.elements.scanStorageButton.active = {fg = 0x000000, bg = 0x9090FF}
    self.elements.scanStorageButton:setContent({
        "SCAN STORAGE"
    })

    self.elements.getSalvoTypesButton:setPosition(2, 7)
    self.elements.getSalvoTypesButton:setWidth(17)
    self.elements.getSalvoTypesButton:setHeight(1)
    self.elements.getSalvoTypesButton.normal = {fg = 0x9090FF, bg = 0x0000F0}
    self.elements.getSalvoTypesButton.active = {fg = 0x000000, bg = 0x9090FF}
    self.elements.getSalvoTypesButton:setContent({
        "GET SALVO TYPES"
    })

    self.elements.launchButton:setPosition(2, 9)
    self.elements.launchButton:setWidth(9)
    self.elements.launchButton:setHeight(3)
    self.elements.launchButton.normal = {fg = 0x00FF00, bg = 0x007000}
    self.elements.launchButton.active = {fg = 0x000000, bg = 0x00FF00}
    self.elements.launchButton:setContent({
        "",
        "LAUNCH"
    })

    self.elements.exitButton:setPosition(11, 9)
    self.elements.exitButton:setWidth(8)
    self.elements.exitButton:setHeight(3)
    self.elements.exitButton.normal = {fg = 0xFF0000, bg = 0x700000}
    self.elements.exitButton.active = {fg = 0x000000, bg = 0xFF0000}
    self.elements.exitButton:setContent({
        "",
        "EXIT"
    })

    self.elements.missileList.group:setPosition(1, 3)
    self.elements.missileList:setContent(self.session.missileListContetnt)

    self.elements.salvoList.group:setPosition(1, 5)
    self.elements.salvoList:setContent(self.session.salvoListContent)
end


function LauncherProgram:initStateOperational()
    self.functions.checkIfAllSet = (function()
        return self.session.target.x ~= nil and self.session.selectedMissileIndex ~= nil
    end)

    self.functions.colorLaunchButton = (function()
        if self.functions.checkIfAllSet() then
            self.elements.launchButton.normal = {fg = 0x00FF00, bg = 0x007000}
            self.elements.launchButton.active = {fg = 0x000000, bg = 0x00FF00}
        else
            self.elements.launchButton.normal = {fg = 0x707070, bg = 0x303030}
            self.elements.launchButton.active = {fg = 0x000000, bg = 0xFF0000}
        end
        self.elements.launchButton:drawNormal(self.resources.gpu)
    end)

    self.functions.drawSalvoTitle = (function()
        if self.session.selectedSalvoIndex ~= nil then
            self.elements.salvoTableTitle:drawActive(self.resources.gpu)
        else
            self.elements.salvoTableTitle:drawNormal(self.resources.gpu)
        end
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
            program.session.oryginalTarget = {x = response.x, z = response.z}
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
        local success, response = program.functions.getMissiles(program.functions.getSiloID())
        if success then
            program.session.missileListContetnt = {}
            program.session.missileTable = {}
            for missileName, count in pairs(response) do
                table.insert(program.session.missileListContetnt, {tostring(missileName).." x "..tostring(count)})
                table.insert(program.session.missileTable, missileName)
            end

            program.elements.missileList:setContent(program.session.missileListContetnt)
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

    self.elements.getSalvoTypesButton.action = (function(self, displayMatrix)
        local success, response = program.functions.getSalvoTypes(program.functions.getSiloID())
        if success then
            program.session.salvoListContent = {}
            program.session.salvoTable = {}
            for _, salvoName in pairs(response) do
                table.insert(program.session.salvoListContent, {tostring(salvoName)})
                table.insert(program.session.salvoTable, salvoName)
            end

            program.elements.salvoList:setContent(program.session.salvoListContent)
            program.elements.salvoList.activeElement = nil
            program.session.selectedSalvoIndex = nil
            program.elements.salvoList.topElementIndex = 1
            program.elements.salvoList.group:drawNormal(displayMatrix.gpu, true)
        else
            program.elements.errorFrame:setContent({
                response[1] or response or "ERROR"
            })
            program.elements.errorFrame:drawNormal(displayMatrix.gpu)
        end
        self:drawNormal(displayMatrix.gpu)
    end)

    self.elements.scanStorageButton.action = function (self, displayMatrix)
        local success, response = program.functions.getScanStorageTime(program.functions.getSiloID())
        if success then
            program.elements.errorFrame:setContent({
                "Scan will take "..tostring(response).." seconds"
            })
            program.elements.errorFrame:drawNormal(displayMatrix.gpu)
            success, response = program.functions.scanStorage(program.functions.getSiloID(), response + 5)
            if success then
                program.elements.errorFrame:setContent({
                    "Scan complete"
                })
            else
                program.elements.errorFrame:setContent({
                    response or "ERROR"
                })
            end
        else
            program.elements.errorFrame:setContent({
                response or "ERROR"
            })
        end
        program.elements.errorFrame:drawNormal(displayMatrix.gpu)
        self:drawNormal(displayMatrix.gpu)
        
    end

    self.elements.launchButton.action = (function(self, displayMatrix)
        if program.functions.checkIfAllSet() then
            if program.session.selectedSalvoIndex ~= nil then
                local success, errorMessage = program.functions.requestSalvo(program.functions.getSiloID(), program.session.target.x, program.session.target.z, program.session.missileTable[program.session.selectedMissileIndex], program.session.salvoTable[program.session.selectedSalvoIndex], program.session.salvoCount, program.session.salvoSeparation)
                if not success then
                    program.elements.launchButton.normal = {fg = 0x000000, bg = 0xFF00000}
                    self:drawNormal(displayMatrix.gpu)
                    program.elements.errorFrame:setContent({
                        errorMessage[1] or "ERROR"
                    })
                    program.elements.errorFrame:drawNormal(displayMatrix.gpu)
                    os.sleep(1)
                    program.elements.launchButton.normal = {fg = 0x00FF00, bg = 0x007000}
                end
            else
                local success, errorMessage = program.functions.requestLaunch(program.functions.getSiloID(), program.session.target.x, program.session.target.z, program.session.missileTable[program.session.selectedMissileIndex])
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

    self.elements.salvoList.onListInteractionFunction = (function (list, elementIndex, element, displayMatrix)
        if list.activeElement == nil then
            program.session.selectedSalvoIndex = nil
        else
            program.session.selectedSalvoIndex = list.activeElement
        end
        program.functions.drawSalvoTitle()
    end)

    self.elements.salvoCount.scroll = (function (self, displayMatrix, direction)
        if program.session.salvoCount > 1 or direction > 0 then
            program.session.salvoCount = program.session.salvoCount + direction
            self:setContent({
                tostring(program.session.salvoCount)
            })
            self:drawNormal(displayMatrix.gpu)
        end
    end)

    self.elements.salvoSeparation.scroll = (function (self, displayMatrix, direction)
        if program.session.salvoSeparation > 5 or direction > 0 then
            program.session.salvoSeparation = program.session.salvoSeparation + 5*direction
            self:setContent({
                tostring(program.session.salvoSeparation)
            })
            self:drawNormal(displayMatrix.gpu)
        end
    end)

    self.elements.positionX.scroll = (function (self, displayMatrix, direction)
        if program.session.target.x ~= nil and
        ((direction > 0 and program.session.target.x - program.session.oryginalTarget.x < program.session.maxOryginalTargetDistance) or
        (direction < 0 and program.session.oryginalTarget.x - program.session.target.x < program.session.maxOryginalTargetDistance)) then
            program.session.target.x = program.session.target.x + direction*10
            self:setContent({
                tostring(program.session.target.x)
            })
            self:drawNormal(displayMatrix.gpu)
        end
    end)

    self.elements.positionZ.scroll = (function (self, displayMatrix, direction)
        if program.session.target.z ~= nil and
        ((direction > 0 and program.session.target.z - program.session.oryginalTarget.z < program.session.maxOryginalTargetDistance) or
        (direction < 0 and program.session.oryginalTarget.z - program.session.target.z < program.session.maxOryginalTargetDistance)) then
            program.session.target.z = program.session.target.z + direction*10
            self:setContent({
                tostring(program.session.target.z)
            })
            self:drawNormal(displayMatrix.gpu)
        end
    end)

    self.displayMatrix = DisplayMatrix.new(self.resources.gpu)
    for _, group in pairs(self.groups) do
        self.displayMatrix:addGroup(group)
    end
end


function LauncherProgram:initStateRunning()
    self.displayMatrix:setDims(62, 25)
    self.displayMatrix:draw()
    self.functions.colorLaunchButton()
    self.displayMatrix:main()
end

function LauncherProgram:revertStateRunning()
    self.session.selectedMissileIndex = nil
    self.session.selectedSalvoIndex = nil
end


return LauncherProgram