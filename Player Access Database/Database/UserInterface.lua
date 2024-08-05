text = require("text")

UserInterface = {
    commands,
    object
}

function UserInterface:new(o, object)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.object = object
    o.commands = {}
    return o
end

function UserInterface:add(command)
    table.insert(self.commands, command)
end

function UserInterface:resolveInput(userInput)
    tokenizedInput = text.tokenize(userInput)
    for _,v in pairs(self.commands) do
        if v:exec(tokenizedInput, self.object) then
            return true
        end
    end
    return false
end

return UserInterface