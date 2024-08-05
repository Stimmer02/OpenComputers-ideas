local comp = require("component")
local DisplayElement = require("DisplayElement")
local GroupElement = require("GroupElement")
local ElementGroup = require("ElementGroup")
local event = require("event")
local term = require("term")

local DisplayMatrix = {}
DisplayMatrix.__index = DisplayMatrix

function DisplayMatrix.new(gpuProxy)
    local self = setmetatable({}, DisplayMatrix)
    self.gpu = gpuProxy

    if self.gpu == nil or self.gpu.type ~= "gpu" then
        error("Argument must be a GPU proxy")
    end
    self.width, self.height = self.gpu.getResolution()
    self.startWidth = self.width
    self.startHeight = self.height
    self.colors = {bg = 0x000000, fg = 0xFFFFFF}
    self.elements = {}

    self.elementClicked = nil

    
    self.actionMatrix = {} -- contains clicable elements
    self.scrollMatrix = {} -- contains scrollable elements
    self.frames = {} -- contains frames
    
    self.frameCharactersMap = {}
    self.frameCharactersMap[0]  = " " -- none
    self.frameCharactersMap[1]  = "╵" -- vertical top
    self.frameCharactersMap[2]  = "╷" -- vertical bottom
    self.frameCharactersMap[4]  = "╶" -- chorizontal right
    self.frameCharactersMap[8]  = "╴" -- chorizontal left
    
    self.frameCharactersMap[3]  = "│" -- vertical
    self.frameCharactersMap[12] = "─" -- chorizontal
    
    self.frameCharactersMap[5]  = "╰" -- top right
    self.frameCharactersMap[9]  = "╯" -- top left
    self.frameCharactersMap[6]  = "╭" -- bottom right
    self.frameCharactersMap[10] = "╮" -- bottom left
    
    self.frameCharactersMap[7]  = "├" -- vertical right
    self.frameCharactersMap[11] = "┤" -- vertical left
    self.frameCharactersMap[13] = "┴" -- chorizontal top
    self.frameCharactersMap[14] = "┬" -- chorizontal bottom
    
    self.frameCharactersMap[15] = "┼" -- all
    
    self.running = false
    return self
end

function DisplayMatrix:main(noKeyboard)
    self.running = true
    if noKeyboard == true then
        while self.running do
            local id, _, x, y, button = event.pullMultiple("touch", "interrupted")
            if id == "interrupted" then
                self:exit()
            elseif id == "touch" and self:clickInRange(x, y) then
                self:checkClick(x, y)
                os.sleep(0.1)
                self:checkDrop(x, y)
            end
        end
    else
        while self.running do
            local id, _, x, y, button = event.pullMultiple("scroll", "drop", "touch", "interrupted")
            if id == "interrupted" then
                self:exit()
            elseif id == "touch" and button == 0 then
                self:checkClick(x, y)
            elseif id == "drop" and button == 0 then
                self:checkDrop(x, y)
            elseif id == "scroll" then
                self:checkScroll(x, y, button)
            end
        end
    end
end

function DisplayMatrix:exit()
    self.running = false
    self.gpu.setResolution(self.startWidth, self.startHeight)
    self.width = self.startWidth
    self.height = self.startHeight
    self:clearScreen()
    term.setCursor(1, 1)
end

function DisplayMatrix:clickInRange(x, y)
    return x >= 1 and x <= self.width and y >= 1 and y <= self.height
end

function DisplayMatrix:checkClick(x, y)
    local element = self.actionMatrix[x][y]
    if element == nil then
        return
    end
    self.elementClicked = element
    self.elementClicked:drawActive(self.gpu)
end

function DisplayMatrix:checkDrop(x, y)
    local element = self.actionMatrix[x][y]
    if element ~= nil and element == self.elementClicked then
        element:executeAction(self, x, y)
    elseif self.elementClicked ~= nil then
        self.elementClicked:drawNormal(self.gpu)
        self.elementClicked = nil
    end
end

function DisplayMatrix:checkScroll(x, y, value)
    local element = self.scrollMatrix[x][y]
    if element == nil then
        return
    end
    element:scroll(self, value, x, y)
