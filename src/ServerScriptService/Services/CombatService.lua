local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local CombatService = {}

local function armyPower(state)
    local power = 0
    for level, count in pairs(state.Soldiers) do power += (GameConfig.SoldierStats[level].Attack * count) end
    return power
end
local function enemyPower(enemy)
    local power = 0
    for _, group in ipairs(enemy.Defenders) do power += GameConfig.SoldierStats[group.Level].Attack * group.Count end
    return power
end
function CombatService.resolve(state, enemy)
    local playerPower, targetPower = armyPower(state), enemyPower(enemy)
    return {
        Won = playerPower >= targetPower and playerPower > 0,
        PlayerPower = playerPower,
        EnemyPower = targetPower,
        Reward = enemy.Reward,
    }
end
return CombatService
