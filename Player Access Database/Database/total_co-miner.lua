local fs = require("filesystem")
local component = require("component")
local bit32 = require("bit32")
local term = require("term")
local event = require("event")
local keyboard = require("keyboard")
local shell = require("shell")
local gpu = component.gpu



BasicGraphisc = {
    width,
    fullLine,
    bgColor,
    fgColor,
    midColor,
}
function BasicGraphisc:new (o, width)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.fullLine = ""
    for i = 1, width do
        o.fullLine = o.fullLine.." "
    end
    o.width = width
    o.bgColor = gpu.getBackground()
    o.fgColor = gpu.getForeground()
    o.midColor = (o.fgColor + o.bgColor)/2
    return o
end

function BasicGraphisc:setInverted(x, y, text, vertical)
    text = text..(self.fullLine:sub(1, self.width - text:len()))
    gpu.setBackground(self.fgColor)
    gpu.setForeground(self.bgColor)
    gpu.set(x, y, text, vertical)
    gpu.setBackground(self.bgColor)
    gpu.setForeground(self.fgColor)
end

function BasicGraphisc:setMidInverted(x, y, text, vertical)
    text = text..(self.fullLine:sub(1, self.width - text:len()))
    gpu.setBackground(self.midColor)
    gpu.setForeground(self.bgColor)
    gpu.set(x, y, text, vertical)
    gpu.setBackground(self.bgColor)
    gpu.setForeground(self.fgColor)
end


Disk = {diskProxy, mountpoint}
function Disk:new (o, diskProxy, mountpoint)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.diskProxy = diskProxy
    o.mountpoint = mountpoint
    return o
end
function Disk.comperator(x, y)
    return x.mountpoint <= y.mountpoint
end



FileExplorerPage = {
    depth,
    currentDir,
    currentDirTable,
    currentDirFiles,
    cursorPosition,
    firstPositionShown,

    basicGraphisc,
    active,
    selected,

    screenStartWidth,
    screenWidth,
    screenHeight,
    mountedDevices
}
function FileExplorerPage:new (o, screenStartWidth, screenWidth, screenHeight)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.depth = 0
    o.currentDir = nil
    o.cursorPosition = 1
    o.firstPositionShown = 1
    o.basicGraphisc = BasicGraphisc:new(nil, screenWidth)
    o.active = false
    o.screenStartWidth = screenStartWidth
    o.screenWidth = screenWidth
    o.screenHeight = screenHeight
    o.selected = {}
    o:getDirTable()

    return o
end

function FileExplorerPage:searchDevices ()
    self.mountedDevices = {}
    for diskProxy, mountpoint in fs.mounts() do
        local newDevice = Disk:new(nil, diskProxy, mountpoint)
        table.insert(self.mountedDevices, newDevice)
    end
--     table.sort(self.mountedDevices, Disk.comperator)
end

function FileExplorerPage:getDirTable ()
    self.currentDirFiles = {}
    self.currentDirTable = {}
    if self.depth == 0 then
        self:searchDevices()
        for _, v in pairs(self.mountedDevices) do
            table.insert(self.currentDirTable, v.mountpoint)
        end
    else
        for v in fs.list(self.currentDir) do
            table.insert(self.currentDirFiles, v)
            table.insert(self.currentDirTable, v)
        end
        table.sort(self.currentDirFiles)
        table.sort(self.currentDirTable)
        table.insert(self.currentDirTable, 1, "<back>")
    end

    self.selected = {}
    for i = 1, #self.currentDirTable do
        table.insert(self.selected, false)
    end
end

function FileExplorerPage:refreshLine (lineNumber)
    gpu.fill(self.screenStartWidth, lineNumber+1, self.screenWidth, 1, " ")
    if lineNumber == 0 then
        local line = "WD:"..(self.currentDir or " CHOOSE DEVICE")
        if line:len() > self.screenWidth then
            line = string.sub(line, 1, self.screenWidth)
        end

        if self.active then
            self.basicGraphisc:setInverted(self.screenStartWidth, 1, line)
        else
            gpu.set(self.screenStartWidth, 1, line)
        end
    else
        local line = self.currentDirTable[lineNumber + self.firstPositionShown - 1]
        if self.cursorPosition == lineNumber then
            line = ">"..line
        else
            line = " "..line
        end
        if line:len() > self.screenWidth then
            line = string.sub(line, 1, self.screenWidth)
        end
        if self.selected[lineNumber + self.firstPositionShown - 1] then
            self.basicGraphisc:setInverted(self.screenStartWidth, lineNumber+1, line)
        else
            gpu.set(self.screenStartWidth, lineNumber+1, line)
        end
    end
