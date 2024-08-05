local DisplayElement = {}
DisplayElement.__index = DisplayElement

function DisplayElement.new()
    local self = setmetatable({}, DisplayElement)
    self.width = 0
    self.height = 0
    self.x = 1
    self.y = 1
    self.content = {}
    self.centeredWidth = true
    self.normal = {fg = 0xFFFFFF, bg = 0x000000}
    self.active = {fg = 0x000000, bg = 0xFFFFFF}
    self.drawFrame = false
    -- self.inactive = false
    
    self.action = nil
    self.scroll = nil
    return self
end

function DisplayElement:executeAction(displayMatrix, x, y)
    if self.action ~= nil then
        self:action(displayMatrix, x, y)
    end
end

function DisplayElement:executeScroll(displayMatrix, direction, x, y)
    if self.scroll ~= nil then
        self:scroll(displayMatrix, direction, x, y)
    end
end

function DisplayElement:setContent(content)
    if content == nil then
        self.content = {}
        return
    end
    if type(content) ~= "table" then
        error("Content must be a table")
    end
    if #content > self.height then
        error("Content has too many lines (".. #content .." > ".. self.height .. ")")
    end
    for i = 1, #content do
        if #content[i] > self.width then
            error("Content line " .. i .. " is too long")
        end
    end
    self.content = content
end

function DisplayElement:setWidth(width)
    for i = 1, #self.content do
        if #self.content[i] > width then
            error("Widht: ".. width .." is to short for content line " .. i)
        end
    end
    self.width = width
end

function DisplayElement:setHeight(height)
    if #self.content > height then
        error("Height: ".. height .." is to short for content")
    end
    self.height = height
end

function DisplayElement:setPosition(x, y)
    self.x = x
    self.y = y
end


function DisplayElement:lineBegining(lineIndex)
    if lineIndex < 1 or lineIndex > #self.content then
        error("Line index is out of bounds")
    end
    if self.centeredWidth == true then
        return math.floor((self.width + (self.width & 1) - #self.content[lineIndex]) / 2)
    else
        return 1
    end
end

function DisplayElement:draw(gpu, colors)
    gpu.setBackground(colors.bg)
    gpu.setForeground(colors.fg)
    gpu.fill(self.x, self.y, self.width, self.height, " ")
    for i = 1, #self.content do
        gpu.set(self.x + self:lineBegining(i), self.y + i - 1, self.content[i])
    end
end

function DisplayElement:drawNormal(gpu)
    self:draw(gpu, self.normal)
end

function DisplayElement:drawActive(gpu)
    self:draw(gpu, self.active)
end

function DisplayElement:setColors(normal, active)
    self.normal = normal
    self.active = active
end

function DisplayElement:setNormalColors(colors)
    self.normal = colors
end

function DisplayElement:setActiveColors(colors)
    self.active = colors
end

return DisplayElement