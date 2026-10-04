local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local StateSchema = {}

function StateSchema.new()
    local soldiers = {}
    for level = 1, GameConfig.MaxSoldierLevel do soldiers[level] = 0 end
    return {
        Currency = GameConfig.StartingCurrency,
        Soldiers = soldiers,
        Conquered = {},
        GenerationLevel = 1,
    }
end

function StateSchema.sanitize(raw)
    local state = StateSchema.new()
    if type(raw) ~= "table" then return state end

    state.Currency = math.max(0, math.floor(tonumber(raw.Currency) or state.Currency))
    local generationLevel = math.floor(tonumber(raw.GenerationLevel) or 1)
    state.GenerationLevel = math.clamp(generationLevel, 1, #GameConfig.GenerationIntervals)

    local remainingCapacity = GameConfig.MaxSoldiers
    if type(raw.Soldiers) == "table" then
        for level = 1, GameConfig.MaxSoldierLevel do
            local requested = math.max(0, math.floor(tonumber(raw.Soldiers[level]) or 0))
            local accepted = math.min(requested, remainingCapacity)
            state.Soldiers[level] = accepted
            remainingCapacity -= accepted
        end
    end

    if type(raw.Conquered) == "table" then
        for id, conquered in pairs(raw.Conquered) do
            if conquered == true then state.Conquered[tostring(id)] = true end
        end
    end
    return state
end

return StateSchema
