---@diagnostic disable: duplicate-set-field
local ProgramPackage = require("ProgramPackage")

local serialization = require("serialization")
local DisplayElement = require("DisplayElement")
local ElementGroup = require("ElementGroup")
local DisplayMatrix = require("DisplayMatrix")
local os = require("os")
local thread = require("thread")


local CompassPackage = ProgramPackage.new()
CompassPackage.__index = CompassPackage

function CompassPackage:description()
    return "COMPASS", "Shows cordinates and direction"
end

function CompassPackage.new(terminalLevel, resources)
    local self = setmetatable(ProgramPackage.new(terminalLevel, resources), CompassPackage)

    self.requiredResources = {"gpu", "navigation", "connection", "userName"}


    return self
end


function CompassPackage:initStateFunctional()

    self.functions.getPosition = function()
        self.resources.connection:send(2, self.resources.userName)
        local response = self.resources.connection:getMessageFrom(5, 2, "location")

        if response ~= nil then
            local message = serialization.unserialize(response.data[1])
            local x = math.floor(message.x)
            local z = math.floor(message.z)
            return true, {x = x, z = z}
        else
            return false, "No server response"
        end
    end

    self.functions.getDirection = function()
        return true, self.resources.navigation.getFacing()
    end

    local directionMap = {}
    directionMap[2] = "north"
    directionMap[3] = "south"
    directionMap[4] = "west"
    directionMap[5] = "east"
    self.functions.directionToString = function(direction)
        local out = directionMap[direction]
        return out ~= nil, out or "Invalid direction"
    end
end

function CompassPackage:initStateSession()
    self.session.threadRunning = false
end

function CompassPackage:initStateInterface()
    

    self.groups = {}
    self.elements = {}

    self.groups.other = ElementGroup.new()
    self.groups.position = ElementGroup.new()
    self.groups.direction = ElementGroup.new()
    self.groups.buttons = ElementGroup.new()

    self.elements.title = DisplayElement.new()
    self.groups.other:addElement(self.elements.title)

    self.elements.positionFrame = DisplayElement.new()
    self.elements.positionTitle = DisplayElement.new()
    self.elements.positionDesctiption = DisplayElement.new()
    self.elements.positionX = DisplayElement.new()
    self.elements.positionZ = DisplayElement.new()
    self.elements.targetName = DisplayElement.new()
    self.groups.position:addElement(self.elements.positionFrame)
    self.groups.position:addElement(self.elements.positionTitle)
    self.groups.position:addElement(self.elements.positionDesctiption)
    self.groups.position:addElement(self.elements.positionX)
    self.groups.position:addElement(self.elements.positionZ)
    self.groups.position:addElement(self.elements.targetName)

    self.elements.directionFrame = DisplayElement.new()
    self.elements.directionTitle = DisplayElement.new()
    self.elements.direction = DisplayElement.new()
    self.groups.direction:addElement(self.elements.directionFrame)
    self.groups.direction:addElement(self.elements.directionTitle)
    self.groups.direction:addElement(self.elements.direction)

    self.elements.exitButton = DisplayElement.new()
    self.elements.getPositionButton = DisplayElement.new()
    self.groups.buttons:addElement(self.elements.exitButton)
    self.groups.buttons:addElement(self.elements.getPositionButton)
end

