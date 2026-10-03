local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local StateSchema = require(ReplicatedStorage.Shared.StateSchema)

local DataService = {}
local store = DataStoreService:GetDataStore(GameConfig.DataStoreName)
local states = {}

function DataService.get(player) return states[player] end
function DataService.load(player)
    local loaded
    local ok, result = pcall(function() return store:GetAsync("Player_" .. player.UserId) end)
    if ok then loaded = result else warn("Data load failed for " .. player.Name .. ": " .. tostring(result)) end
    states[player] = StateSchema.sanitize(loaded)
    return states[player]
end
function DataService.save(player)
    local state = states[player]
    if not state then return false end
    local payload = StateSchema.sanitize(state)
    local ok, result = pcall(function() store:UpdateAsync("Player_" .. player.UserId, function() return payload end) end)
    if not ok then warn("Data save failed for " .. player.Name .. ": " .. tostring(result)) end
    return ok
end
function DataService.clear(player) states[player] = nil end

Players.PlayerRemoving:Connect(function(player) DataService.save(player); DataService.clear(player) end)
game:BindToClose(function() for _, player in Players:GetPlayers() do DataService.save(player) end end)

return DataService
