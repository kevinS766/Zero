-- export_payload.luau
-- Extracts all LuaSourceContainers from Roblox Studio services and posts them to http://127.0.0.1:34567

local HttpService = game:GetService("HttpService")

local services = {
    { name = "ServerScriptService", svc = game:GetService("ServerScriptService") },
    { name = "ReplicatedStorage", svc = game:GetService("ReplicatedStorage") },
    { name = "StarterPlayer", svc = game:GetService("StarterPlayer") },
    { name = "StarterGui", svc = game:GetService("StarterGui") },
    { name = "ReplicatedFirst", svc = game:GetService("ReplicatedFirst") },
    { name = "ServerStorage", svc = game:GetService("ServerStorage") },
}

local totalExported = 0
local summary = {}

for _, item in ipairs(services) do
    local scripts = {}
    for _, desc in ipairs(item.svc:GetDescendants()) do
        if desc:IsA("LuaSourceContainer") then
            local parts = {}
            local cur = desc
            while cur and cur ~= item.svc do
                table.insert(parts, 1, cur.Name)
                cur = cur.Parent
            end
            table.insert(scripts, {
                service = item.name,
                path = table.concat(parts, "/"),
                class = desc.ClassName,
                source = desc.Source
            })
        end
    end

    if #scripts > 0 then
        totalExported = totalExported + #scripts
        local payload = HttpService:JSONEncode({ scripts = scripts })
        local response = HttpService:PostAsync("http://127.0.0.1:34567", payload, Enum.HttpContentType.ApplicationJson)
        table.insert(summary, item.name .. ": " .. #scripts)
    end
end

return "Export finished. Total: " .. totalExported .. " (" .. table.concat(summary, ", ") .. ")"
