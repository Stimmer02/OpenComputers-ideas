local DisplayMatrix = require("DisplayMatrix")
local DisplayMatrixTemplates = require("DisplayMatrixTemplates")
local DisplayElement = require("DisplayElement")
local ElementGroup = require("ElementGroup")
local SecureConnection = require("SecureConnection")

local computer = require("computer")
local fs = require("filesystem")
local comp = require("component")
local os = require("os")
local thread = require("thread")

local ProgramManager = {}
ProgramManager.__index = ProgramManager
function ProgramManager.new(rootPath)
    local self = setmetatable({}, ProgramManager)

    self.rootPath = rootPath
    self.programs = {}
    self.resources = {}
    self.programBackgroundLevel = "session"

    self.displayMatrix = nil
    self.list = nil
    self.statusBar = nil
    self.actionBar = nil
    self.statusElements = {}
    self.buttons = {}
    self.update = true
    self.updateThread = nil
    self.updateThreadsRunning = false

    self:gatherResources()
    self:readPrograms()
    self:buildInterface()
    self:updateProgramList()

    return self
end

function ProgramManager:buildInterface()
    self.displayMatrix = DisplayMatrix.new(self.resources.gpu)

    local width, height = self.resources.gpu.getResolution()
    local elementCount = math.floor((height - 5) / 4)

    local listBuilder = DisplayMatrixTemplates.new("list")
    listBuilder:setType("no_select")
    listBuilder.elementHeight = 3
    listBuilder.elementWidth = width - 4
    listBuilder.numberOfVisibleElements = elementCount
    listBuilder.drawFrameAroundEveryElement = true
    self.list = listBuilder:build()
    self.list.group:setPosition(2, 3)
    self.list.onListInteractionFunction = (function(list, elementIndex, element, displayMatrix)
        self:executeProgram(elementIndex)
    end)

    self.statusBar = ElementGroup.new()
    self.statusElements.background = DisplayElement.new()
    self.statusElements.clock = DisplayElement.new()
    self.statusElements.batteryDescription = DisplayElement.new()
    self.statusElements.batteryLevel = DisplayElement.new()
    self.statusElements.memoryDescription = DisplayElement.new()
    self.statusElements.memoryLevel = DisplayElement.new()

    self.statusBar:addElement(self.statusElements.background)
    self.statusBar:addElement(self.statusElements.clock)
    self.statusBar:addElement(self.statusElements.batteryDescription)
    self.statusBar:addElement(self.statusElements.batteryLevel)
    self.statusBar:addElement(self.statusElements.memoryDescription)
    self.statusBar:addElement(self.statusElements.memoryLevel)

    self.actionBar = ElementGroup.new()
    self.buttons.shutdown = DisplayElement.new()
    self.buttons.reboot = DisplayElement.new()
    self.buttons.closeApps = DisplayElement.new()

    self.actionBar:addElement(self.buttons.shutdown)
    self.actionBar:addElement(self.buttons.reboot)
    self.actionBar:addElement(self.buttons.closeApps)


    self.statusBar:setPosition(1, 1)
    self.statusBar:setNormalColors({fg = 0x000000, bg = 0xFFFFFF}, true)

    self.statusElements.background:setPosition(1, 1)
    self.statusElements.background:setWidth(width)
    self.statusElements.background:setHeight(1)

    self.statusElements.clock:setPosition(2, 1)
    self.statusElements.clock:setWidth(5)
    self.statusElements.clock:setHeight(1)

    self.statusElements.batteryDescription:setPosition(width-12, 1)
    self.statusElements.batteryDescription:setWidth(8)
    self.statusElements.batteryDescription:setHeight(1)
    self.statusElements.batteryDescription:setContent({"Battery:"})

    self.statusElements.batteryLevel:setPosition(width-4, 1)
    self.statusElements.batteryLevel:setWidth(4)
    self.statusElements.batteryLevel:setHeight(1)

    self.statusElements.memoryDescription:setPosition(width-24, 1)
    self.statusElements.memoryDescription:setWidth(7)
    self.statusElements.memoryDescription:setHeight(1)
    self.statusElements.memoryDescription:setContent({"Memory:"})

    self.statusElements.memoryLevel:setPosition(width-17, 1)
    self.statusElements.memoryLevel:setWidth(4)
    self.statusElements.memoryLevel:setHeight(1)


    self.actionBar:setPosition(1, elementCount * 4 + 3)

    self.buttons.shutdown:setPosition(1, 1)
    self.buttons.shutdown:setWidth(8)
    self.buttons.shutdown:setHeight(3)
    self.buttons.shutdown.normal = {fg = 0xFF0000, bg = 0x700000}
    self.buttons.shutdown.active = {fg = 0x000000, bg = 0xFFFFFF}
    self.buttons.shutdown.centeredWidth = false
    self.buttons.shutdown:setContent({
        "",
        "  ⏼"
    })
    self.buttons.shutdown.action = (function()
        self:shutdown()
    end)

    self.buttons.reboot:setPosition(10, 1)
    self.buttons.reboot:setWidth(8)
    self.buttons.reboot:setHeight(3)
    self.buttons.reboot.normal = {fg = 0xFF0000, bg = 0x700000}
    self.buttons.reboot.active = {fg = 0x000000, bg = 0xFFFFFF}
    self.buttons.reboot.centeredWidth = false
    self.buttons.reboot:setContent({
        "",
        "  🗘"
    })
    self.buttons.reboot.action = (function()
        self:reboot()
    end)

    self.buttons.closeApps:setPosition(19, 1)
    self.buttons.closeApps:setWidth(16)
    self.buttons.closeApps:setHeight(3)
    self.buttons.closeApps.normal = {fg = 0x000000, bg = 0xFFFFFF}
    self.buttons.closeApps.active = {fg = 0xFF0000, bg = 0xFFFFFF}
    self.buttons.closeApps:setContent({
        "",
        "CLEAR MEMORY"
    })
    self.buttons.closeApps.action = (function()
        self:closeApps()
    end)


    self.displayMatrix:addGroup(self.list.group)
    self.displayMatrix:addGroup(self.statusBar)
    self.displayMatrix:addGroup(self.actionBar)
