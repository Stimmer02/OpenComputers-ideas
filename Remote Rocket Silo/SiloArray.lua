local Silo = require("Silo")

local thread = require("thread")

local SiloArray = {}
SiloArray.__index = SiloArray

function SiloArray.new(databaseFile)
    local self = setmetatable({}, SiloArray)
    local startTime = os.time()
    self.silos = Silo.loadFromDatabase(databaseFile)
    self.storageScanningTime = os.time() - startTime
    return self
end

function SiloArray:scanStorage()
    for _, silo in pairs(self.silos) do
        silo.magazine:checkIfLoaded()
        silo.magazine:scanStorage()
    end
end

function SiloArray:getMissiles()
    local missiles = {}
    for _, silo in pairs(self.silos) do
        local siloMissiles = silo.magazine:getMissiles()
        for missileName, count in pairs(siloMissiles) do
            if missiles[missileName] == nil then
                missiles[missileName] = 0
            end
            missiles[missileName] = missiles[missileName] + count
        end
    end
    return missiles
end

-- function SiloArray:getSiloWithMostMissiles(missileName)
--     local siloWithMostMissiles = nil
--     local mostMissiles = 0
--     for _, silo in pairs(self.silos) do
--         local missileCount = silo.magazine:getMissiles()[missileName]
--         if missileCount ~= nil and missileCount > mostMissiles then
--             siloWithMostMissiles = silo
--             mostMissiles = missileCount
--         end
--     end
--     return siloWithMostMissiles
-- end

function SiloArray:sortSilosByMissileCount(missileName, reverse, onlyIdle)
    reverse = reverse or false
    onlyIdle = onlyIdle or false
    local siloArray = {}
    local totalCount = 0
    if onlyIdle then
        for ID, silo in pairs(self.silos) do
            local missileCount = silo.magazine:getMissiles()[missileName]
            if missileCount ~= nil and silo.inUse == false then
                table.insert(siloArray, {ID = ID, count = missileCount})
                totalCount = totalCount + missileCount
            end
        end
    else
        for ID, silo in pairs(self.silos) do
            local missileCount = silo.magazine:getMissiles()[missileName]
            if missileCount ~= nil then
                table.insert(siloArray, {ID = ID, count = missileCount})
                totalCount = totalCount + missileCount
            end
        end
    end
    if reverse == false then
        table.sort(siloArray, function(a, b)
            return a.count > b.count
        end)
    else
        table.sort(siloArray, function(a, b)
            return a.count < b.count
        end)
    end
    

    return siloArray, totalCount
end


function SiloArray:launchSingleMissile(missileName, x, z)
    local silosID, totalCount = self:sortSilosByMissileCount(missileName, false, true)

    if totalCount == 0 then
        return false, "No missile found or all silos are busy"
    end
    local silo = self.silos[silosID[1].ID]
    local success, error = silo:safeLaunch(x, z, missileName)
    if not success then
        if error == "Target is too close" then
            for i = 2, #silosID do
                silo = self.silos[silosID[i].ID]
                if silo:checkDistance(x, z) then
                    return silo:safeLaunch(x, z, missileName)
                end
            end
            return false, error
        else
            return false, error
        end
    end
    return true
end

function SiloArray:launchSalvoFromSilo(siloID, missileName, centerX, centerZ, count, spreadFunction, spreadFunctionIteratorArray)
    spreadFunction = spreadFunction or function(x, z, launchNumber) return x, z end
    local silo = self.silos[siloID]
    if silo == nil then
        return 0, "Silo " .. siloID .. " not found"
    end
    
    if spreadFunctionIteratorArray == nil then
        silo:openHatch()
        for i = 1, count do
            local x, z = spreadFunction(centerX, centerZ, i)
            print("Launch " .. i .. " at " .. x .. ", " .. z)
            local success, error = silo:safeLaunch(x, z, missileName)
            if not success then
                silo:closeHatch()
                return i-1, error
            end
        end
    elseif #spreadFunctionIteratorArray < count then
        return 0, "spreadFunctionIteratorArray is smaller than the launch count"
    else
        silo:openHatch()
        for i = 1, count do
            local x, z = spreadFunction(centerX, centerZ, spreadFunctionIteratorArray[i])
            local success, error = silo:safeLaunch(x, z, missileName)
            if not success then
                silo:closeHatch()
                return i-1, error
            end
        end
    end

    silo:closeHatch()
    return count
end