end


function FileExplorerPage:fullRefresh ()
    gpu.fill(self.screenStartWidth, 1, self.screenWidth, self.screenHeight, " ")
    local line = "WD:"..(self.currentDir or " CHOOSE DEVICE")
    if line:len() > self.screenWidth then
        line = string.sub(line, 1, self.screenWidth)
    end

    if self.active then
        self.basicGraphisc:setInverted(self.screenStartWidth, 1, line)
    else
        gpu.set(self.screenStartWidth, 1, line)
    end
    if #self.currentDirTable > self.screenHeight-1 then
        local offset = self.firstPositionShown-1
        for i = 1, self.screenHeight-1 do
            line = self.currentDirTable[i+offset]
            if line:len() > self.screenWidth-1 then
                line = string.sub(line, 1, self.screenWidth-1)
            end

            if self.cursorPosition == i then
                line = ">"..line
            else
                line = " "..line
            end

            if self.selected[i+self.firstPositionShown-1] then
                self.basicGraphisc:setInverted(self.screenStartWidth, i+1, line)
            else
                gpu.set(self.screenStartWidth, i+1, line)
            end
        end
    else
        for i = 1, #self.currentDirTable do
            line = self.currentDirTable[i]
            if line:len() > self.screenWidth-1 then
                line = string.sub(line, 1, self.screenWidth-1)
            end

            if self.cursorPosition == i then
                line = ">"..line
            else
                line = " "..line
            end

            if self.selected[i+self.firstPositionShown-1] then
                self.basicGraphisc:setInverted(self.screenStartWidth, i+1, line)
            else
                gpu.set(self.screenStartWidth, i+1, line)
            end
        end
    end
end

function FileExplorerPage:moveCursor (directionUp)
    if directionUp then
        if self.cursorPosition > 1 then
            local line = self.currentDirTable[self.cursorPosition]
            self.cursorPosition = self.cursorPosition-1
            self:refreshLine(self.cursorPosition + 1)
            self:refreshLine(self.cursorPosition)
        elseif self.cursorPosition == 1 and self.firstPositionShown > 1 then
            self.firstPositionShown = self.firstPositionShown-1
            gpu.copy(self.screenStartWidth, 3, self.screenWidth, self.screenHeight-3, 0, 1)
            self:refreshLine(self.cursorPosition + 1)
            self:refreshLine(self.cursorPosition)
        end
    else
        if self.cursorPosition < #self.currentDirTable and self.cursorPosition < self.screenHeight-1 then
            local line = self.currentDirTable[self.cursorPosition]
            self.cursorPosition = self.cursorPosition+1
            self:refreshLine(self.cursorPosition - 1)
            self:refreshLine(self.cursorPosition)
        elseif self.cursorPosition == self.screenHeight-1 and self:absCursorPosition() < #self.currentDirTable then
            self.firstPositionShown = self.firstPositionShown+1
            gpu.copy(self.screenStartWidth, 3, self.screenWidth, self.screenHeight-3, 0, -1)
            self:refreshLine(self.cursorPosition - 1)
            self:refreshLine(self.cursorPosition)
        end
    end
end

function FileExplorerPage:selectPosition ()
    if self.depth ~= 0 and self.cursorPosition > 1 then
        self.selected[self:absCursorPosition()] = not self.selected[self:absCursorPosition()]
        self:refreshLine(self.cursorPosition)
    end
end

function FileExplorerPage:selectAllToThisElement ()
    if self.depth ~= 0 then
        local shortestPathDown, shortestPathUp = 0, 0
        for i = self:absCursorPosition() + 1, #self.currentDirTable do
            if self.selected[i] then
                shortestPathDown = i - self:absCursorPosition()
                break
            end
        end
        for i = self:absCursorPosition() - 1, 2, -1 do
            if self.selected[i] then
                shortestPathUp = self:absCursorPosition() - i
                break
            end
        end
        if shortestPathDown ~= 0 and (shortestPathDown < shortestPathUp or shortestPathUp == 0) then
            for i = self.cursorPosition, self.cursorPosition+shortestPathDown do
                self.selected[i+self.firstPositionShown-1] = true
                self:refreshLine(i)
            end
        elseif shortestPathUp ~= 0 then
            for i = self.cursorPosition, self.cursorPosition-shortestPathUp, -1 do
                self.selected[i+self.firstPositionShown-1] = true
                self:refreshLine(i)
            end
        end
    end
