local comp = require("component")
local os = require("os")
local side = require("sides")
local thread = require("thread")

local SiloMagazine = require("SiloMagazine")

local Silo = {}
Silo.__index = Silo

function Silo.new(launchpadAddr, loaderAddr, hatchAddr, launchpadPositionX, launchpadPositionZ)
    local self = setmetatable({}, Silo)

    if launchpadAddr == nil then
        error("Silo.new: Missing required component - launchpad")
    elseif loaderAddr == nil then
        error("Silo.new: Missing required component - transposer")
    elseif hatchAddr == nil then
            error("Silo.new: Missing required component - redstone")
    end
    
    self.launchpad = comp.proxy(launchpadAddr)
    self.loader = comp.proxy(loaderAddr)
    self.hatch = comp.proxy(hatchAddr)

    if self.launchpad and self.launchpad.type ~= "launchpad" then
        error("Silo.new: launchpad argument does not contial a launchpad address")
    elseif self.loader and self.loader.type ~= "transposer" then
        error("Silo.new: loader argument does not contain a loader address")
    elseif self.hatch and self.hatch.type ~= "redstone" then
        error("Silo.new: hatch argument does not contain a hatch address")
    end
    
    self.magazine = SiloMagazine.new(self.loader)
    self.target = {x = 0, z = 0}
    self.hatchOpen = nil
    self.minimumDistance = 100
    self.chathOperationTime = 4
    self.launchTime = 5
    self.chathOperatingThread = nil
    self.inUse = false
    self:closeHatch()

    if launchpadPositionX == nil or launchpadPositionZ == nil then
        error("Silo.new: Missing required arguments - launchpadPositionX, launchpadPositionZ")
    end
    self.launchpadPosition = {x = launchpadPositionX, z = launchpadPositionZ}

    return self
end

function Silo:getLastTarget()
    return self.target
end

function Silo:setTarget(x, z)
    if not self:checkDistance(x, z) then
        return false, "Target is too close"
    end

    self.target.x = x
    self.target.z = z
    local success = self.launchpad.setTarget(x, z)
    if not success then
        return false, "Failed to set target"
    end

    return true
end

function Silo:load(missileName)
    return self.magazine:load(missileName)
end

local function launch(self)
    self.launchpad.launch()
    self.magazine.loaded = ""
end

function Silo:openHatch()
    self:waitForHatch()
    local prev = self.hatch.setOutput(side.up, 15)
    if prev == 0 then 
        self.chathOperatingThread = thread.create(function()
            os.sleep(self.chathOperationTime)
        end)
    end
    self.hatchOpen = true
end

function Silo:closeHatch()
    self:waitForHatch()
    local prev = self.hatch.setOutput(side.up, 0)
    if prev ~= 0 then 
        self.chathOperatingThread = thread.create(function()
            os.sleep(self.chathOperationTime)
        end)
    end
    self.hatchOpen = false
end

function Silo:closeHatchAfter(time)
    self:waitForHatch()
    self.chathOperatingThread = thread.create(function()
        os.sleep(time)
        local prev = self.hatch.setOutput(side.up, 0)
        if prev ~= 0 then 
            os.sleep(self.chathOperationTime)
        end
        self.hatchOpen = false
    end)
end

function Silo:waitForHatch()
    if self.chathOperatingThread ~= nil then
        self.chathOperatingThread:join()
        self.chathOperatingThread = nil
    end
end

function Silo:makeSiloBusy(time)
    self:waitForHatch()
    self.chathOperatingThread = thread.create(function()
        os.sleep(time)
    end)
end

function Silo:checkDistance(x, z)
    local distance = math.sqrt((self.launchpadPosition.x - x)^2 + (self.launchpadPosition.z - z)^2)
    if distance < self.minimumDistance then
        return false
    end
    return true
end

