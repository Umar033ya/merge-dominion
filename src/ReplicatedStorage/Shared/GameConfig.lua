local GameConfig = {
    DataStoreName = "MergeDominion_MVP_v1",
    StartingCurrency = 120,
    MaxSoldiers = 20,
    GenerationIntervals = {60, 50, 40, 30, 20, 15, 10},
    GenerationUpgradeCosts = {50, 75, 100, 125, 150, 200},
    DefaultWalkSpeed = 16,
    SprintWalkSpeed = 24,
    MaxSoldierLevel = 20,
    CityAttackCooldown = 8,
    CityIncomeSeconds = 60,
    SoldierStats = {},
    EnemyCities = {
        {Id = "EmberOutpost", Name = "Ember Outpost", Position = Vector3.new(0, 0, -105), Defenders = {{Level = 1, Count = 5}, {Level = 2, Count = 2}}, Reward = 60, IncomePerMinute = 30, Theme = "Ember"},
        {Id = "Stonewatch", Name = "Stonewatch", Position = Vector3.new(105, 0, -25), Defenders = {{Level = 2, Count = 5}, {Level = 3, Count = 2}}, Reward = 110, IncomePerMinute = 50, Theme = "Stone"},
        {Id = "Frostkeep", Name = "Frostkeep", Position = Vector3.new(-105, 0, 35), Defenders = {{Level = 3, Count = 5}, {Level = 4, Count = 3}}, Reward = 180, IncomePerMinute = 75, Theme = "Frost"},
        {Id = "Sunspire", Name = "Sunspire", Position = Vector3.new(88, 0, 72), Defenders = {{Level = 5, Count = 5}, {Level = 7, Count = 2}}, Reward = 260, IncomePerMinute = 100, Theme = "Sun"},
        {Id = "NightfallCitadel", Name = "Nightfall Citadel", Position = Vector3.new(-88, 0, -70), Defenders = {{Level = 8, Count = 4}, {Level = 10, Count = 3}, {Level = 12, Count = 1}}, Reward = 380, IncomePerMinute = 150, Theme = "Night"},
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
end

return GameConfig
