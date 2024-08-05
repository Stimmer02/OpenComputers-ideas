event = require("event")

UserDatabaseServerProxy = {port, addr, modem}

function UserDatabaseServerProxy:new(o, port, addr, modem)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.port = port
    o.addr = addr
    o.modem = modem
    return o
end

function UserDatabaseServerProxy:get(name, passwd, accessKey)
    self.modem.open(self.port)
    self.modem.send(self.addr, self.port, 1, name, passwd, accessKey)
    local _, _, _, _, _, out = event.pull(5, "modem_message")
    print("message rec:", out)
    self.modem.close(self.port)

    if out == nil then
        out = false
    end
    return out
end

return UserDatabaseServerProxy