end

function DisplayMatrix:checkDims(width, height)
    if width < 1 or height < 1 then
        error("Width and height must be greater than 0")
    end

    local maxWidth, maxHeight = self.gpu.maxResolution()

    if width > maxWidth then
        error("Width is too big for this device")
    end

    if height > maxHeight then
        error("Height is too big for this device")
    end

    for _, element in pairs(self.elements) do
        if element.x + element.width - 1 > width then
            error("Element is out of bounds (x = " .. element.x .. ")")
        end
        if element.y + element.height - 1 > height then
            error("Element is out of bounds(y = " .. element.y .. ")")
        end
    end
end

function DisplayMatrix:dimsAcceptable(width, height)
    if width < 1 or height < 1 then
        return false
    end

    local maxWidth, maxHeight = self.gpu.maxResolution()

    if width > maxWidth then
        return false
    end

    if height > maxHeight then
        return false
    end

    for _, element in pairs(self.elements) do
        if element.x + element.width - 1 > width then
            return false
        end
        if element.y + element.height - 1 > height then
            return false
        end
    end

    return true
end

function DisplayMatrix:setDims(width, height)
    if width == self.width and height == self.height then
        return
    end
    self.width = width
    self.height = height
    self:checkDims(width, height)
    if self.gpu.setResolution(width, height) == false then
        error("Failed to set resolution" .. width .. "x" .. height)
    end
end

function DisplayMatrix:setDimsToMin()
    local minWidth = 1
    local minHeight = 1

    for _, element in pairs(self.elements) do
        if element.x + element.width - 1 > minWidth then
            minWidth = element.x + element.width - 1
        end
        if element.y + element.height - 1 > minHeight then
            minHeight = element.y + element.height - 1
        end
    end

    for i = 1, self.width do
        for j = 1, self.height do
            if self.frames[i][j] ~= 0 then
                if i > minWidth then
                    minWidth = i
                end
                if j > minHeight then
                    minHeight = j
                end
            end
        end
    end

    self:setDims(minWidth, minHeight)
end

function DisplayMatrix:resetCollors()
    self.gpu.setBackground(self.colors.bg)
    self.gpu.setForeground(self.colors.fg)
end

function DisplayMatrix:initMatrix()
    self.actionMatrix = {}
    self.scrollMatrix = {}
    for i = 1, self.width do
        self.actionMatrix[i] = {}
        self.scrollMatrix[i] = {}
    end

    self.frames = {}
    for i = 1, self.width do
        self.frames[i] = {}
        for j = 1, self.height do
            self.frames[i][j] = 0
        end
    end
end

function DisplayMatrix:clearScreen()
    self:resetCollors()
    self.gpu.fill(1, 1, self.width, self.height, " ")
end

function DisplayMatrix:addElement(element)
    if element == nil or (getmetatable(element) ~= DisplayElement and getmetatable(element) ~= GroupElement) then
        error("Argument must be a DisplayElement or GroupElement")
    end
    if element.x < 1 or element.x + element.width - 1 > self.width then
        error("Element is out of bounds (x = " .. element.x .. ")")
    end
    if element.y < 1 or element.y + element.height - 1 > self.height then
        error("Element is out of bounds(y = " .. element.y .. ")")
    end
    table.insert(self.elements, element)
end

function DisplayMatrix:addMultipleElements(elements)
    for _, element in pairs(elements) do
        self:addElement(element)
    end
end

function DisplayMatrix:addGroup(group)
    if group == nil or getmetatable(group) ~= ElementGroup then
        error("Argument must be a GroupElement")
    end
    self:addMultipleElements(group:getElements())
end

function DisplayMatrix:fillMatrix(element)
    if element.action == nil and element.scroll == nil then
        return
    end
    if element.action ~= nil and element.scroll ~= nil then
        for i = element.x, element.x + element.width - 1 do
            for j = element.y, element.y + element.height - 1 do
                self.actionMatrix[i][j] = element
                self.scrollMatrix[i][j] = element
            end
        end
    elseif element.action ~= nil then
        for i = element.x, element.x + element.width - 1 do
            for j = element.y, element.y + element.height - 1 do
                self.actionMatrix[i][j] = element
            end
        end
    elseif element.scroll ~= nil then
        for i = element.x, element.x + element.width - 1 do
            for j = element.y, element.y + element.height - 1 do
                self.scrollMatrix[i][j] = element
            end
        end
    end
