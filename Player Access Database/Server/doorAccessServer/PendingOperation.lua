fs = require("filesystem")
serialization = require("serialization")

pendingOperation = {
    open,
    mediaAddr,
}

function pendingOperation:new(o, open, mediaAddr)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.open = open
    o.mediaAddr = mediaAddr
    return o
end

function pendingOperation:execute(system)
    if self.open then
        local d = system.DB:findByCurrentMedia(self.mediaAddr)
        if d ~= nil then
            local mediaSub = string.sub(self.mediaAddr, 1, 3)
            if fs.exists("/mnt/"..mediaSub.."/USERDATA") == false then
                return
            end

            local file = io.open("/mnt/"..mediaSub.."/USERDATA", "rb")
            local name = serialization.unserialize(file:read())
            local passwd = serialization.unserialize(file:read())
            file:close()
            if system.UD:get(name, passwd, d.access) then
                door.setRed(d, 15)
                d.lastMedia = self.mediaAddr
            end
        end
    else
        local d = system.DB:findByLastMedia(self.mediaAddr)
        if d ~= nil then
            door.setRed(d, 0)
            d.lastMedia = nil
        end
    end
end

return pendingOperation