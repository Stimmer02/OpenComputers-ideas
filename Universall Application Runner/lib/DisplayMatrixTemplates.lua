local ElementGroup = require("ElementGroup")
local DisplayElement = require("DisplayElement")


-- KEYPAD TEMPLATE
local DisplayMatrixTemplate_keypad = {}
DisplayMatrixTemplate_keypad.__index = DisplayMatrixTemplate_keypad
function DisplayMatrixTemplate_keypad.new()
    local self = setmetatable({}, DisplayMatrixTemplate_keypad)
    self.passwordMaxLength = 4
    self.hiddenPassword = false
    self.drawFrameAroundEveryButton = false
    self.drawFrameAroundKeypad = true
    self.displayColors =       {normal = {fg = 0xFFFFFF, bg = 0x000000}, active = {fg = 0x000000, bg = 0xFFFFFF}}
    self.numberButtonsColors = {normal = {fg = 0xFFFFFF, bg = 0x000000}, active = {fg = 0x000000, bg = 0xFFFFFF}}
    self.acceptButtonsColors = {normal = {fg = 0x000000, bg = 0xFFFFFF}, active = {fg = 0xFFFFFF, bg = 0x000000}}
    self.rejectButtonsColors = {normal = {fg = 0x000000, bg = 0xFFFFFF}, active = {fg = 0xFFFFFF, bg = 0x000000}}
    self.writeToDisplayFunction = nil        -- takes keypad object and state as arguments
    self.doIfPasswordCorrectFunction = nil   -- takes keypad object as argument
    self.doIfPasswordIncorrectFunction = nil -- takes keypad object as argument
    self.passwordCheckFunction = nil         -- takes password to check as argument
    return self
end

function DisplayMatrixTemplate_keypad:setColors(palete, mainNormalColor, mainActiveColor)
    mainNormalColor = mainNormalColor or {fg = 0xFFFFFF, bg = 0x000000}
    mainActiveColor = mainActiveColor or {fg = mainNormalColor.bg, bg = mainNormalColor.fg}
    if palete == "basic" then
        self.displayColors =       {normal = mainNormalColor, active = mainActiveColor}
        self.numberButtonsColors = {normal = mainNormalColor, active = mainActiveColor} 
        self.acceptButtonsColors = {normal = mainActiveColor, active = mainNormalColor}
        self.rejectButtonsColors = {normal = mainActiveColor, active = mainNormalColor}
    elseif palete == "standard" then
        self.displayColors =       {normal = mainNormalColor, active = mainActiveColor}
        self.numberButtonsColors = {normal = {fg = 0x000000, bg = 0x5A5A5A}, active = {fg = 0x000000, bg = 0xFFFFFF}}
        self.acceptButtonsColors = {normal = {fg = 0x000000, bg = 0x00FF00}, active = {fg = 0x000000, bg = 0xFFFFFF}}
        self.rejectButtonsColors = {normal = {fg = 0x000000, bg = 0xFF0000}, active = {fg = 0x000000, bg = 0xFFFFFF}}
    else
        error("Color palete must be one of: basic, standard")
    end
end