end

function DisplayMatrix:drawFrame()
    self:resetCollors()
    for i = 1, self.width do
        for j = 1, self.height do
            if self.frames[i][j] ~= 0 then
                self.gpu.set(i, j, self.frameCharactersMap[self.frames[i][j]])
            end
        end
    end
end

function DisplayMatrix:addFrameAround(element)
    local x = element.x - 1
    local y = element.y - 1
    local width = element.width + 2
    local height = element.height + 2
    if x > 0 and x + width - 2 < self.width and y > 0 and y + height - 2 < self.height then
        self.frames[x][y] = self.frames[x][y] | 6
        self.frames[x + width - 1][y + height - 1] = self.frames[x + width - 1][y] | 9
        self.frames[x][y + height - 1] = self.frames[x][y + height - 1] | 5
        self.frames[x + width - 1][y] = self.frames[x + width - 1][y] | 10

        for i = x + 1, x + width - 2 do
            self.frames[i][y] = self.frames[i][y] | 12
            self.frames[i][y + height - 1] = self.frames[i][y + height - 1] | 12
        end

        for i = y + 1, y + height - 2 do
            self.frames[x][i] = self.frames[x][i] | 3
            self.frames[x + width - 1][i] = self.frames[x + width - 1][i] | 3
        end
    else
        local corner_topLeft = true
        local corner_topRight = true
        local corner_bottomLeft = true
        local corner_bottomRight = true

        if x > 0 then
            local start = y + 1
            local stop = y + height - 2
            if y < 1 then
                start = 1
            end
            if y + height - 1 > self.height then
                stop = self.height
            end
            for i = start, stop do
                self.frames[x][i] = self.frames[x][i] | 3
            end            
        else
            corner_topLeft = false
            corner_bottomLeft = false
        end

        if x + width - 2 < self.width then
            local start = y + 1
            local stop = y + height - 2
            if y < 1 then
                start = 1
            end
            if y + height - 1 > self.height then
                stop = self.height
            end
            for i = start, stop do
                self.frames[x + width - 1][i] = self.frames[x + width - 1][i] | 3
            end
        else
            corner_topRight = false
            corner_bottomRight = false
        end

        if y > 0 then
            local start = x + 1
            local stop = x + width - 2
            if x < 1 then
                start = 1
            end
            if x + width - 1 > self.width then
                stop = self.width
            end
            for i = start, stop do
                self.frames[i][y] = self.frames[i][y] | 12
            end
        else
            corner_topLeft = false
            corner_topRight = false
        end

        if y + height - 2 < self.height then
            local start = x + 1
            local stop = x + width - 2
            if x < 1 then
                start = 1
            end
            if x + width - 1 > self.width then
                stop = self.width
            end
            for i = start, stop do
                self.frames[i][y + height - 1] = self.frames[i][y + height - 1] | 12
            end
        else
            corner_bottomLeft = false
            corner_bottomRight = false
        end

        if corner_topLeft then
            self.frames[x][y] = self.frames[x][y] | 6
        end
        if corner_topRight then
            self.frames[x + width - 1][y] = self.frames[x + width - 1][y] | 10
        end
        if corner_bottomLeft then
            self.frames[x][y + height - 1] = self.frames[x][y + height - 1] | 5
        end
        if corner_bottomRight then
            self.frames[x + width - 1][y + height - 1] = self.frames[x + width - 1][y + height - 1] | 9
        end
    end

end

function DisplayMatrix:drawElement(element)
    element:drawNormal(self.gpu, element.normal)
    self:fillMatrix(element)
    if element.drawFrame == true then
        self:addFrameAround(element)
    end

end

function DisplayMatrix:draw()
    self:resetCollors()
    self:clearScreen()
    self:initMatrix()
    for _, element in pairs(self.elements) do
        self:drawElement(element)
    end
    self:drawFrame()
end



return DisplayMatrix