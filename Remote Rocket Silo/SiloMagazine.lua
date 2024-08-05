local SiloMagazine = {}
SiloMagazine.__index = SiloMagazine

function SiloMagazine.new(loader)
    local self = setmetatable({}, SiloMagazine)
    if loader.type ~= "transposer" then
        error("SiloMagazine.new: loader argument requires transposer proxy")
    end
    self.loader = loader
    self.size = nil
    self.ammo = {}
    self.loaded = ""
    self.emptySpace = {}

    self.storageSide = nil
    self.launchpadSide = nil

    self:checkConnections()
    self:scanStorage()
    self:checkIfLoaded()

    return self
end

function SiloMagazine:checkConnections()
    for i = 0, 5 do
        local name = self.loader.getInventoryName(i)
        if name == "hbm:launch_pad" then
            if self.launchpadSide ~= nil then
                error("SiloMagazine: " .. self.loader.address .. " Multiple launchpads connected")
            end
            self.launchpadSide = i
        elseif name ~= nil then
            if self.storageSide ~= nil then
                error("SiloMagazine: " .. self.loader.address .. " Multiple storage units connected")
            end
            self.storageSide = i
        end
    end

    if self.launchpadSide == nil then
        error("SiloMagazine: " .. self.loader.address .. " No launchpad connected")
    end
    if self.storageSide == nil then
        error("SiloMagazine: " .. self.loader.address .. " No storage unit connected")
    end
end

function SiloMagazine:isMissile(item)
    return item ~= nil and type(item.name) == "string" and string.sub(item.name, 1, 11) == "hbm:missile"
end

function SiloMagazine:getMissileName(item)
    return item.label or item.name or "ERROR:MISSING_NAME"
end

function SiloMagazine:scanStorage()
    self.size = self.loader.getInventorySize(self.storageSide) 
    if self.size == nil then
        error("SiloMagazine: " .. self.loader.address .. " Storage unit disconnected")
    end

    self.ammo = {}
    self.emptySpace = {}

    for i = 1, self.size do
        local item = self.loader.getStackInSlot(self.storageSide, i)
        if self:isMissile(item) then
            local name = self:getMissileName(item)
            if type(self.ammo[name]) ~= "table" then
                self.ammo[name] = {}
            end
            table.insert(self.ammo[name], i)
        elseif item == nil then
            table.insert(self.emptySpace, i)
        end
    end
end

function SiloMagazine:checkIfLoaded()
    local item = self.loader.getStackInSlot(self.launchpadSide, 1)
    if self:isMissile(item) then
        self.loaded = self:getMissileName(item)
    else
        self.loaded = ""
    end
end

function SiloMagazine:load(missileName)
    if self.loaded == missileName then
        return true
    end

    if self.ammo[missileName] == nil or #self.ammo[missileName] == 0 then
        return false, "no missiles of requested type available"
    end

    self:checkIfLoaded()
    local success, error = self:unload()
    if not success then
        return false, error
    end

    local slot = table.remove(self.ammo[missileName])
    self.loader.transferItem(self.storageSide, self.launchpadSide, 1, slot, 1)
    self.loaded = missileName

    return true
end

function SiloMagazine:unload()
    if self.loaded == "" then
        return true
    end

    if #self.emptySpace == 0 then
        return false, "no space to unload loaded missile"
    end

    local emptySlot = table.remove(self.emptySpace)
    self.loader.transferItem(self.launchpadSide, self.storageSide, 1, 1, emptySlot)
    if type(self.ammo[self.loaded]) ~= "table" then
        self.ammo[self.loaded] = {}
    end
    table.insert(self.ammo[self.loaded], emptySlot)
    self.loaded = ""

    return true
end

function SiloMagazine:getMissiles()
    local missiles = {}
    for missileName, slots in pairs(self.ammo) do
        missiles[missileName] = #slots
    end
    if self.loaded ~= "" then
        if missiles[self.loaded] == nil then
            missiles[self.loaded] = 0
        end
        missiles[self.loaded] = missiles[self.loaded] + 1
    end
    
    return missiles
end

return SiloMagazine