local component = require("component")

Display = {screen, screenAddr, cursorPos = {x, y}, resolution = {x, y}, startResolution = {x, y}}
function Display:new(o, screenAddr, startResolution, cursorPos)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.screenAddr = screenAddr
    o.screen = component.proxy(screenAddr)
    o.startResolution = startResolution
    o.resolution = startResolution
    o.cursorPos = cursorPos or {x = 1, y = 1}

    return o
end

return Display