end

function FileExplorerPage:backDirectory ()
    if self.depth > 0 then
        self.currentDir = fs.path(self.currentDir)
        self.depth = self.depth-1
        self.cursorPosition = 1
        self.firstPositionShown = 1
        self:getDirTable()
        self:fullRefresh()
    end
end

function FileExplorerPage:enterDirectory ()
    if self.depth == 0 then
        self.currentDir = self.mountedDevices[self:absCursorPosition()].mountpoint
        self.depth = self.depth+1
        self.cursorPosition = 1
        self.firstPositionShown = 1
        self:getDirTable()
        self:fullRefresh()
    else
        if self.cursorPosition == 1 then
            self:backDirectory()
        else
            local newDir = fs.concat(self.currentDir, self.currentDirTable[self:absCursorPosition()])
            if fs.isDirectory(newDir) then
                self.currentDir = newDir
                self.depth = self.depth+1
                self.cursorPosition = 1
                self.firstPositionShown = 1
                self:getDirTable()
                self:fullRefresh()
            else
                return false
            end
        end
    end
    return true
end

function FileExplorerPage:absCursorPosition ()
    return self.cursorPosition + self.firstPositionShown - 1
end

function FileExplorerPage:returnSelected ()
    local out = {}
    if self.depth ~= 0 then
        for i, v in pairs(self.currentDirFiles) do
            if self.selected[i+1] then
                table.insert(out, fs.concat(self.currentDir, v))
            end
        end
    end
    return out
end



FileExplorer = {
    screenWidth,
    screenHeight,
    tabWidth,
    fep1,
    fep2,
    activeFep,
    clipboard,
}
function FileExplorer:new (o)
    local o = o or {}
    setmetatable(o , {__index = self})
    o.screenWidth, o.screenHeight = gpu.getViewport()
    o.tabWidth = bit32.arshift(o.screenWidth-1, 1)
    o.fep1 = FileExplorerPage:new(nil, 1, o.tabWidth, o.screenHeight-2)
    o.fep2 = FileExplorerPage:new(nil, o.tabWidth+2, o.tabWidth, o.screenHeight-2)
    o.fep1.active = true
    o.activeFep = o.fep1
    o.clipboard = {}
    return o
end

function FileExplorer:printWindowBorders ()
    gpu.fill(self.tabWidth+1, 1, 1, self.screenHeight-2, "│")
    gpu.fill(1, self.screenHeight-1, self.screenWidth, 1, "─")
    gpu.set(self.tabWidth+1, self.screenHeight-1, "┴")
end

function FileExplorer:clearInfoLine ()
    gpu.fill(1, self.screenHeight, self.screenWidth, 1, " ")
end

function FileExplorer:printInfoLine (line)
    gpu.fill(1, self.screenHeight, self.screenWidth, 1, " ")
    gpu.set(1, self.screenHeight, line)
end

function FileExplorer:fullRefresh (clearInfo)
    self:printWindowBorders()
    self.fep1:fullRefresh()
    self.fep2:fullRefresh()
    if clearInfo == true then
        self:clearInfoLine()
    end
end

function FileExplorer:readFilename ()
    term.setCursorBlink(true)
    self:printInfoLine("FILENAME: ")
    term.setCursor(11, self.screenHeight)
    local name = io.stdin:read()
--     self:printWindowBorders()
    --TODO check if filename is valid
    return name
end

