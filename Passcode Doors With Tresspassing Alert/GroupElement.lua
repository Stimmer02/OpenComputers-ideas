local DisplayElement = require("DisplayElement")

local GroupElement = DisplayElement.new()
GroupElement.__index = GroupElement


---@diagnostic disable-next-line: duplicate-set-field
function GroupElement.new(displayElement)
    if getmetatable(displayElement) ~= DisplayElement then
        error("GroupElement.new() requires a DisplayElement as argument")
    end
    setmetatable(displayElement, GroupElement)
    displayElement.relativeX = displayElement.x
    displayElement.relativeY = displayElement.y
    return displayElement
end

function GroupElement:updatePosition(xDiff, yDiff)
    self.x = self.relativeX + xDiff
    self.y = self.relativeY + yDiff
end

---@diagnostic disable-next-line: duplicate-set-field
function GroupElement:setPosition(x, y)
    local xDiff = self.x - self.relativeX
    local yDiff = self.y - self.relativeY
    self.relativeX = x
    self.relativeY = y
    self:updatePosition(xDiff, yDiff)
end

return GroupElement