function Silo:safeLaunch(x, z, missileName)
    self.inUse = true
    local success, error
    success, error = self:setTarget(x, z)
    if not success then
        self.inUse = false
        return false, error
    end

    success, error = self:load(missileName)
    if not success then
        self.inUse = false
        return false, error
    end

    if self.hatchOpen then
        self:waitForHatch()
        launch(self)
        self:makeSiloBusy(self.launchTime)
    else
        self:openHatch()
        self:waitForHatch()
        launch(self)
        self:closeHatchAfter(self.chathOperationTime)
    end
    self:load(missileName)
    self.inUse = false
    return true
end



function Silo.appendSiloDatabase(filename, launchpadPositionX, launchpadPositionZ)
    -- file: index lauchpadPositionX launchpadPositionZ launchpadAddr loaderAddr hatchAddr
    local file = io.open(filename, "r")
    if file == nil then
        error("Silo.appendSiloDatabase: Failed to open file ".. filename .." to read")
    end

    local launchpadAddr = {}
    local loaderAddr = {}
    local hatchAddr = {}
    local indexes = {}

    for line in file:lines() do
        local values = {}
        for value in line:gmatch("%S+") do
            table.insert(values, value)
        end

        if #values >= 6 then
            local index = tonumber(values[1])
            if index == nil then
                error("Silo.appendSiloDatabase: Failed to read index from line: " .. line)
            end
            launchpadAddr[values[4]] = index
            loaderAddr[values[5]] = index
            hatchAddr[values[6]] = index
            indexes[index] = true
        end
    end
    file:close()

    table.sort(indexes)
    local lowestFreeIndex = nil
    for i = 1, #indexes do
        if indexes[i] ~= true then
            lowestFreeIndex = i
            break
        end
    end
    if lowestFreeIndex == nil then
        lowestFreeIndex = #indexes + 1
    end


    local newLaunchpadAddr = nil
    local newLoaderAddr = nil
    local newHatchAddr = nil


    for address, _ in pairs(comp.list()) do
        if comp.proxy(address).type == "launchpad" then
            if launchpadAddr[address] == nil then
                if newLaunchpadAddr ~= nil then
                    error("Silo.appendSiloDatabase: Multiple not registered launchpads found")
                end
                newLaunchpadAddr = address
            end

        elseif comp.proxy(address).type == "transposer" then
            if loaderAddr[address] == nil then
                if newLoaderAddr ~= nil then
                    error("Silo.appendSiloDatabase: Multiple not registered loaders found")
                end
                newLoaderAddr = address
            end

        elseif comp.proxy(address).type == "redstone" then
            if hatchAddr[address] == nil then
                if newHatchAddr ~= nil then
                    error("Silo.appendSiloDatabase: Multiple not registered hatches found")
                end
                newHatchAddr = address
            end
        end
    end

    if newLaunchpadAddr == nil then
        error("Silo.appendSiloDatabase: No unregistered launchpad found")
    elseif newLoaderAddr == nil then
        error("Silo.appendSiloDatabase: No unregistered loader found")
    elseif newHatchAddr == nil then
        error("Silo.appendSiloDatabase: No unregistered hatch found")
    end


    file = io.open(filename, "a")
    if file == nil then
        error("Silo.appendSiloDatabase: Failed to open file ".. filename .." to append")
    end

    file:write(lowestFreeIndex .. " " .. launchpadPositionX .. " " .. launchpadPositionZ .. " " .. newLaunchpadAddr .. " " .. newLoaderAddr .. " " .. newHatchAddr .. "\n")

    file:close()
end

function Silo.loadFromDatabase(filename)
    local file = io.open(filename, "r")
    if file == nil then
        error("Silo.createFromDatabase: Failed to open file ".. filename .." to read")
    end

    local siloArray = {}
    for line in file:lines() do
        local values = {}
        for value in line:gmatch("%S+") do
            table.insert(values, value)
        end
        if #values >= 6 then
            local silo = Silo.new(values[4], values[5], values[6], tonumber(values[2]), tonumber(values[3]))
            siloArray[tonumber(values[1])] = silo
        end
    end
    file:close()

    return siloArray
end

return Silo