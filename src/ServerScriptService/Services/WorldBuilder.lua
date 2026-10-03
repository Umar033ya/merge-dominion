local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local WorldBuilder = {}

local COLORS = {
    Ground = Color3.fromRGB(45, 68, 63),
    GroundAccent = Color3.fromRGB(63, 91, 78),
    Road = Color3.fromRGB(118, 103, 83),
    RoadEdge = Color3.fromRGB(84, 78, 68),
    MainBlue = Color3.fromRGB(45, 126, 205),
    MainLight = Color3.fromRGB(114, 205, 245),
    MainDark = Color3.fromRGB(27, 73, 126),
    Wood = Color3.fromRGB(116, 78, 49),
    Stone = Color3.fromRGB(99, 108, 117),
    Leaf = Color3.fromRGB(58, 133, 91),
    LeafLight = Color3.fromRGB(91, 175, 108),
}

local function part(parent, name, size, position, color, material)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Position = position
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.Anchored = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function cylinder(parent, name, radius, height, position, color, material)
    local p = part(parent, name, Vector3.new(radius * 2, height, radius * 2), position, color, material)
    p.Shape = Enum.PartType.Cylinder
    return p
end

local function label(parent, text, position, color, width)
    local gui = Instance.new("BillboardGui")
    gui.Name = "Nameplate"
    gui.Size = UDim2.fromOffset(width or 240, 52)
    gui.StudsOffset = Vector3.new(0, 8, 0)
    gui.AlwaysOnTop = true
    gui.MaxDistance = 350

    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Size = UDim2.fromScale(1, 1)
    t.Text = text
    t.TextColor3 = color
    t.TextScaled = true
    t.Font = Enum.Font.GothamBold
    t.TextStrokeTransparency = 0.45
    t.Parent = gui
    gui.Parent = parent

    local anchor = part(parent, "LabelAnchor", Vector3.new(1, 1, 1), position, Color3.new(1, 1, 1))
    anchor.Transparency = 1
    anchor.CanCollide = false
    anchor.CanTouch = false
    anchor.CanQuery = false
    gui.Adornee = anchor
end

local function road(parent, name, size, position)
    part(parent, name .. "Border", Vector3.new(size.X + 2, 0.25, size.Z + 2), position + Vector3.new(0, 0.04, 0), COLORS.RoadEdge, Enum.Material.Slate)
    part(parent, name, Vector3.new(size.X, 0.3, size.Z), position + Vector3.new(0, 0.2, 0), COLORS.Road, Enum.Material.Ground)
end

local function tree(parent, position, scale)
    scale = scale or 1
    cylinder(parent, "TreeTrunk", 1.25 * scale, 5 * scale, position + Vector3.new(0, 2.5 * scale, 0), COLORS.Wood, Enum.Material.Wood)
    local crown = cylinder(parent, "TreeCrown", 3.5 * scale, 5 * scale, position + Vector3.new(0, 6 * scale, 0), COLORS.Leaf, Enum.Material.Grass)
    crown.Shape = Enum.PartType.Ball
    local top = cylinder(parent, "TreeTop", 2.2 * scale, 3.5 * scale, position + Vector3.new(0, 8.2 * scale, 0), COLORS.LeafLight, Enum.Material.Grass)
    top.Shape = Enum.PartType.Ball
end

local function rock(parent, position, size)
    local r = part(parent, "Rock", size, position + Vector3.new(0, size.Y / 2, 0), COLORS.Stone, Enum.Material.Slate)
    r.Shape = Enum.PartType.Ball
end

local function checkpoint(parent, id, name, position)
    local model = Instance.new("Model")
    model.Name = id
    model:SetAttribute("CheckpointId", id)
    model:SetAttribute("Purpose", "FutureRespawnCheckpoint")
    model.Parent = parent

    cylinder(model, "CheckpointPad", 5, 0.8, position + Vector3.new(0, 0.4, 0), Color3.fromRGB(232, 183, 63), Enum.Material.Metal)
    cylinder(model, "CheckpointGlow", 3.5, 0.18, position + Vector3.new(0, 0.9, 0), Color3.fromRGB(255, 226, 103), Enum.Material.Neon)
    part(model, "CheckpointPost", Vector3.new(0.8, 4, 0.8), position + Vector3.new(0, 2.4, 0), COLORS.Stone, Enum.Material.Metal)
    part(model, "CheckpointFlag", Vector3.new(5, 2, 0.25), position + Vector3.new(2.3, 3.3, 0), Color3.fromRGB(255, 216, 91), Enum.Material.Fabric)
    label(model, "CHECKPOINT\n" .. name, position + Vector3.new(0, 3, 0), Color3.fromRGB(255, 241, 164), 220)
