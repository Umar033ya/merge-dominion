local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local StateSchema = require(ReplicatedStorage.Shared.StateSchema)

local DataService = {}
local store = DataStoreService:GetDataStore(GameConfig.DataStoreName)
local states = {}
local MAX_ATTEMPTS = 3

local function retry(operation, description)
    local lastError
    for attempt = 1, MAX_ATTEMPTS do
        local ok, result = pcall(operation)
        if ok then return true, result end
        lastError = result
        if attempt < MAX_ATTEMPTS then task.wait(attempt) end
    end
    warn(description .. " after " .. MAX_ATTEMPTS .. " attempts: " .. tostring(lastError))
    return false, lastError
end

function DataService.get(player) return states[player] end
function DataService.load(player)
    local loaded
    local ok, result = retry(function() return store:GetAsync("Player_" .. player.UserId) end, "Data load failed for " .. player.Name)
    if ok then loaded = result end
    states[player] = StateSchema.sanitize(loaded)
    return states[player]
end
function DataService.save(player)
    local state = states[player]
    if not state then return false end
    local payload = StateSchema.sanitize(state)
    local ok = retry(function()
        return store:UpdateAsync("Player_" .. player.UserId, function() return payload end)
    end, "Data save failed for " .. player.Name)
    return ok
end
function DataService.clear(player) states[player] = nil end

Players.PlayerRemoving:Connect(function(player) DataService.save(player); DataService.clear(player) end)
game:BindToClose(function() for _, player in Players:GetPlayers() do DataService.save(player) end end)

return DataService
