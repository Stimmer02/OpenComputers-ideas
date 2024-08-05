local comp = require("component")
local event = require("event")
local thread = require("thread")
local sides  = require("sides")

local DisplayElement = require("DisplayElement")
local DisplayMatrix = require("DisplayMatrix")
local ElementGroup = require("ElementGroup")
local DisplayMatrixTemplates = require("DisplayMatrixTemplates")

local function loadConfig(configFile)
    local config = {}
    local file = io.open(configFile, "r")
    if file == nil then
        return nil
    end

    for line in file:lines() do
        local key, value = line:match("([^=]+)=([^=]+)")
        config[key] = value
    end

    file:close()
    return config
end

local config = loadConfig("./config.txt")
if config == nil then
    error("Failed to load config file")
end
if config.door == nil then
    error("Door address not found in config file")
end
if config.detonator == nil then
    error("Detonator address not found in config file")
end


local door = comp.proxy(config.door)
local detonator = comp.proxy(config.detonator)
local sensor = comp.motion_sensor
local dataCard = comp.data

if door == nil then
    error("Failed to load door")
end
if detonator == nil then
    error("Failed to load detonator")
end
if sensor == nil then
    error("Failed to load sensor")
end
if dataCard == nil then 
    error("Failed to load data card")
end

sensor.setSensitivity(0)
print("Door: " .. door.address)
print("Detonator: " .. detonator.address)


local keypadBuilder = DisplayMatrixTemplates.new("keypad")
keypadBuilder.doIfPasswordCorrectFunction = function(keypad)
    if keypad.active then
        keypad.active = false
        door.setOutput({0, 0, 0, 0, 0, 0})
    else
        keypad.active = true
        door.setOutput({15, 15, 15, 15, 15, 15})
    end
end
keypadBuilder.doIfPasswordIncorrectFunction = function(keypad) end
keypadBuilder:setBasicPasswordCheckFunction(config.password or "000")
keypadBuilder.writeToDisplayFunction = function(keypad, state)
    if state  == 0 then
        if keypad.active then
            return "LOCKED"
        else
            return "UNLOCKED"
        end
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
local keypad = keypadBuilder:build()
keypad.active = door.getInput(sides.top) ~= 0


local displayMatrix = DisplayMatrix.new(comp.gpu)
displayMatrix:setDims(17, 16)
keypad.group:setPosition(0, 0)
displayMatrix:addGroup(keypad.group)
displayMatrix:draw()


local threadRunning = true

local function sensorThread()
    while threadRunning do
        local type = event.pullMultiple("motion", "interrupted")
        if type == "interrupted" then
            threadRunning = false
        elseif keypad.active then
            detonator.setOutput({15, 15, 15, 15, 15, 15})
            os.sleep(1)
            detonator.setOutput({0, 0, 0, 0, 0, 0})
        end
    end
end
local sensorThreadHandle = thread.create(sensorThread)
displayMatrix:main(true)
threadRunning = false
sensorThreadHandle:join()