end

local function mainBase(world)
    local model = Instance.new("Model")
    model.Name = "MainBase"
    model:SetAttribute("Permanent", true)
    model:SetAttribute("BaseType", "PlayerMainBase")
    model.Parent = world

    part(model, "Foundation", Vector3.new(48, 2, 42), Vector3.new(0, 1, 62), COLORS.MainDark, Enum.Material.Concrete)
    part(model, "House", Vector3.new(34, 14, 28), Vector3.new(0, 9, 64), COLORS.MainBlue, Enum.Material.Metal)
    part(model, "Roof", Vector3.new(40, 3, 34), Vector3.new(0, 17, 64), COLORS.MainDark, Enum.Material.Slate)
    part(model, "Door", Vector3.new(7, 9, 0.6), Vector3.new(0, 6.5, 49.7), COLORS.Wood, Enum.Material.Wood)
    part(model, "DoorGlow", Vector3.new(4, 5, 0.2), Vector3.new(0, 6.5, 49.35), COLORS.MainLight, Enum.Material.Neon)

    for _, x in ipairs({-12, 12}) do
        part(model, "Window", Vector3.new(6, 5, 0.5), Vector3.new(x, 10, 49.5), COLORS.MainLight, Enum.Material.Glass)
    end
    for _, x in ipairs({-19, 19}) do
        part(model, "CornerTower", Vector3.new(5, 19, 5), Vector3.new(x, 10, 62), COLORS.MainDark, Enum.Material.Metal)
        part(model, "CornerCap", Vector3.new(7, 2, 7), Vector3.new(x, 20.5, 62), COLORS.MainLight, Enum.Material.Neon)
    end

    part(model, "FlagPole", Vector3.new(0.6, 22, 0.6), Vector3.new(0, 28, 64), COLORS.Stone, Enum.Material.Metal)
    part(model, "Flag", Vector3.new(8, 4, 0.3), Vector3.new(4, 34, 64), COLORS.MainLight, Enum.Material.Fabric)
    label(model, "MAIN BASE • SAFE • PERMANENT", Vector3.new(0, 18, 64), Color3.fromRGB(187, 235, 255), 300)

    local yard = Instance.new("Model")
    yard.Name = "SoldierYard"
    yard:SetAttribute("Purpose", "SoldierCreationAndMergeArea")
    yard.Parent = world
    part(yard, "YardFloor", Vector3.new(38, 0.4, 24), Vector3.new(0, 0.2, 34), COLORS.GroundAccent, Enum.Material.Ground)
    part(yard, "YardBorderFront", Vector3.new(38, 1.2, 1), Vector3.new(0, 0.8, 22), COLORS.MainLight, Enum.Material.Neon)
    part(yard, "YardBorderBack", Vector3.new(38, 1.2, 1), Vector3.new(0, 0.8, 46), COLORS.MainLight, Enum.Material.Neon)
    for _, x in ipairs({-14, 14}) do
        part(yard, "YardPost", Vector3.new(1, 5, 1), Vector3.new(x, 3.5, 34), COLORS.Wood, Enum.Material.Wood)
    end
    label(yard, "SOLDIER YARD • CREATE & MERGE", Vector3.new(0, 4, 34), Color3.fromRGB(203, 255, 214), 280)
end