function FileExplorer:main ()
    self:fullRefresh(true)
    local running = true
    local key, key2
    while running do
        _, _, key, key2= event.pull(nil, "key_down")
        if key2 == 200 then --up
            self.activeFep:moveCursor(true)
            if keyboard.isShiftDown() then
                self.activeFep:selectPosition()
            end
        elseif key2 == 208 then --down
            self.activeFep:moveCursor(false)
            if keyboard.isShiftDown() then
                self.activeFep:selectPosition()
            end
        elseif key2 == 203 then --left
            self.activeFep = self.fep1
            self.fep1.active = true
            self.fep2.active = false
            self.fep1:refreshLine(0)
            self.fep2:refreshLine(0)
        elseif key2 == 205 then --right
            self.activeFep = self.fep2
            self.fep1.active = false
            self.fep2.active = true
            self.fep1:refreshLine(0)
            self.fep2:refreshLine(0)
        elseif key == 0 then
            goto continue
        elseif key == 8 then --backspace
            self.activeFep:backDirectory()
        elseif key == 13 then --enter
            if not self.activeFep:enterDirectory() then
                os.execute("shedit "..fs.concat(self.activeFep.currentDir, self.activeFep.currentDirTable[self.activeFep:absCursorPosition()]))
                self:fullRefresh(true)
            end
        elseif key2 == 57 then --space
            if keyboard.isShiftDown() then
                self.activeFep:selectAllToThisElement()
            else
                self.activeFep:selectPosition()
            end
        elseif key2 == 46 then --c
            if keyboard.isControlDown() then
                self.clipboard = self.activeFep:returnSelected()
                if #self.clipboard == 0 then
                    self:printInfoLine("NO FILE WAS SELECTED")
                else
                    self:printInfoLine("COPYING FILES TO CLIPBOARD: "..tostring(#self.clipboard))
                end
            end
        elseif key2 == 47 then --v
            if keyboard.isControlDown() then
                if #self.clipboard == 0 then
                    self:printInfoLine("NO FILE IN CLIPBOARD")
                else
                    for _, v in pairs(self.clipboard) do
                        os.execute("/bin/cp.lua -r "..v.." "..self.activeFep.currentDir.."/")
                    end
                    self.activeFep:getDirTable()
                    self.activeFep:fullRefresh()
                    self:printInfoLine("FILES PASTED: "..tostring(#self.clipboard))
                end
            end
        elseif key2 == 211 then --DELETE
            if keyboard.isControlDown() then
                local selected = self.activeFep:returnSelected()
                if #selected == 0 then
                    self:printInfoLine("NO FILE WAS SELECTED")
                else
                    local filesDeleted = 0
                    local noErr, err
                    for _, v in pairs(selected) do
                        noErr, err = fs.remove(v)
                        if noErr then
                            filesDeleted = filesDeleted+1
                        else
                            break
                        end
                    end
                    self.activeFep.cursorPosition = 1
                    self.activeFep:getDirTable()
                    self.activeFep:fullRefresh()
                    if noErr then
                        self:printInfoLine("FILES DELETED: "..tostring(filesDeleted))
                    else
                        self:printInfoLine("FILES DELETED: "..tostring(filesDeleted).."; "..err)
                    end
                end
            end
        elseif key2 == 20 then --t
            if keyboard.isControlDown() and self.activeFep.depth > 0 then
                local name = self:readFilename()
                if fs.exists(self.activeFep.currentDir.."/"..name) then
                    self:printInfoLine("FILE ALREADY EXISTS: "..name)
                else
                    local file, err = fs.open(self.activeFep.currentDir.."/"..name, "w")
                    if file == nil then
                        self:printInfoLine("COULD NOT CREATE FILE: "..name.."; "..err)
                    else
                        self:printInfoLine("FILE CREATED: "..name)
                        file:close()
                        self.activeFep:getDirTable()
                    end
                end
                self:fullRefresh()
            end
        elseif key2 == 32 then --d
            if keyboard.isControlDown() and self.activeFep.depth > 0 then
                local name = self:readFilename()
                local noErr, err = fs.makeDirectory(self.activeFep.currentDir.."/"..name)
                self.activeFep:getDirTable()
                self:fullRefresh()
                if noErr then
                    self:printInfoLine("DIRECTORY CREATED: "..name)
                else
                    self:printInfoLine("COULD NOT CREATE DIRECTORY: "..name.."; "..err)
                end
            end
        elseif key2 == 35 then --h
            self:printInfoLine("h-help, Ctrl+: q-quit, d-mkDir, t-touch, c-copy, v-paste, DEL-delete, SPACE-select")
        elseif key2 == 16 then --q
            if keyboard.isControlDown() then
                running = false
            end
        else
            self:printInfoLine(tostring(key).." "..tostring(key2))
        end

        ::continue::
    end

    term.clear()
end

local buffer = gpu.allocateBuffer()
local currentBuffer = gpu.getActiveBuffer()
-- gpu.bitblt(table.unpack({src=0, dest=buffer}))
fileExplorer = FileExplorer:new()
gpu.bitblt(currentBuffer, 1, 1, fileExplorer.screenWidth, fileExplorer.screenHeight, buffer, 1, 1)
fileExplorer:main()
-- gpu.bitblt(table.unpack({src=buffer, dest=0}))
gpu.bitblt(buffer, 1, 1, fileExplorer.screenWidth, fileExplorer.screenHeight, currentBuffer, 1, 1)
gpu.freeBuffer(buffer)

