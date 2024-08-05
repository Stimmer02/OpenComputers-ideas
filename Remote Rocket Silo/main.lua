local SecureConnection = require("SecureConnection")
local serialization = require("serialization")
local SiloAray = require("SiloArray")

local siloArray = SiloAray.new("siloDatabase.txt")


print("Missiles in storage:")
local missiles = siloArray:getMissiles()
table.sort(missiles)
for missileName, count in pairs(missiles) do
    print(missileName .. ":", count)
end

local connection = SecureConnection.new("userDatabase.txt")

while true do
    local message = connection:waitForMessageAndHandleDatabaseQuerries()

    if message == nil then
        print("Interrupted")
        break
    elseif message.header == "launch" then
        local cordinates = serialization.unserialize(message.data[1])
        if cordinates == nil then
            print("Failed to unserialize message")
            connection:send(message.originID, "launch", "failed", "Failed to unserialize message")
            break
        end
        print("Received launch request: " .. math.modf(cordinates.x) .. ", " .. math.modf(cordinates.z))


        local success, error = siloArray:launchSingleMissile(message.data[2], cordinates.x, cordinates.z)

        if success ~= true then
            print("Failed to launch missile:")
            -- for i = 1, #error do
            --     print(error[i])
            -- end
            print(error)
            connection:send(message.originID, "launch", "failed", serialization.serialize(error))
        else
            print("Request succeded")
            connection:send(message.originID, "launch", "confirmed", cordinates.name)
        end
    elseif message.header == "getMissiles" then
        missiles = siloArray:getMissiles()
        connection:send(message.originID, "missiles", serialization.serialize(missiles))
    end
end