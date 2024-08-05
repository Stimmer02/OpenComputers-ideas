local ModemMessageFilter = {}
ModemMessageFilter.__index = ModemMessageFilter

function ModemMessageFilter.new(type, localAddr, remoteAddr, port, closerThan, furtherThan, messageHeader)
    local self = setmetatable({}, ModemMessageFilter)
    self.type = type
    self.localAddr = localAddr
    self.remoteAddr = remoteAddr
    self.port = port
    self.closerThan = closerThan
    self.furtherThan = furtherThan
    self.messageHeader = messageHeader
    return self
end

function ModemMessageFilter:match(type, localAddr, remoteAddr, port, distance, messageHeader)
    if self.type and self.type ~= type then
        return false
    end
    if self.localAddr and self.localAddr ~= localAddr then
        return false
    end
    if self.remoteAddr and self.remoteAddr ~= remoteAddr then
        return false
    end
    if self.port and self.port ~= port then
        return false
    end
    if self.closerThan and self.closerThan >= distance then
        return false
    end
    if self.furtherThan and self.furtherThan <= distance then
        return false
    end
    if self.messageHeader and self.messageHeader ~= messageHeader then
        return false
    end
    return true
end

return ModemMessageFilter