local GameConfig = {
    DataStoreName = "MergeDominion_MVP_v1",
    StartingCurrency = 120,
    SoldierCost = 25,
    PassiveIncomeSeconds = 20,
    PassiveIncomeAmount = 15,
    MaxSoldierLevel = 3,
    SoldierStats = {
        [1] = {Health = 30, Attack = 10, Color = Color3.fromRGB(86, 184, 255)},
        [2] = {Health = 70, Attack = 25, Color = Color3.fromRGB(132, 255, 164)},
        [3] = {Health = 150, Attack = 65, Color = Color3.fromRGB(255, 190, 75)},
    },
    EnemyBases = {
        {Id = "EmberOutpost", Name = "Ember Outpost", Position = Vector3.new(0, 0, -105), Defenders = {{Level = 1, Count = 2}}, Reward = 60},
        {Id = "Stonewatch", Name = "Stonewatch", Position = Vector3.new(105, 0, -25), Defenders = {{Level = 2, Count = 3}}, Reward = 110},
        {Id = "Frostkeep", Name = "Frostkeep", Position = Vector3.new(-105, 0, 35), Defenders = {{Level = 2, Count = 5}}, Reward = 180},
    },
}
return GameConfig
