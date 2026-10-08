local GameConfig = {
    DataStoreName = "MergeDominion_MVP_v1",
    StartingCurrency = 120,
    MaxSoldiers = 20,
    GenerationIntervals = {60, 50, 40, 30, 20, 15, 10},
    GenerationUpgradeCosts = {50, 75, 100, 125, 150, 200},
    GenerationLevelUpgradeCosts = {},
    DefaultWalkSpeed = 16,
    SprintWalkSpeed = 24,
    MaxSoldierLevel = 20,
    CityAttackCooldown = 8,
    CityIncomeSeconds = 60,
    ArmyTravelSeconds = 8,
    BattleSeconds = 5,
    MainBasePosition = Vector3.new(0, 0, 80),
    SoldierYardPosition = Vector3.new(0, 0, 52),
    SoldierStats = {},
    EnemyCities = {
        {Id = "EmberOutpost", Name = "Ember Outpost", Position = Vector3.new(0, 0, -115), Defenders = {{Level = 1, Count = 4}, {Level = 2, Count = 2}}, Reward = 60, IncomePerMinute = 25, Theme = "Ember"},
        {Id = "Stonewatch", Name = "Stonewatch", Position = Vector3.new(120, 0, -55), Defenders = {{Level = 2, Count = 4}, {Level = 3, Count = 2}}, Reward = 90, IncomePerMinute = 40, Theme = "Stone"},
        {Id = "Frostkeep", Name = "Frostkeep", Position = Vector3.new(-120, 0, -55), Defenders = {{Level = 3, Count = 4}, {Level = 4, Count = 2}}, Reward = 120, IncomePerMinute = 55, Theme = "Frost"},
        {Id = "Sunspire", Name = "Sunspire", Position = Vector3.new(190, 0, 25), Defenders = {{Level = 4, Count = 4}, {Level = 5, Count = 2}}, Reward = 155, IncomePerMinute = 70, Theme = "Sun"},
        {Id = "NightfallCitadel", Name = "Nightfall Citadel", Position = Vector3.new(-190, 0, 25), Defenders = {{Level = 5, Count = 4}, {Level = 7, Count = 2}}, Reward = 195, IncomePerMinute = 85, Theme = "Night"},
        {Id = "Ironvale", Name = "Ironvale", Position = Vector3.new(225, 0, 145), Defenders = {{Level = 6, Count = 4}, {Level = 8, Count = 2}}, Reward = 240, IncomePerMinute = 105, Theme = "Iron"},
        {Id = "Moonharbor", Name = "Moonharbor", Position = Vector3.new(-225, 0, 145), Defenders = {{Level = 7, Count = 4}, {Level = 9, Count = 2}}, Reward = 285, IncomePerMinute = 125, Theme = "Moon"},
        {Id = "Cindercrest", Name = "Cindercrest", Position = Vector3.new(150, 0, 255), Defenders = {{Level = 9, Count = 4}, {Level = 11, Count = 2}}, Reward = 335, IncomePerMinute = 150, Theme = "Cinder"},
        {Id = "VerdantReach", Name = "Verdant Reach", Position = Vector3.new(-150, 0, 255), Defenders = {{Level = 10, Count = 4}, {Level = 12, Count = 2}}, Reward = 390, IncomePerMinute = 180, Theme = "Verdant"},
        {Id = "Dragonspire", Name = "Dragonspire", Position = Vector3.new(0, 0, 335), Defenders = {{Level = 13, Count = 4}, {Level = 16, Count = 3}, {Level = 19, Count = 1}}, Reward = 500, IncomePerMinute = 230, Theme = "Dragon"},
    },
}

local palettes = {
    {Color = Color3.fromRGB(86, 184, 255), AccentColor = Color3.fromRGB(190, 235, 255), Name = "Rookie"},
    {Color = Color3.fromRGB(132, 255, 164), AccentColor = Color3.fromRGB(224, 255, 170), Name = "Scout"},
    {Color = Color3.fromRGB(255, 190, 75), AccentColor = Color3.fromRGB(255, 238, 151), Name = "Champion"},
    {Color = Color3.fromRGB(205, 135, 255), AccentColor = Color3.fromRGB(239, 205, 255), Name = "Guardian"},
    {Color = Color3.fromRGB(255, 112, 151), AccentColor = Color3.fromRGB(255, 198, 216), Name = "Knight"},
}
local levelNames = {"Recruit", "Trooper", "Swordsman", "Archer", "Vanguard", "Paladin", "Ranger", "Sentinel", "Captain", "Warden", "Elite", "Tactician", "Commander", "Marshal", "General", "War Chief", "Mythic", "Arcane", "Legendary", "Hero"}
for level = 1, GameConfig.MaxSoldierLevel do
    local palette = palettes[((level - 1) % #palettes) + 1]
    local tier = math.floor((level - 1) / 5)
    GameConfig.SoldierStats[level] = {
        Name = levelNames[level] or palette.Name,
        Health = 30 + level * 18 + tier * 12,
        Attack = 10 + level * 8 + tier * 5,
        Color = palette.Color,
        AccentColor = palette.AccentColor,
        Tier = tier,
    }
    if level < GameConfig.MaxSoldierLevel then GameConfig.GenerationLevelUpgradeCosts[level] = 150 + level * 100 end
end

return GameConfig
