local component = require("component")
local term = require("term")
local Display = require("Display")
local serial = require("serialization")

DisplayManager = {onlyInstance, displays = {}, count, currentDisplay, gpu, primaryScreenAddr}
function DisplayManager:new(o)
    if DisplayManager.onlyInstance == nil then
        local o = o or {}
        setmetatable(o, {__index = self})
        o.gpu = component.gpu
        o.primaryScreenAddr = o.gpu.getScreen()
        local x, y = term.getCursor()
        local rx, ry = o.gpu.getResolution()
        local newDisplay = Display:new(nil, o.primaryScreenAddr, {rx, ry}, {x, y})
        table.insert(o.displays, newDisplay)
        o.count = 1
        o.currentDisplay = 1
        DisplayManager.onlyInstance = o
        return o
    else
        return DisplayManager.onlyInstance
    end
end

function DisplayManager:add(screenAddr)
    self.gpu.bind(screenAddr)
    local rx, ry = self.gpu.getResolution()
    self.gpu.bind(self.displays[self.currentDisplay].screenAddr)
    local newDisplay = Display:new(nil, screenAddr, {rx, ry}, {1, 1})
    table.insert(self.displays, newDisplay)
    self.count = self.count + 1
end

function DisplayManager:autoAdd()
    for addres, _ in component.list("screen") do
        local contains = false
        for _, v in  pairs(self.displays) do
            if v.screenAddr == addres then
                contains = true
                break
            end
        end
        if contains == false then
            self:add(addres)
        end
    end
end

function DisplayManager:identify()
    for i = 1, self.count do
        self:changeDisplay(i)
        term.write(i)
    end
    self:changeDisplay(1)
end

function DisplayManager:doForAll(fun , args)
    for i = 1, self.count do
        self:changeDisplay(i)
        fun(table.unpack(args))
    end
end

function DisplayManager:doMultipleForAll(funTable, argsTable)
    for i = 1, self.count do
        self:changeDisplay(i)
        for i, v in pairs(funTable) do
            v(table.unpack(argsTable[i]))
        end
    end
end

function DisplayManager:changeDisplay(displayIndex)
    if self.currentDisplay ~= displayIndex then
        local x, y = term.getCursor()
        self.displays[self.currentDisplay].cursorPos = {x, y}
        x, y = self.gpu.getResolution()
        self.displays[self.currentDisplay].resolution = {x, y} --IS THIS EVEN NEEDED?
        self.currentDisplay = displayIndex
        self.gpu.bind(self.displays[displayIndex].screenAddr)
        self.gpu.setResolution(self.displays[self.currentDisplay].resolution[1], self.displays[self.currentDisplay].resolution[2])
        term.setCursor(self.displays[self.currentDisplay].cursorPos[1], self.displays[self.currentDisplay].cursorPos[2])
    end
end

function DisplayManager:resetResolution()
    local temp = self.currentDisplay
    for i = 1, self.count do
        self:changeDisplay(i)
        self.gpu.setResolution(self.displays[i].startResolution[1], self.displays[i].startResolution[2])
    end
    self:changeDisplay(temp)
end

function DisplayManager:reset(clearAll)
    self:resetResolution()
    if clearAll ~= nil then
        for i = 2, self.count do
            self:changeDisplay(i)
            term.clear()
        end
        if clearAll then
            self:changeDisplay(1)
            term.clear()
            return
        end
    end
    self:changeDisplay(1)
end

return DisplayManager
