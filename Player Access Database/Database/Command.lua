Command = {
    keyword,
    func
}

function Command:new(o, keyword, func)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.keyword = keyword
    o.func = func
    return o
end

function Command:exec(args, object)
    if self.keyword == args[1] then
        self.func(args, object)
        return true
    else
        return false
    end
end


return Command

