DoorDatabase = require("DoorDatabase")
PendingOperation = require("PendingOperation")
door = require("door")
UserDatabaseServerProxy = require("UserDatabaseServerProxy")

event = require("event")
component = require("component")
term = require("term")
thread = require("thread")
text = require("text")

local DoorAccessServer = {
    DB,
    pending,
    UD,
    managerInterfaceThread,
    operationExecutionThread,
    operationListennerThread,
    running
}

function DoorAccessServer:new(o, UDPort, UDAddr, modem)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.DB = DoorDatabase:new(nil)
    o.pending = {}
    o.UD = UserDatabaseServerProxy:new(nil, UDPort, UDAddr, modem)
    o.running = false
    return o
end

function DoorAccessServer:managerInterfaceF()
    os.sleep(1)
    while self.running do
        term.write("\n> ")
        local userIn = term.read()
        if userIn == "exit\n" then
            term.write("exiting...\n")
            self:stop()
        elseif userIn == "add\n" then
            term.write("name: ")
            local name = term.read()
            term.write("access: ")
            local access = term.read()
            local newDoor = door:new(nil, text.trim(name), text.trim(access))
            term.write("detecting...\n")
            self.operationListennerThread:suspend()
            newDoor:detect()
            self.DB:add(newDoor)
            term.write("\nadded:\n")
            newDoor:print()
            self.operationListennerThread:resume()
        elseif userIn == "remove\n" then
            term.write("name: ")
            local name = term.read()
            self.DB:delete(text.trim(name))
        elseif userIn == "save\n" then
            self.DB:save("DB.txt")
            term.write("saved\n")
        elseif userIn == "drop\n" then
            self.DB:drop()
            term.write("all dropped\n")
        else
            term.write("unrecognized command: "..userIn)
        end
    end
end

function DoorAccessServer:operationExecutionF()
    while self.running do
        os.sleep(0.5)
        for i, v in pairs(self.pending) do
            v:execute(self)
            table.remove(self.pending, i)
        end
    end
end

function DoorAccessServer:operationListennerF()
    while self.running do
        local eventName, addr, type = event.pull(nil, "component")
        if type == "filesystem" then
            if eventName == "component_added" then
                table.insert(self.pending, PendingOperation:new(nil, true, addr))
            elseif eventName == "component_removed" then
                table.insert(self.pending, PendingOperation:new(nil, false, addr))
            end
        end
    end
end


function DoorAccessServer:threadErrorHandler(fun)
    local status, err = xpcall(fun, debug.traceback, self)
    if status == false then
        self:stop()
        term.clear()
        term.write(err)
        term.write("\n")
    end
end

function DoorAccessServer:start()
    self.running = true
    self.managerInterfaceThread = thread.create(self.threadErrorHandler, self, self.managerInterfaceF)
    self.operationExecutionThread = thread.create(self.threadErrorHandler, self, self.operationExecutionF)
    self.operationListennerThread = thread.create(self.threadErrorHandler, self, self.operationListennerF)
    term.write("all threads have started\n")
end

function DoorAccessServer:join()
    self.managerInterfaceThread:join()
    self.operationExecutionThread:join()
    self.operationListennerThread:join()
    term.write("all threads have joined\n")
end

function DoorAccessServer:stop()
    self.running = false
    self.managerInterfaceThread:kill()
    self.operationExecutionThread:kill()
    self.operationListennerThread:kill()
end

local DAS = DoorAccessServer:new(nil, 1, "4d13909d-36a6-4743-9810-e0205692b4d5", component.modem)
DAS.DB:load("DB.txt")
DAS:start()
DAS:join()

-- return DoorAccessServer