local function enemyBase(world, index, enemy)
    local model = Instance.new("Model")
    model.Name = enemy.Id
    model:SetAttribute("BaseId", enemy.Id)
    model:SetAttribute("BaseType", "EnemyBase")
    model:SetAttribute("DefenderTier", index)
    model.Parent = world

    local position = enemy.Position
    local footprint = 28 + index * 5
    local wallColor = Color3.fromRGB(112 + index * 18, 58 + index * 18, 58 + index * 8)
    local accent = Color3.fromRGB(255, 93 + index * 35, 67)

    part(model, "Foundation", Vector3.new(footprint, 2, footprint), position + Vector3.new(0, 1, 0), COLORS.Stone, Enum.Material.Concrete)
    part(model, "Keep", Vector3.new(footprint - 8, 8 + index * 2, footprint - 8), position + Vector3.new(0, 6 + index, 0), wallColor, Enum.Material.Brick)
    part(model, "KeepRoof", Vector3.new(footprint - 4, 2, footprint - 4), position + Vector3.new(0, 11 + index * 2, 0), Color3.fromRGB(62, 48, 49), Enum.Material.Slate)

    local towerHeight = 10 + index * 3
    local towerOffset = footprint / 2 - 3
    for _, x in ipairs({-towerOffset, towerOffset}) do
        for _, z in ipairs({-towerOffset, towerOffset}) do
            part(model, "DefenseTower", Vector3.new(6, towerHeight, 6), position + Vector3.new(x, towerHeight / 2 + 1, z), wallColor, Enum.Material.Brick)
            part(model, "TowerBeacon", Vector3.new(3, 1.5, 3), position + Vector3.new(x, towerHeight + 2, z), accent, Enum.Material.Neon)
        end
    end

    part(model, "Gate", Vector3.new(9, 7 + index, 1), position + Vector3.new(0, 4.5 + index / 2, footprint / 2), COLORS.Wood, Enum.Material.Wood)
    part(model, "Beacon", Vector3.new(3, 14 + index * 4, 3), position + Vector3.new(0, 8 + index * 2, 0), accent, Enum.Material.Neon)
    label(model, string.format("%d  •  %s\n%s", index, enemy.Name, index == 1 and "WEAK DEFENSES" or index == 2 and "HARDENED DEFENSES" or "STRONG DEFENSES"), position + Vector3.new(0, 12 + index * 2, 0), Color3.fromRGB(255, 220, 205), 270)
end

function WorldBuilder.build()
    local old = workspace:FindFirstChild("MergeDominionWorld")
    if old then old:Destroy() end
    local world = Instance.new("Folder")
    world.Name = "MergeDominionWorld"
    world.Parent = workspace

    part(world, "ArenaGround", Vector3.new(280, 2, 230), Vector3.new(0, -1, 0), COLORS.Ground, Enum.Material.Grass)
    part(world, "ArenaInset", Vector3.new(262, 0.05, 212), Vector3.new(0, 0.025, 0), COLORS.GroundAccent, Enum.Material.Ground)

    road(world, "MainRoad", Vector3.new(12, 1, 150), Vector3.new(0, -0.2, -18))
    road(world, "EastRoad", Vector3.new(100, 1, 10), Vector3.new(52, -0.18, -25))
    road(world, "WestRoad", Vector3.new(100, 1, 10), Vector3.new(-52, -0.16, 35))
    road(world, "YardApproach", Vector3.new(38, 1, 8), Vector3.new(0, -0.12, 46))

    mainBase(world)
    for index, enemy in ipairs(GameConfig.EnemyBases) do
        enemyBase(world, index, enemy)
    end

    local checkpointFolder = Instance.new("Folder")
    checkpointFolder.Name = "Checkpoints"
    checkpointFolder.Parent = world
    checkpoint(checkpointFolder, "MainBaseCheckpoint", "Main Base", Vector3.new(0, 0, 18))
    checkpoint(checkpointFolder, "EmberCheckpoint", "Ember Outpost", Vector3.new(0, 0, -88))
    checkpoint(checkpointFolder, "StonewatchCheckpoint", "Stonewatch", Vector3.new(83, 0, -25))
    checkpoint(checkpointFolder, "FrostkeepCheckpoint", "Frostkeep", Vector3.new(-83, 0, 35))

    for _, item in ipairs({
        {Vector3.new(-58, 0, 78), 1.2}, {Vector3.new(58, 0, 78), 1},
        {Vector3.new(-72, 0, -70), 1.1}, {Vector3.new(72, 0, -70), 1.3},
        {Vector3.new(-72, 0, 88), 0.8}, {Vector3.new(72, 0, 90), 0.8},
    }) do
        tree(world, item[1], item[2])
    end
    for _, position in ipairs({Vector3.new(-38, 0, -22), Vector3.new(42, 0, 70), Vector3.new(-48, 0, 56), Vector3.new(46, 0, -64)}) do
        rock(world, position, Vector3.new(4, 3, 3))
    end

    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "PlayerSpawn"
    spawn.Size = Vector3.new(8, 1, 8)
    spawn.Position = Vector3.new(0, 13, 61)
    spawn.Anchored = true
    spawn.Neutral = true
    spawn.Transparency = 1
    spawn.CanCollide = false
    spawn.Parent = world
    return world
end

return WorldBuilder
