local ProgramPackage = {}
ProgramPackage.__index = ProgramPackage

function ProgramPackage:description()
    return "NO NAME", "No description."
end

function ProgramPackage.new(terminalLevel, resources)
    local self = setmetatable({}, ProgramPackage)
    self.levelMap = {functional = 1, session = 2, memory = 3, initialized = 4, operational = 5, running = 6}
    if type(terminalLevel) == "string" then
        self.terminalLevel = self.levelMap[terminalLevel]
        if self.terminalLevel == nil then
            error("Invalid level: " .. terminalLevel)
        end
    else
        self.terminalLevel = terminalLevel
    end
    self.resources = resources

    self.level = 0

    self.functions = {}
    self.session = {}
    self.groups = {}
    self.elements = {}
    self.displayMatrix = nil
    self.thread = nil
    self.error = nil

    self.requiredResources = {}

    self.depNames = {{}, {}, {}, {}, {}, {}}
    self.dep = {}


    return self
end

function ProgramPackage:levelToString()
    if self == nil or self.level == nil or self.level == 0 then
        return "not loaded"
    elseif self.level == 1 then
        return "functional"
    elseif self.level == 2 then
        return "session"
    elseif self.level == 3 then
        return "interface"
    elseif self.level == 4 then
        return "initialized"
    elseif self.level == 5 then
        return "operational"
    elseif self.level == 6 then
        return "running"
    else
        return "unknown"
    end
end

-- LEVEL MEANINGS:
-- 1: functional - defining only independent functions, that mostly help performing operations on the device like reading message from certain server, in this state program can function as a library
-- 2: session - defining program variables that are not dependent on the interface so they can store program state
-- 3: interface - defining interface variables and overal memory
-- 4: initialized - loading interface elements (spacing, colors, content)
-- 5: operational - initializing interface elements behavior in the context of the program
-- 6: running - setting filepatchs, loading files and starting displayMatrix

function ProgramPackage:run()

    if not self:checkRequiredResources() then
        return false
    end

    local initializationShedule = {
        self.initStateFunctional,
        self.initStateSession,
        self.initStateInterface,
        self.initStateInitialized,
        self.initStateOperational,
        self.initStateRunning
    }
    while self.level + 1 <= self.terminalLevel do
        if not self:loadDependencies(self.level + 1) then
            return false
        end

        local success, errorMessage = pcall(initializationShedule[self.level + 1], self)
        if not success then
            self.error = "LEVEL " .. self.level + 1 .. ": " .. errorMessage
            return  false
        end
        self.level = self.level + 1
    end

    return true
end

function ProgramPackage:revert(toLevel)
    if type(toLevel) == "string" then
        toLevel = self.levelMap[toLevel]
    end
    toLevel = toLevel or 0

    local revertShedule = {
        self.revertStateFunctional,
        self.revertStateSession,
        self.revertStateInterface,
        self.revertStateInitialized,
        self.revertStateOperational,
        self.revertStateRunning
    }

    while self.level > toLevel do
        local success, errorMessage = pcall(revertShedule[self.level], self)
        if not success then
            self.error = "LEVEL " .. self.level .. ": " .. errorMessage
            return false
        end
        self:unloadDependencies(self.level)
        self.level = self.level - 1
    end
    return true
end

function ProgramPackage:loadDependencies(level)
    for index, name in pairs(self.depNames[level]) do
        if self.dep[name] == nil then
            local success, returnValue = pcall(require, "Programs." .. name)
            if not success or returnValue == nil then
                self.error = "ERROR LOADING DEPENDENCY FOR LEVEL " .. level .. " - " .. name .. ": " .. returnValue
                return false
            end
            local lib =  returnValue.new("functional", self.resources)
            success = lib:run()
            if not success then
                self.error = "ERROR INITIALIZING DEPENDENCY FOR LEVEL " .. level .. " - " .. name .. ": " .. lib.error
                return false
            end

            self.dep[name] = lib.functions
        else
            table.remove(self.depNames[level], index)
        end
    end
    return true
end

function ProgramPackage:unloadDependencies(level)
    for _, name in pairs(self.depNames[level]) do
        self.dep[level][name] = nil
    end
end

function ProgramPackage:checkRequiredResources()
    for _, name in pairs(self.requiredResources) do
        if self.resources[name] == nil then
            self.error = "MISSING RESOURCE: " .. name
            return false
        end
    end
    return true
end

function ProgramPackage:suppressToBackground()
    self.displayMatrix:exit()
    self.groups = {}
    self.elements = {}
    for i = 3, 6 do
        self:unloadDependencies(i)
    end
end


function ProgramPackage:initStateFunctional()
    error("ProgramPackage:initStateFunctional() must be overridden")
end

function ProgramPackage:initStateSession()
    error("ProgramPackage:initStateSession() must be overridden")
end

function ProgramPackage:initStateInterface()
    error("ProgramPackage:initStateInterface() must be overridden")
end

function ProgramPackage:initStateInitialized()
    error("ProgramPackage:initStateInitialized() must be overridden")
end

function ProgramPackage:initStateOperational()
    error("ProgramPackage:initStateOperational() must be overridden")
end

function ProgramPackage:initStateRunning()
    error("ProgramPackage:initStateRunning() must be overridden")
end


function ProgramPackage:revertStateFunctional()
    self.functions = {}
end

function ProgramPackage:revertStateSession()
    self.session = {}
end

function ProgramPackage:revertStateInterface()
    self.groups = {}
    self.elements = {}
end

function ProgramPackage:revertStateInitialized()
end

function ProgramPackage:revertStateOperational()
    self.displayMatrix = nil
end

function ProgramPackage:revertStateRunning()
end


return ProgramPackage