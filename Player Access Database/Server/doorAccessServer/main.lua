local DoorAccessServer = require("DoorAccessServer")

local DAS = DoorAccessServer:new(nil)
DAS:start()
print("joining...")
DAS:join()