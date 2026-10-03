local GameConfig = {
    DataStoreName = "MergeDominion_MVP_v1",
    StartingCurrency = 120,
    MaxSoldiers = 20,
    GenerationIntervals = {60, 50, 40, 30, 20, 15, 10},
    GenerationUpgradeCosts = {50, 75, 100, 125, 150, 200},
    DefaultWalkSpeed = 16,
    SprintWalkSpeed = 24,
    MaxSoldierLevel = 3,
    SoldierStats = {
        [1] = {Name = "Rookie", Health = 30, Attack = 10, Color = Color3.fromRGB(86, 184, 255), AccentColor = Color3.fromRGB(190, 235, 255)},
        [2] = {Name = "Veteran", Health = 70, Attack = 25, Color = Color3.fromRGB(132, 255, 164), AccentColor = Color3.fromRGB(224, 255, 170)},
        [3] = {Name = "Champion", Health = 150, Attack = 65, Color = Color3.fromRGB(255, 190, 75), AccentColor = Color3.fromRGB(255, 238, 151)},
    },
    EnemyBases = {
        {Id = "EmberOutpost", Name = "Ember Outpost", Position = Vector3.new(0, 0, -105), Defenders = {{Level = 1, Count = 2}}, Reward = 60},
        {Id = "Stonewatch", Name = "Stonewatch", Position = Vector3.new(105, 0, -25), Defenders = {{Level = 2, Count = 3}}, Reward = 110},
        {Id = "Frostkeep", Name = "Frostkeep", Position = Vector3.new(-105, 0, 35), Defenders = {{Level = 2, Count = 5}}, Reward = 180},
    },
}
return GameConfig
