local DisplayManager = require "DisplayManager"
local term = require("term")

local dm = DisplayManager:new(nil)
dm:autoAdd()
dm:doMultipleForAll({term.clear, dm.gpu.setResolution}, {{}, {1, 1}})
dm:identify()
os.sleep(5)
dm:reset(true)
