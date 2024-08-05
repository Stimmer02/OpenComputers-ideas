comp = require("component")


for a, v in pairs(comp.list()) do
     if v == "tunnel" then
         print(comp.proxy(a).getChannel())
     end
end