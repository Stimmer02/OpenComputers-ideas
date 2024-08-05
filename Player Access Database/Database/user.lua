function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


local user = {
    name,
    passwd,
    access
}

function user:new(o, name, passwd, access)
    local o = o or {}
    setmetatable(o, {__index = self})
    o.passwd = passwd--[[component.data.md5(passwd)]]
    o.name = name
    o.access = shallowcopy(access)
    return o
end

UserDatabase = {
    emptyAccessMap,
    data
}

return user