function SiloArray:launchSalvo(missileName, centerX, centerZ, count, spreadFunction)
    local silos, missileCount = self:sortSilosByMissileCount(missileName, true)
    if missileCount == 0 then
        return 0, {"No missile found of type " .. missileName}
    end

    if #silos == 1 then
        local count, error = self:launchSalvoFromSilo(silos[1].ID, missileName, centerX, centerZ, count, spreadFunction)
        return count, {error}
    end

    if missileCount < count then
        count = missileCount
    end

    local launchsToAssign = count

    local threadLaunchCount = {}
    local threadArray = {}
    local threadSuccess = {}
    local threadErrors = {}

    local successCount = 0
    local errors = {}

    if #silos >= count then
        for i = 1, count do
            threadArray[i] = thread.create(function()
                threadSuccess[i], threadErrors[i] = self:launchSalvoFromSilo(silos[#silos - i + 1].ID, missileName, centerX, centerZ, 1, spreadFunction, {i})
            end)
        end

    else

        for i = 1 , #silos - 1 do
            threadLaunchCount[i] = math.floor(launchsToAssign / (#silos - (i - 1)))
            if threadLaunchCount[i] > silos[i].count then
                threadLaunchCount[i] = silos[i].count
            end
            launchsToAssign = launchsToAssign - threadLaunchCount[i]
        end
        threadLaunchCount[#silos] = launchsToAssign


        if spreadFunction == nil then
            for i = #silos, 1, -1 do
                threadArray[i] = thread.create(function()
                    threadSuccess[i], threadErrors[i] = self:launchSalvoFromSilo(silos[i].ID, missileName, centerX, centerZ, threadLaunchCount[i])
                end)
            end
        else
            local spreadFunctionIteratorArray = {}
            for i = 1, #silos do
                spreadFunctionIteratorArray[i] = {}
            end
            local silosWithMissiles = {}
            for i = 1, #silos do
                silosWithMissiles[i] = i
            end

            local iterator = 1
            for i = 1, count do
                local siloIndex = silosWithMissiles[iterator]
                table.insert(spreadFunctionIteratorArray[siloIndex], i)
                if #spreadFunctionIteratorArray[siloIndex] == threadLaunchCount[siloIndex] then
                    table.remove(silosWithMissiles, iterator)
                elseif iterator < #silosWithMissiles then
                    iterator = iterator + 1
                else
                    iterator = 1
                end
            end

            for i = #silos, 1, -1 do
                threadArray[i] = thread.create(function()
                    threadSuccess[i], threadErrors[i] = self:launchSalvoFromSilo(silos[i].ID, missileName, centerX, centerZ, threadLaunchCount[i], spreadFunction, spreadFunctionIteratorArray[i])
                end)
                -- threadSuccess[i], threadErrors[i] = self:launchSalvoFromSilo(silos[i].ID, missileName, centerX, centerZ, threadLaunchCount[i], spreadFunction, spreadFunctionIteratorArray[i])
            end
        end
    end


    for i = 1, #threadArray do
        threadArray[i]:join()
    end

    for i = 1, #threadArray do
        if threadSuccess[i] ~= nil then
            successCount = successCount + threadSuccess[i]

            if threadErrors[i] ~= nil then
                table.insert(errors, "Silo " .. silos[i].ID .. ": " .. threadErrors[i])
            end
        else
            table.insert(errors, "Silo " .. silos[i].ID .. ": " .. "Thread error")
        end
    end


    return successCount, errors
end

function SiloArray:launchSalvo_random(missileName, centerX, centerZ, count, radius)
    radius = radius or 40
    local spreadFunction = function(x, z, launchNumber)
        local angle = math.random() * 2 * math.pi
        local distance = math.random() * radius
        return x + distance * math.cos(angle), z + distance * math.sin(angle)
    end
    return self:launchSalvo(missileName, centerX, centerZ, count, spreadFunction)
end

function SiloArray:launchSalvo_circle(missileName, centerX, centerZ, count, radius)
    radius = radius or 40
    local spreadFunction = function(x, z, launchNumber)
        local angle = launchNumber * 2 * math.pi / count
        return x + radius * math.cos(angle), z + radius * math.sin(angle)
    end
    return self:launchSalvo(missileName, centerX, centerZ, count, spreadFunction)
end

function SiloArray:launchSalvo_line(missileName, centerX, centerZ, count, distance)
    distance = distance or 40
    local spreadFunction = function(x, z, launchNumber)
        return x, z + (launchNumber - (count - 1) / 2) * distance
    end
    return self:launchSalvo(missileName, centerX, centerZ, count, spreadFunction)
end

function SiloArray:launchSalvo_rectangle(missileName, centerX, centerZ, sideX, sideZ, spacing)
    sideX = sideX or 3
    sideZ = sideZ or 3
    spacing = spacing or 30
    local centralLaunchNumber = math.floor((sideX * sideZ + 1) / 2)
    local middleRow = math.floor(sideZ / 2)
    local spreadFunction = function(x, z, launchNumber)
        local zModifier = math.floor((launchNumber - 1) / sideX) - middleRow
        launchNumber = launchNumber - centralLaunchNumber
        local xModifier = launchNumber - sideX  * zModifier
        if sideZ % 2 == 0 then
            zModifier = zModifier + 0.5
        end

        if sideX % 2 == 0 then
            xModifier = xModifier + 0.5
        end


        return x + xModifier * spacing, z + zModifier * spacing
    end
    
    return self:launchSalvo(missileName, centerX, centerZ, sideX * sideZ, spreadFunction)
end

function SiloArray:launchSalvo_square(missileName, centerX, centerZ, count, spacing)
    return self:launchSalvo_rectangle(missileName, centerX, centerZ, count, count, spacing)
end

return SiloArray