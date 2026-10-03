local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local StateSchema = require(ReplicatedStorage.Shared.StateSchema)

local DataService = {}
local states = {}
local MAX_ATTEMPTS = 3
local store
local useMemoryFallback = RunService:IsStudio() and (game.GameId == 0 or game.PlaceId == 0)

if not useMemoryFallback then
    local ok, result = pcall(function()
        return DataStoreService:GetDataStore(GameConfig.DataStoreName)
    end)
    if ok then
        store = result
    else
        useMemoryFallback = true
        warn("DataStore unavailable; using in-memory progression for this server: " .. tostring(result))
    end
else
    warn("Unpublished Studio place detected; using in-memory progression. Publish the place and enable API Services to test persistence.")
end

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

function DataService.get(player)
    return states[player]
end

function DataService.load(player)
    if useMemoryFallback then
        states[player] = StateSchema.new()
        return states[player]
    end

    local ok, loaded = retry(function()
        return store:GetAsync("Player_" .. player.UserId)
    end, "Data load failed for " .. player.Name)
    if not ok then
        useMemoryFallback = true
        states[player] = StateSchema.new()
    else
        states[player] = StateSchema.sanitize(loaded)
    end
    return states[player]
end

function DataService.save(player)
    local state = states[player]
    if not state then return false end
    if useMemoryFallback then return true end

    local payload = StateSchema.sanitize(state)
    local ok = retry(function()
        return store:UpdateAsync("Player_" .. player.UserId, function()
            return payload
        end)
    end, "Data save failed for " .. player.Name)
    if not ok then useMemoryFallback = true end
    return ok
end

function DataService.clear(player)
    states[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
    DataService.save(player)
    DataService.clear(player)
end)

game:BindToClose(function()
    for _, player in Players:GetPlayers() do
        DataService.save(player)
    end
end)

return DataService