function DisplayMatrixTemplate_keypad:setBasicWriteToDisplayFunction()
    self.writeToDisplayFunction = function(keypad, state)
        -- states:
        -- 0 - no password
        -- 1 - entering password
        -- 2 - password correct
        -- 3 - password incorrect
        if state  == 0 then
            return keypad.emptyPassword
        elseif state == 1 then
            if keypad.hiddenPassword then
                return string.rep("*", #keypad.currentPassword) .. string.rep("-", keypad.maxPasswordLength - #keypad.currentPassword)
            else
                return keypad.currentPassword .. string.rep("-", keypad.maxPasswordLength - #keypad.currentPassword)
            end
        elseif state == 2 then
            return "CORRECT"
        elseif state == 3 then
            return "INCORRECT"
        end
    end
end

function DisplayMatrixTemplate_keypad:setBasicPasswordCheckFunction(correctPassword)
    self.passwordMaxLength = #correctPassword
    self.passwordCheckFunction = function(password)
        return password == correctPassword
    end
end

function DisplayMatrixTemplate_keypad:build(preinitializedKeypadObject)
    if self.doIfPasswordCorrectFunction == nil then
        error("doIfPasswordCorrectFunction must be set")
    end
    if self.doIfPasswordIncorrectFunction == nil then
        error("doIfPasswordIncorrectFunction must be set")
    end
    if self.passwordCheckFunction == nil then
        error("passwordCheckFunction must be set")
    end
    if self.writeToDisplayFunction == nil then
        error("writeToDisplayFunction must be set")
    end

    local keypad = preinitializedKeypadObject or {}
    keypad.currentPassword = keypad.currentPassword or ""
    if keypad.emptyPassword == nil then
        keypad.emptyPassword = string.rep("-", self.passwordMaxLength)
    end

    keypad.maxPasswordLength = self.passwordMaxLength
    keypad.hiddenPassword = self.hiddenPassword

    keypad.doIfPasswordCorrectFunction = self.doIfPasswordCorrectFunction
    keypad.doIfPasswordIncorrectFunction = self.doIfPasswordIncorrectFunction
    keypad.passwordCheckFunction = self.passwordCheckFunction
    keypad.writeToDisplayFunction = self.writeToDisplayFunction

    keypad.displayWidth = 13
    if self.drawFrameAroundEveryButton then
        keypad.displayWidth = 17
    elseif self.drawFrameAroundKeypad then
        keypad.displayWidth = 15
    end

    local passCodeDisplay = DisplayElement.new()
    passCodeDisplay:setWidth(keypad.displayWidth)
    passCodeDisplay:setHeight(1)
    passCodeDisplay:setPosition(2, 2)
    local state = 0
    if #keypad.currentPassword > 0 then
        state = 1
    end
    passCodeDisplay:setContent({
        self.writeToDisplayFunction(keypad, state)
    })
    passCodeDisplay:setColors(self.displayColors.normal, self.displayColors.active)


    local numberButtons
    if self.drawFrameAroundEveryButton then
        numberButtons = ElementGroup.createGroup(4, 3, 5, 3, 1, 1, true, true)
    else
        numberButtons = ElementGroup.createGroup(4, 3, 5, 3, 0, 0, false, true)
    end

    if self.drawFrameAroundEveryButton or self.drawFrameAroundKeypad then
        numberButtons:setPosition(2, 4)
    else
        numberButtons:setPosition(1, 4)
    end

    local buttonContents = {}
    local buttonActions = {}
    for i = 1, 10 do
        local buttonIndex = i
        if i == 10 then
            buttonIndex = 0
        end
        buttonContents[i] = {
            "",
            tostring(buttonIndex)
        }
        buttonActions[i] = (function(self, displayMatrix)

            if #keypad.currentPassword < keypad.maxPasswordLength then
                keypad.currentPassword = keypad.currentPassword .. buttonIndex
                passCodeDisplay:setContent({
                    keypad.writeToDisplayFunction(keypad, 1)
                })
                passCodeDisplay:drawNormal(displayMatrix.gpu)
            end
            self:drawNormal(displayMatrix.gpu)
        end)
    end

    buttonContents[11] = {
        "",
        " ✔"
    }
    buttonContents[12] = {
        "",
        "X"
    }

    buttonActions[11] = (function(self, displayMatrix)
        if keypad.passwordCheckFunction(keypad.currentPassword) then
            passCodeDisplay:setContent({
                keypad.writeToDisplayFunction(keypad, 2)
            })
            passCodeDisplay:drawNormal(displayMatrix.gpu)
            keypad.doIfPasswordCorrectFunction(keypad)
            os.sleep(1)
        else
            passCodeDisplay:setContent({
                keypad.writeToDisplayFunction(keypad, 3)
            })
            passCodeDisplay:drawNormal(displayMatrix.gpu)
            keypad.doIfPasswordIncorrectFunction(keypad)
            os.sleep(1)
        end
        keypad.currentPassword = ""
        passCodeDisplay:setContent({
            keypad.writeToDisplayFunction(keypad, 0)
        })
        passCodeDisplay:drawNormal(displayMatrix.gpu)
        self:drawNormal(displayMatrix.gpu)
    end)

    buttonActions[12] = (function(self, displayMatrix)
        keypad.currentPassword = ""
        passCodeDisplay:setContent({
            keypad.writeToDisplayFunction(keypad, 0)
        })
        self:drawNormal(displayMatrix.gpu)
        passCodeDisplay:drawNormal(displayMatrix.gpu)
    end)
    numberButtons:setContent(buttonContents)
    numberButtons:setAction(buttonActions)
    if self.hiddenPassword then
        numberButtons:setColors(self.numberButtonsColors.normal, self.numberButtonsColors.normal)
    else
        numberButtons:setColors(self.numberButtonsColors.normal, self.numberButtonsColors.active)
    end
    numberButtons.elements[11]:setColors(self.acceptButtonsColors.normal, self.acceptButtonsColors.active)
    numberButtons.elements[12]:setColors(self.rejectButtonsColors.normal, self.rejectButtonsColors.active)
    if self.drawFrameAroundKeypad then
        numberButtons:createFrameElement(true)
    end

    local keypadGroup = ElementGroup.new()
    keypadGroup:addElement(passCodeDisplay)
    keypadGroup:addElement(numberButtons)
    
    keypad.group = keypadGroup
    return keypad
end




-- LIST TEMPLATE
local DisplayMatrixTemplate_list = {}
DisplayMatrixTemplate_list.__index = DisplayMatrixTemplate_list
function DisplayMatrixTemplate_list.new()
    local self = setmetatable({}, DisplayMatrixTemplate_list)
    self.elementWidth = 20
    self.elementHeight = 1
    self.elementSpacing = 0 -- does not work properly
    self.numberOfVisibleElements = 5
    self.scrollOnElements = true
    self.scrollBar = true
    self.scrollBarButtons = true
    self.scrollBarWidth = 1
    self.frameAroundList = true
    self.frameAroundScrollBar = true
    self.drawFrameAroundEveryElement = false
    self.elementsCentered = false
    self.elementColors =          {normal = {fg = 0xFFFFFF, bg = 0x000000}, active = {fg = 0x000000, bg = 0xFFFFFF}}
    self.scrollBarColors =        {normal = {fg = 0xFFFFFF, bg = 0x000000}, active = {fg = 0x000000, bg = 0xFFFFFF}}
    self.scrollBarButtonsColors = {normal = {fg = 0x000000, bg = 0xFFFFFF}, active = {fg = 0xFFFFFF, bg = 0x000000}}
    self.onListInteractionFunction = nil -- takes list object, element index, element object, display matrix as arguments
    self.elementsContent = {}
    self.listType = "no_action"
    return self
end

function DisplayMatrixTemplate_list:enumerateElements(toEnumerate)
    self.elementsContent = {}
    if type(toEnumerate) == "number" then
        for i = 1, toEnumerate do
            self.elementsContent[i] = {tostring(i) .. ") "}
        end
    elseif type(toEnumerate) == "table" then
        for i = 1, #toEnumerate do
            self.elementsContent[i] = {tostring(i) .. ") " .. tostring(toEnumerate[i])}
        end
    else
        error("toEnumerate must be a number or a table")
    end
end

function DisplayMatrixTemplate_list:setColors(palete, mainNormalColor, mainActiveColor)
    mainNormalColor = mainNormalColor or {fg = 0xFFFFFF, bg = 0x000000}
    mainActiveColor = mainActiveColor or {fg = mainNormalColor.bg, bg = mainNormalColor.fg}
    if palete == "basic" then
        self.scrollBarColors =        {normal = mainNormalColor, active = mainActiveColor}
        self.elementColors =          {normal = mainNormalColor, active = mainActiveColor}
        self.scrollBarButtonsColors = {normal = mainActiveColor, active = mainNormalColor}
    elseif palete == "standard" then
        self.scrollBarColors =        {normal = mainNormalColor, active = mainActiveColor}
        self.elementColors =          {normal = {fg = 0x000000, bg = 0x909090}, active = {fg = 0x000000, bg = 0xFFFFFF}}
        self.scrollBarButtonsColors = {normal = {fg = 0x000000, bg = 0x909090}, active = {fg = 0xFFFFFF, bg = 0x000000}}
    else
        error("Color palete must be one of: basic, standard")
    end
end

function DisplayMatrixTemplate_list:setType(type)
    if type == "single_select" or type == "multi_select" or type == "no_select" or type == "no_action" then
        self.listType = type
    else
        error("List type must be one of: single_select, multi_select, no_select, no_action")
    end
end

function DisplayMatrixTemplate_list:build()
    -- if self.onListInteractionFunction == nil and self.listType ~= "no_action" then
    --     error("onListInteractionFunction must be set")
    -- end

    if self.drawFrameAroundEveryElement then
        self.elementSpacing = self.elementSpacing + 1
    end

    local group = ElementGroup.new()
    local list = {}
    list.numberOfVisibleElements = self.numberOfVisibleElements
    list.topElementIndex = 1
    list.elementWidth = self.elementWidth
    list.elementHeight = self.elementHeight + self.elementSpacing
    list.elementSpacing = self.elementSpacing
    list.onListInteractionFunction = self.onListInteractionFunction
    list.elementsContent = self.elementsContent
    list.elementVisible = (function(self, index)
        return index >= self.topElementIndex and index < (self.topElementIndex + self.numberOfVisibleElements)
    end)

    local listGroup = ElementGroup.createGroup(self.numberOfVisibleElements, 1, self.elementWidth, self.elementHeight, 0, self.elementSpacing, self.drawFrameAroundEveryElement, self.elementsCentered)

    local scrollFunction = (function(self, displayMatrix, value)
        if value > 0 then
            if list.topElementIndex > 1 then
                displayMatrix.gpu.copy(listGroup.x, listGroup.y, list.elementWidth, list.elementHeight * (list.numberOfVisibleElements - 1) - list.elementSpacing, 0, list.elementHeight)
                list.topElementIndex = list.topElementIndex - 1
                for i = 1, list.numberOfVisibleElements do
                    listGroup.elements[i]:setContent(list.elementsContent[list.topElementIndex + i - 1])
                end
                list:drawElement(1, displayMatrix.gpu)
            end
        elseif value < 0 then
            if list.topElementIndex + list.numberOfVisibleElements <= #list.elementsContent then
                displayMatrix.gpu.copy(listGroup.x, listGroup.y + list.elementHeight, list.elementWidth, list.elementHeight * (list.numberOfVisibleElements - 1) - list.elementSpacing, 0, -list.elementHeight)
                list.topElementIndex = list.topElementIndex + 1
                for i = 1, list.numberOfVisibleElements do
                    listGroup.elements[i]:setContent(list.elementsContent[list.topElementIndex + i - 1])
                end
                list:drawElement(list.numberOfVisibleElements, displayMatrix.gpu)
            end
        end
    end)

    list.setContent = (function (self, newContent)
        self.elementsContent = newContent
        listGroup:setContent(newContent)
    end)

    list.scrollFunction = (function(self, displayMatrix, value)
        scrollFunction(self, displayMatrix, value)
    end)

    if self.listType == "single_select" then
        list.activeElement = nil

        list.drawElement = (function(self, listIndex, gpu)
            local elementIndex = listIndex + self.topElementIndex - 1
            if elementIndex == list.activeElement then
                listGroup.elements[listIndex]:drawActive(gpu)
            else
                listGroup.elements[listIndex]:drawNormal(gpu)
            end
        end)

        for i = 1, self.numberOfVisibleElements do
            listGroup.elements[i].action = (function(self, displayMatrix)
                local pressedIndex = list.topElementIndex + i - 1
                if self.content[1] == nil then
                    self:drawNormal(displayMatrix.gpu)
                    return
                end
                if list.activeElement == pressedIndex then
                    self:drawNormal(displayMatrix.gpu)
                    list.activeElement = nil
                elseif list.activeElement == nil then
                    self:drawActive(displayMatrix.gpu)
                    list.activeElement = pressedIndex
                else
                    if list:elementVisible(list.activeElement) then
                        listGroup.elements[list.activeElement - list.topElementIndex + 1]:drawNormal(displayMatrix.gpu)
                    end
                    self:drawActive(displayMatrix.gpu)
                    list.activeElement = pressedIndex
                end
                list.onListInteractionFunction(list, pressedIndex, self, displayMatrix)
            end)
        end
    elseif self.listType == "multi_select" then
        list.activeElements = {}

        list.drawElement = (function(self, listIndex, gpu)
            local elementIndex = listIndex + self.topElementIndex - 1
            if list.activeElements[elementIndex] then
                listGroup.elements[listIndex]:drawActive(gpu)
            else
                listGroup.elements[listIndex]:drawNormal(gpu)
            end
        end)

        for i = 1, self.numberOfVisibleElements do
            listGroup.elements[i].action = (function(self, displayMatrix)
                local pressedIndex = list.topElementIndex + i - 1
                if self.content[1] == nil then
                    self:drawNormal(displayMatrix.gpu)
                    return
                end
                if list.activeElements[pressedIndex] then
                    list.activeElements[pressedIndex] = nil
                    listGroup.elements[i]:drawNormal(displayMatrix.gpu)
                else
                    list.activeElements[pressedIndex] = true
                    listGroup.elements[i]:drawActive(displayMatrix.gpu)
                end
                list.onListInteractionFunction(list, pressedIndex, self, displayMatrix)
            end)
        end
    elseif self.listType == "no_select" then
        list.drawElement = (function(self, listIndex, gpu)
            listGroup.elements[listIndex]:drawNormal(gpu)
        end)

        for i = 1, self.numberOfVisibleElements do
            listGroup.elements[i].action = (function(self, displayMatrix)
                if self.content[1] == nil then
                    self:drawNormal(displayMatrix.gpu)
                    return
                end
                local pressedIndex = list.topElementIndex + i - 1
                self:drawNormal(displayMatrix.gpu)
                list.onListInteractionFunction(list, pressedIndex, self, displayMatrix)
            end)
        end
    elseif self.listType == "no_action" then
        list.drawElement = (function(self, listIndex, gpu)
            listGroup.elements[listIndex]:drawNormal(gpu)
        end)
    else
        error("List type must be one of: single_select, multi_select, no_select, no_action")
    end

    if self.frameAroundList then
        local frameElement = listGroup:createFrameElement(false)
        frameElement:setPosition(1, 1)
        group:addElement(frameElement, true)
    end

    listGroup:setColors(self.elementColors.normal, self.elementColors.active)
    listGroup:setContent(self.elementsContent)
    group:addElement(listGroup)


    if self.scrollBar then
        local scrollBarCharacter = string.rep("=", self.scrollBarWidth)
        if self.scrollBarButtons then
            local height = self.numberOfVisibleElements * list.elementHeight - list.elementSpacing - 2
            local scrollBar = DisplayElement.new()

            list.scrollFunction = (function(self, displayMatrix, value)
                scrollFunction(self, displayMatrix, value)
                if (#list.elementsContent == list.numberOfVisibleElements) then
                    return
                end
                local newPosition = math.floor((list.topElementIndex - 1) / (#list.elementsContent - list.numberOfVisibleElements) * (height - 1) + 1)
                scrollBar.content[list.scrollBarPosition] = ""
                list.scrollBarPosition = newPosition
                scrollBar.content[list.scrollBarPosition] = scrollBarCharacter
                scrollBar:drawNormal(displayMatrix.gpu)
            end)
            local scrollBarContent = {}
            list.scrollBarPosition = 1
            scrollBarContent[1] = scrollBarCharacter
            for i = 2, height - 1 do
                scrollBarContent[i] = ""
            end
            scrollBar:setWidth(self.scrollBarWidth)
            scrollBar:setHeight(height)
            scrollBar.drawFrame = false
            scrollBar.scroll = list.scrollFunction
            scrollBar:setColors(self.scrollBarColors.normal, self.scrollBarColors.active)
            scrollBar:setContent(scrollBarContent)
            scrollBar:setPosition(1, 2)

            local scrollUpButton = DisplayElement.new()
            scrollUpButton:setWidth(self.scrollBarWidth)
            scrollUpButton:setHeight(1)
            scrollUpButton:setContent({"^"})
            scrollUpButton:setPosition(1, 1)
            scrollUpButton.action = (function(self, displayMatrix)
                list.scrollFunction(nil, displayMatrix, 1)
                self:drawNormal(displayMatrix.gpu)
            end)
            scrollUpButton:setColors(self.scrollBarButtonsColors.normal, self.scrollBarButtonsColors.active)

            local scrollDownButton = DisplayElement.new()
            scrollDownButton:setWidth(self.scrollBarWidth)
            scrollDownButton:setHeight(1)
            scrollDownButton:setContent({"v"})
            scrollDownButton:setPosition(1, height + 2)
            scrollDownButton.action = (function(self, displayMatrix)
                list.scrollFunction(nil, displayMatrix, -1)
                self:drawNormal(displayMatrix.gpu)
            end)
            scrollDownButton:setColors(self.scrollBarButtonsColors.normal, self.scrollBarButtonsColors.active)

            local scrollBarGroup = ElementGroup.new()
            scrollBarGroup:addElement(scrollBar)
            scrollBarGroup:addElement(scrollUpButton)
            scrollBarGroup:addElement(scrollDownButton)
            scrollBarGroup:setPosition(listGroup.x + self.elementWidth + 1, listGroup.y)
            if self.frameAroundScrollBar then
                scrollBarGroup:createFrameElement(true)
            end

            list.scrollBar = scrollBarGroup
            group:addElement(scrollBarGroup)


        else
            local height = self.numberOfVisibleElements * list.elementHeight - list.elementSpacing
            local scrollBar = DisplayElement.new()

            list.scrollFunction = (function(self, displayMatrix, value)
                scrollFunction(self, displayMatrix, value)
                if (#list.elementsContent == list.numberOfVisibleElements) then
                    return
                end
                local newPosition = math.floor((list.topElementIndex - 1) / (#list.elementsContent - list.numberOfVisibleElements) * (height - 1) + 1)
                scrollBar.content[list.scrollBarPosition] = ""
                list.scrollBarPosition = newPosition
                scrollBar.content[list.scrollBarPosition] = scrollBarCharacter
                scrollBar:drawNormal(displayMatrix.gpu)
            end)

            local scrollBarContent = {}
            list.scrollBarPosition = 1
            scrollBarContent[1] = scrollBarCharacter
            for i = 2, height - 1 do
                scrollBarContent[i] = ""
            end
            
            scrollBar:setWidth(self.scrollBarWidth)
            scrollBar:setHeight(height)
            scrollBar.drawFrame = self.frameAroundScrollBar
            scrollBar.scroll = list.scrollFunction
            scrollBar:setColors(self.scrollBarColors.normal, self.scrollBarColors.active)
            scrollBar:setContent(scrollBarContent)
            scrollBar:setPosition(listGroup.x + self.elementWidth + 1, listGroup.y)
            
            list.scrollBar = scrollBar
            group:addElement(scrollBar)
        end
    end

    if self.scrollOnElements then
        for i = 1, self.numberOfVisibleElements do
            listGroup.elements[i].scroll = list.scrollFunction
        end
    end

    list.group = group
    return list
end




-- COUNTDOWN TEMPLATE
local DisplayMatrixTemplate_countdown = {}
DisplayMatrixTemplate_countdown.__index = DisplayMatrixTemplate_countdown
function DisplayMatrixTemplate_countdown.new()
    local self = setmetatable({}, DisplayMatrixTemplate_countdown)
    self.countdown = 10
    self.countdownColors = {normal = {fg = 0xFFFFFF, bg = 0x000000}, active = {fg = 0x000000, bg = 0xFFFFFF}}
    self.onCountdownEndFunction = nil
    return self
end


-- DISPLAY MATRIX TEMPLATES
local DisplayMatrixTemplates = {}
function DisplayMatrixTemplates.new(type)
    local typeTable = {
        keypad = DisplayMatrixTemplate_keypad,
        list = DisplayMatrixTemplate_list,
        -- countdown = DisplayMatrixTemplate_countdown
    }

    local templateBuilder = typeTable[type]
    if templateBuilder == nil then
        error("Invalid template type: " .. type)
    end

    return templateBuilder.new()
end

return DisplayMatrixTemplates