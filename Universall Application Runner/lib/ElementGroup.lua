local GroupElement = require("GroupElement")
local DisplayElement = require("DisplayElement")


local ElementGroup = {}
ElementGroup.__index = ElementGroup

function ElementGroup.new()
    local self = setmetatable({}, ElementGroup)
    self.elements = {}
    self.groups = {}
    self.x = 1
    self.y = 1
    self.relativeX = self.x
    self.relativeY = self.y
    return self
end

function ElementGroup.createGroup(rows, collums, elementWidth, elementHeight, collumSpacing, rowSpacing, frame, centered)
    centered = centered or false
    frame = frame or false
    local self = ElementGroup.new()
    for i = 1, rows do
        for j = 1, collums do
            local element = DisplayElement.new()
            element:setWidth(elementWidth)
            element:setHeight(elementHeight)
            element:setPosition((j - 1) * (elementWidth + collumSpacing) + 1, (i - 1) * (elementHeight + rowSpacing) + 1)
            element.drawFrame = frame
            element.centeredWidth = centered
            self:addElement(element)
        end
    end
    return self
end


function ElementGroup:addElement(element, begining)
    if getmetatable(element) == DisplayElement then
        local groupElement = GroupElement.new(element)
        groupElement:updatePosition(self.x, self.y)
        if begining == nil then
            table.insert(self.elements, groupElement)
        else
            table.insert(self.elements, 1, groupElement)
        end
    elseif getmetatable(element) == ElementGroup then
        element:updatePosition(self.x, self.y)
        if begining == nil then
            table.insert(self.groups, element)
        else
            table.insert(self.groups, 1, element)
        end
    elseif getmetatable(element) == GroupElement then
        error("Given element is already a GroupElement")
    else
        error("ElementGroup:addElement() requires a DisplayElement or ElementGroup as argument")
    end
end

function ElementGroup:setPosition(x, y)
    local xDiff = self.x - self.relativeX + 1
    local yDiff = self.y - self.relativeY + 1
    self.relativeX = x
    self.relativeY = y
    self:updatePosition(xDiff, yDiff)
end

function ElementGroup:updatePosition(xDiff, yDiff)
    self.x = self.relativeX + xDiff - 1
    self.y = self.relativeY + yDiff - 1
    for _, element in ipairs(self.elements) do
        element:updatePosition(self.x, self.y)
    end
    for _, group in ipairs(self.groups) do
        group:updatePosition(self.x, self.y)
    end
end

function ElementGroup:getElements()
    local allElements = {}
    for _, element in ipairs(self.elements) do
        table.insert(allElements, element)
    end
    for _, group in ipairs(self.groups) do
        for _, element in ipairs(group:getElements()) do
            table.insert(allElements, element)
        end
    end

    return allElements
end

function ElementGroup:setAction(actionArr)
    if #actionArr > #self.elements then
        error("actionArr has too many entries (".. #actionArr .." > ".. #self.elements .. ")")
    end
    for i, element in ipairs(self.elements) do
        element.action = actionArr[i]
    end
end

function ElementGroup:setContent(contentArr, gpu, colors)
    -- if #contentArr > #self.elements then
    --     error("contentArr has too many entries (".. #contentArr .." > ".. #self.elements .. ")" )
    -- end
    if gpu == nil then
        for i, element in ipairs(self.elements) do
            element:setContent(contentArr[i])
        end
    elseif colors == nil then
        for  i, element in ipairs(self.elements) do
            element:setContent(contentArr[i])
            element:drawNormal(gpu)
        end
    else
        for i, element in ipairs(self.elements) do
            element:setContent(contentArr[i])
            element:draw(gpu, colors)
        end
    end
end

function ElementGroup:setColors(normalColors, activeColors, recursive)
    for _, element in ipairs(self.elements) do
        element:setColors(normalColors, activeColors)
    end
    if recursive then
        for _, group in ipairs(self.groups) do
            group:setColors(normalColors, activeColors, recursive)
        end
    end
end

function ElementGroup:setNormalColors(colors, recursive)
    for _, element in ipairs(self.elements) do
        element:setNormalColors(colors)
    end
    if recursive then
        for _, group in ipairs(self.groups) do
            group:setNormalColors(colors, recursive)
        end
    end
end

function ElementGroup:setActiveColors(colors, recursive)
    for _, element in ipairs(self.elements) do
        element:setActiveColors(colors)
    end
    if recursive then
        for _, group in ipairs(self.groups) do
            group:setActiveColors(colors, recursive)
        end
    end
end

function ElementGroup:draw(gpu, colors, recursive)
    for _, element in ipairs(self.elements) do
        element:draw(gpu, colors)
    end
    if recursive then
        for _, group in ipairs(self.groups) do
            group:draw(gpu, colors, recursive)
        end
    end
end

function ElementGroup:drawNormal(gpu, recursive)
    for _, element in ipairs(self.elements) do
        element:drawNormal(gpu)
    end
    if recursive then
        for _, group in ipairs(self.groups) do
            group:drawNormal(gpu, recursive)
        end
    end
end

function ElementGroup:drawActive(gpu, recursive)
    for _, element in ipairs(self.elements) do
        element:drawActive(gpu)
    end
    if recursive then
        for _, group in ipairs(self.groups) do
            group:drawActive(gpu, recursive)
        end
    end
end

function ElementGroup:getDims()
    local width = 0
    local height = 0
    for _, element in ipairs(self.elements) do
        local elementWidth, elementHeight
        elementWidth = element.relativeX + element.width
        elementHeight = element.relativeY + element.height
        if elementWidth > width then
            width = elementWidth
        end
        if elementHeight > height then
            height = elementHeight
        end
    end
    for _, group in ipairs(self.groups) do
        local groupWidth, groupHeight = group:getDims()
        groupWidth = groupWidth + group.relativeX
        groupHeight = groupHeight + group.relativeY
        if groupWidth > width then
            width = groupWidth
        end
        if groupHeight > height then
            height = groupHeight
        end
    end
    return width - 1, height - 1
end

function ElementGroup:createFrameElement(addToSelf)
    addToSelf = addToSelf or false
    local width, height = self:getDims()
    local frameElement = DisplayElement.new()
    frameElement:setWidth(width)
    frameElement:setHeight(height)
    frameElement.drawFrame = true
    if addToSelf then
        self:addElement(frameElement, true)
    else
        return frameElement
    end
end

return ElementGroup