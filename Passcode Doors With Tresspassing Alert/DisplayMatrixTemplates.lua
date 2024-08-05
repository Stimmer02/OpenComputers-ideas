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
        numberButtons:createFrameElement()
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
    self.elementSpacing = 0
    self.numberOfElements = 5
    self.numberOfVisibleElements = 5
    self.scrollBar = true
    self.scrollBarButtons = true
    self.scrollBarWidth = 1
    self.frameAroundList = true
    self.frameAroundScrollBar = true
    self.drawFrameAroundEveryElement = false
    self.scrollBarColors =        {normal = {fg = 0xFFFFFF, bg = 0x000000}, active = {fg = 0x000000, bg = 0xFFFFFF}}
    self.elementColors =          {normal = {fg = 0xFFFFFF, bg = 0x000000}, active = {fg = 0x000000, bg = 0xFFFFFF}}
    self.scrollBarButtonsColors = {normal = {fg = 0x000000, bg = 0xFFFFFF}, active = {fg = 0xFFFFFF, bg = 0x000000}}
    self.onListInteractionFunction = nil
    self.listType = "single_select"
    return self
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
        self.elementColors =          {normal = {fg = 0x5A5A5A, bg = 0x000000}, active = {fg = 0x000000, bg = 0xFFFFFF}}
        self.scrollBarButtonsColors = {normal = {fg = 0x000000, bg = 0x5A5A5A}, active = {fg = 0xFFFFFF, bg = 0x000000}}
    else
        error("Color palete must be one of: basic, standard")
    end
end

function DisplayMatrixTemplate_list:setType(type)
    if type == "single_select" or type == "multi_select" or type == "no_select" then
        self.listType = type
    else
        error("List type must be one of: single_select, multi_select, no_select")
    end
end

function DisplayMatrixTemplate_list:build()
end


-- DISPLAY MATRIX TEMPLATES
local DisplayMatrixTemplates = {}
function DisplayMatrixTemplates.new(type)
    local typeTable = {
        keypad = DisplayMatrixTemplate_keypad
    }

    local templateBuilder = typeTable[type]
    if templateBuilder == nil then
        error("Invalid template type: " .. type)
    end

    return templateBuilder.new()
end

return DisplayMatrixTemplates