end

function ProgramManager:readPrograms()
    for programFile, _ in fs.list(self.rootPath) do
        local programPath = fs.concat(self.rootPath, programFile)
        print("Loading program: " .. programPath)
        if fs.exists(programPath) then
            if programPath[1] == "/" then
                programPath = string.sub(programPath, 2)
            end
            if string.sub(programPath, 1, 5) == "home/" then
                programPath = string.sub(programPath, 6)
            end
            programPath = string.gsub(programPath, ".lua", "")
            programPath = string.gsub(programPath, "/", ".")
            local program = require(programPath)
            local name, description = program.description()
            table.insert(self.programs, {program = nil, name = name, description = description, path = programPath, error = nil})
            print(name .. " - " .. description)
        end
    end
end

function ProgramManager:gatherResources()
    local resourceNames = {"gpu", "tunnel", "navigation"}
    for _, resourceName in ipairs(resourceNames) do
        self.resources[resourceName] = comp[resourceName]
    end

    if self.resources.gpu == nil then
        error("No GPU found")
    end

    if self.resources.tunnel then
        self.resources.connection = SecureConnection.new("userDatabase.txt")
    end

    self.resources.userName = "stimmer02"
end


function ProgramManager:run()
    self.displayMatrix:draw()
    self:updateStatus()
    self:startUpdateThread()
    self.displayMatrix:main()
    self:stopUpdateThread()
end

function ProgramManager:updateProgramList()
    local programListContent = {}
    self.width = self.resources.gpu.getResolution()
    self.width = self.width - 4
    for _, program in ipairs(self.programs) do
        local state = ""
        if program.error then
            state = string.sub(program.error, 1, self.width)
        elseif program.program then
            state = "state: " .. program.program:levelToString()
        else
            state = "state: not loaded"
        end
        table.insert(programListContent, {program.name, string.sub(program.description, 1, self.width), state})
    end
    self.list:setContent(programListContent)
    self.list.selectedMissileIndex = nil
    self.list.topElementIndex = 1
end

function ProgramManager:executeProgram(programNumber)
    self.update = false
    local selectedProgram = self.programs[programNumber]
    if selectedProgram.program == nil then
        selectedProgram.program = require(selectedProgram.path).new("running", self.resources)
    end
    selectedProgram.error = nil
    selectedProgram.program:run()
    if selectedProgram.program.error then
        selectedProgram.error = selectedProgram.program.error
        selectedProgram.program = nil
        local errorFile = io.open("/tmp/error.txt", "w")
        if errorFile then
            errorFile:write(selectedProgram.error)
            errorFile:close()
        end
    else
        selectedProgram.program:revert(self.programBackgroundLevel)
    end
    local state = ""
    if selectedProgram.error then
        state = string.sub(selectedProgram.error, 1, self.width)
    else
        state = "state: " .. selectedProgram.program:levelToString()
    end
    self.list.elementsContent[programNumber][3] = state
    self.displayMatrix:draw()
    self.update = true
    self:updateStatus()
end

function ProgramManager:updateClock()
    local time = os.date("%H:%M")
    self.statusElements.clock.content[1] = time
    self.statusElements.clock:drawNormal(self.resources.gpu)
end

function ProgramManager:updateBattery()
    local batteryLevel = math.ceil(computer.energy() / computer.maxEnergy() * 100)
    self.statusElements.batteryLevel.content[1] = string.format("%3d%%", batteryLevel)
    self.statusElements.batteryLevel:drawNormal(self.resources.gpu)
end

function ProgramManager:updateMemory()
    local totalMemory = computer.totalMemory()
    local memoryLevel = math.ceil((totalMemory - computer.freeMemory()) / totalMemory * 100)
    self.statusElements.memoryLevel.content[1] = string.format("%3d%%", memoryLevel)
    self.statusElements.memoryLevel:drawNormal(self.resources.gpu)
end

function ProgramManager:updateStatus()
    self:updateClock()
    self:updateBattery()
    self:updateMemory()
end

local function updateThread(self)
    while self.updateThreadsRunning do
        if self.update then
            self:updateStatus()
        end
        os.sleep(1)
    end
end


function ProgramManager:startUpdateThread()
    self.updateThreadsRunning = true
    self.updateThread = thread.create(updateThread, self)
end

function ProgramManager:stopUpdateThread()
    self.updateThreadsRunning = false
    self.updateThread:join()
end

function ProgramManager:shutdown()
    self.displayMatrix:exit()
    self:stopUpdateThread()
    computer.shutdown()
end

function ProgramManager:reboot()
    self.displayMatrix:exit()
    self:stopUpdateThread()
    computer.shutdown(true)
end

function ProgramManager:closeApps()
    for _, program in ipairs(self.programs) do
        if program.program then
            program.program = nil
            program.error = nil
        end
    end
    self:updateProgramList()
    self.displayMatrix:draw()
end


return ProgramManager