function CompassPackage:initStateInitialized()
    self.groups.other:setPosition(1, 1)
    self.groups.position:setPosition(23, 4)
    self.groups.direction:setPosition(2, 4)
    self.groups.buttons:setPosition(1, 9)

    self.elements.title:setPosition(2, 1)
    self.elements.title:setWidth(39)
    self.elements.title:setHeight(1)
    self.elements.title.drawFrame = true
    self.elements.title:setContent({
        "COMPASS"
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
        "---"
    })

    self.elements.positionZ:setPosition(3, 4)
    self.elements.positionZ:setWidth(16)
    self.elements.positionZ:setHeight(1)
    self.elements.positionZ:setContent({
        "---"
    })

    self.elements.targetName:setPosition(1, 6)
    self.elements.targetName:setWidth(18)
    self.elements.targetName:setHeight(2)
    self.elements.targetName.drawFrame = true
    self.elements.targetName:setContent({
        "Target:",
        "---"
    })

    self.elements.directionFrame:setPosition(1, 1)
    self.elements.directionFrame:setWidth(18)
    self.elements.directionFrame:setHeight(3)
    self.elements.directionFrame.drawFrame = true

    self.elements.directionTitle:setPosition(1, 1)
    self.elements.directionTitle:setWidth(18)
    self.elements.directionTitle:setHeight(1)
    self.elements.directionTitle.drawFrame = true
    self.elements.directionTitle:setContent({
        "Direction:"
    })

    self.elements.direction:setPosition(2, 3)
    self.elements.direction:setWidth(16)
    self.elements.direction:setHeight(1)
    self.elements.direction:setContent({
        "---"
    })

    self.elements.exitButton:setPosition(1, 1)
    self.elements.exitButton:setWidth(6)
    self.elements.exitButton:setHeight(3)
    self.elements.exitButton.normal = {fg = 0xFF0000, bg = 0x700000}
    self.elements.exitButton.active = {fg = 0x000000, bg = 0xFF0000}
    self.elements.exitButton:setContent({
        "",
        "EXIT"
    })

    self.elements.getPositionButton:setPosition(7,1)
    self.elements.getPositionButton:setWidth(14)
    self.elements.getPositionButton:setHeight(3)
    self.elements.getPositionButton.normal = {fg = 0x9090FF, bg = 0x0000F0}
    self.elements.getPositionButton.active = {fg = 0x000000, bg = 0x9090FF}
    self.elements.getPositionButton:setContent({
        "",
        "GET POSITION"
    })
end

function CompassPackage:initStateOperational()
    

    self.functions.updateDirectionThread = function()
        while self.session.threadRunning do
            local _, direction = self.functions.getDirection()
            _, direction = self.functions.directionToString(direction)
            self.elements.direction:setContent({direction})
            self.elements.direction:drawNormal(self.resources.gpu)
            os.sleep(1)
        end
    end

    local program = self
    self.elements.getPositionButton.action = (function(self, displayMatrix)
        program.elements.positionZ:setContent({
            "downloading"
        })
        program.elements.positionX:setContent({
            "downloading"
        })
        program.elements.targetName:setContent({
            "Target:",
            program.resources.userName
        })
        program.elements.positionZ:drawNormal(displayMatrix.gpu)
        program.elements.positionX:drawNormal(displayMatrix.gpu)
        program.elements.targetName:drawNormal(displayMatrix.gpu)

        local success, response = program.functions.getPosition()

        if success then
            program.elements.positionZ:setContent({
                tostring(response.z)
            })
            program.elements.positionX:setContent({
                tostring(response.x)
            })
        else
            program.elements.positionZ:setContent({
                "---"
            })
            program.elements.positionX:setContent({
                "---"
            })
        end

        program.elements.positionZ:drawNormal(displayMatrix.gpu)
        program.elements.positionX:drawNormal(displayMatrix.gpu)
        
        self:drawNormal(displayMatrix.gpu)
    end)

    self.elements.exitButton.action = (function(self, displayMatrix)
        displayMatrix:exit()
        program.session.threadRunning = false
    end)


    self.displayMatrix = DisplayMatrix.new(self.resources.gpu)
    for _, group in pairs(self.groups) do
        self.displayMatrix:addGroup(group)
    end
end

function CompassPackage:initStateRunning()

    self.displayMatrix:setDims(41, 11)
    self.displayMatrix:draw()
    self.session.threadRunning = true
    thread.create(self.functions.updateDirectionThread)
    self.displayMatrix:main()
end

function CompassPackage:revertStateRunning()
    self.session.threadRunning = false
end

return CompassPackage