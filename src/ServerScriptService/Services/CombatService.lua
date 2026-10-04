local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local CombatService = {}

local function armyPower(state)
    local power = 0
    for level, count in pairs(state.Soldiers) do
        local stats = GameConfig.SoldierStats[level]
        if stats then power += stats.Attack * count end
    end
    return power
end

local function enemyPower(city)
    local power = 0
    for _, group in ipairs(city.Defenders) do
        local stats = GameConfig.SoldierStats[group.Level]
        if stats then power += stats.Attack * group.Count end
    end
    return power
end

function CombatService.resolve(state, city)
    local playerPower = armyPower(state)
    local targetPower = enemyPower(city)
    local won = playerPower >= targetPower and playerPower > 0
    return {
        Won = won,
        PlayerPower = playerPower,
        EnemyPower = targetPower,
        Reward = city.Reward,
        Defenders = city.Defenders,
    }
end

return CombatService
