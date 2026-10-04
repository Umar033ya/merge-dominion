local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local WorldBuilder = {}

local COLORS = {
    Ground = Color3.fromRGB(45, 68, 63), GroundAccent = Color3.fromRGB(63, 91, 78), Road = Color3.fromRGB(118, 103, 83), RoadEdge = Color3.fromRGB(84, 78, 68),
    MainBlue = Color3.fromRGB(45, 126, 205), MainLight = Color3.fromRGB(114, 205, 245), MainDark = Color3.fromRGB(27, 73, 126), Wood = Color3.fromRGB(116, 78, 49), Stone = Color3.fromRGB(99, 108, 117), Leaf = Color3.fromRGB(58, 133, 91), LeafLight = Color3.fromRGB(91, 175, 108),
}
local CITY_COLORS = {
    Ember = {Wall = Color3.fromRGB(176, 70, 55), Accent = Color3.fromRGB(255, 116, 63)}, Stone = {Wall = Color3.fromRGB(116, 124, 136), Accent = Color3.fromRGB(226, 190, 105)}, Frost = {Wall = Color3.fromRGB(76, 111, 160), Accent = Color3.fromRGB(150, 224, 255)}, Sun = {Wall = Color3.fromRGB(190, 136, 55), Accent = Color3.fromRGB(255, 228, 104)}, Night = {Wall = Color3.fromRGB(78, 63, 119), Accent = Color3.fromRGB(203, 137, 255)},
}

local function part(parent, name, size, position, color, material)
    local p = Instance.new("Part")
    p.Name, p.Size, p.Position, p.Color, p.Material, p.Anchored = name, size, position, color, material or Enum.Material.SmoothPlastic, true
    p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end
local function cylinder(parent, name, radius, height, position, color, material)
    local p = part(parent, name, Vector3.new(radius * 2, height, radius * 2), position, color, material); p.Shape = Enum.PartType.Cylinder; return p
end
local function label(parent, textValue, position, color, width)
    local gui = Instance.new("BillboardGui"); gui.Name, gui.Size, gui.StudsOffset, gui.AlwaysOnTop, gui.MaxDistance = "Nameplate", UDim2.fromOffset(width or 240, 52), Vector3.new(0, 8, 0), true, 350
    local t = Instance.new("TextLabel"); t.BackgroundTransparency, t.Size, t.Text, t.TextColor3, t.TextScaled, t.Font = 1, UDim2.fromScale(1, 1), textValue, color, true, Enum.Font.GothamBold; t.TextStrokeTransparency = 0.45; t.Parent = gui
    local anchor = part(parent, "LabelAnchor", Vector3.new(1, 1, 1), position, Color3.new(1, 1, 1)); anchor.Transparency, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = 1, false, false, false; gui.Adornee, gui.Parent = anchor, parent
end
local function road(parent, name, size, position)
    part(parent, name .. "Border", Vector3.new(size.X + 2, 0.25, size.Z + 2), position + Vector3.new(0, 0.04, 0), COLORS.RoadEdge, Enum.Material.Slate)
    part(parent, name, Vector3.new(size.X, 0.3, size.Z), position + Vector3.new(0, 0.2, 0), COLORS.Road, Enum.Material.Ground)
end
local function tree(parent, position, scale)
    scale = scale or 1
    cylinder(parent, "TreeTrunk", 1.25 * scale, 5 * scale, position + Vector3.new(0, 2.5 * scale, 0), COLORS.Wood, Enum.Material.Wood)
    local crown = cylinder(parent, "TreeCrown", 3.5 * scale, 5 * scale, position + Vector3.new(0, 6 * scale, 0), COLORS.Leaf, Enum.Material.Grass); crown.Shape = Enum.PartType.Ball
    local top = cylinder(parent, "TreeTop", 2.2 * scale, 3.5 * scale, position + Vector3.new(0, 8.2 * scale, 0), COLORS.LeafLight, Enum.Material.Grass); top.Shape = Enum.PartType.Ball
end
local function rock(parent, position, size)
    local r = part(parent, "Rock", size, position + Vector3.new(0, size.Y / 2, 0), COLORS.Stone, Enum.Material.Slate); r.Shape = Enum.PartType.Ball
end
local function checkpoint(parent, id, name, position)
    local model = Instance.new("Model"); model.Name, model.Parent = id, parent; model:SetAttribute("CheckpointId", id); model:SetAttribute("Purpose", "FutureRespawnCheckpoint")
    cylinder(model, "CheckpointPad", 5, 0.8, position + Vector3.new(0, 0.4, 0), Color3.fromRGB(232, 183, 63), Enum.Material.Metal)
    cylinder(model, "CheckpointGlow", 3.5, 0.18, position + Vector3.new(0, 0.9, 0), Color3.fromRGB(255, 226, 103), Enum.Material.Neon)
    part(model, "CheckpointPost", Vector3.new(0.8, 4, 0.8), position + Vector3.new(0, 2.4, 0), COLORS.Stone, Enum.Material.Metal)
    part(model, "CheckpointFlag", Vector3.new(5, 2, 0.25), position + Vector3.new(2.3, 3.3, 0), Color3.fromRGB(255, 216, 91), Enum.Material.Fabric)
    label(model, "CHECKPOINT\n" .. name, position + Vector3.new(0, 3, 0), Color3.fromRGB(255, 241, 164), 220)
end

local function mainBase(world)
    local model = Instance.new("Model"); model.Name, model.Parent = "MainBase", world; model:SetAttribute("Permanent", true); model:SetAttribute("BaseType", "PlayerMainBase")
    part(model, "Foundation", Vector3.new(48, 2, 42), Vector3.new(0, 1, 62), COLORS.MainDark, Enum.Material.Concrete); part(model, "House", Vector3.new(34, 14, 28), Vector3.new(0, 9, 64), COLORS.MainBlue, Enum.Material.Metal); part(model, "Roof", Vector3.new(40, 3, 34), Vector3.new(0, 17, 64), COLORS.MainDark, Enum.Material.Slate); part(model, "Door", Vector3.new(7, 9, 0.6), Vector3.new(0, 6.5, 49.7), COLORS.Wood, Enum.Material.Wood); part(model, "DoorGlow", Vector3.new(4, 5, 0.2), Vector3.new(0, 6.5, 49.35), COLORS.MainLight, Enum.Material.Neon)
    for _, x in ipairs({-12, 12}) do part(model, "Window", Vector3.new(6, 5, 0.5), Vector3.new(x, 10, 49.5), COLORS.MainLight, Enum.Material.Glass) end
    for _, x in ipairs({-19, 19}) do part(model, "CornerTower", Vector3.new(5, 19, 5), Vector3.new(x, 10, 62), COLORS.MainDark, Enum.Material.Metal); part(model, "CornerCap", Vector3.new(7, 2, 7), Vector3.new(x, 20.5, 62), COLORS.MainLight, Enum.Material.Neon) end
    part(model, "FlagPole", Vector3.new(0.6, 22, 0.6), Vector3.new(0, 28, 64), COLORS.Stone, Enum.Material.Metal); part(model, "Flag", Vector3.new(8, 4, 0.3), Vector3.new(4, 34, 64), COLORS.MainLight, Enum.Material.Fabric); label(model, "MAIN BASE • SAFE • PERMANENT", Vector3.new(0, 18, 64), Color3.fromRGB(187, 235, 255), 300)
    local yard = Instance.new("Model"); yard.Name, yard.Parent = "SoldierYard", world; yard:SetAttribute("Purpose", "SoldierCreationAndMergeArea"); part(yard, "YardFloor", Vector3.new(38, 0.4, 24), Vector3.new(0, 0.2, 34), COLORS.GroundAccent, Enum.Material.Ground); part(yard, "YardBorderFront", Vector3.new(38, 1.2, 1), Vector3.new(0, 0.8, 22), COLORS.MainLight, Enum.Material.Neon); part(yard, "YardBorderBack", Vector3.new(38, 1.2, 1), Vector3.new(0, 0.8, 46), COLORS.MainLight, Enum.Material.Neon); label(yard, "SOLDIER YARD • CREATE & MERGE", Vector3.new(0, 4, 34), Color3.fromRGB(203, 255, 214), 280)
end

local function cityZone(world, index, city)
    local model = Instance.new("Model"); model.Name, model.Parent = city.Id, world; model:SetAttribute("CityId", city.Id); model:SetAttribute("BaseType", "EnemyCity"); model:SetAttribute("Difficulty", index); model:SetAttribute("IncomePerMinute", city.IncomePerMinute); model:SetAttribute("Conquered", false)
    local theme = CITY_COLORS[city.Theme] or CITY_COLORS.Stone; local position = city.Position; local footprint = 30 + index * 3
    part(model, "CityFoundation", Vector3.new(footprint, 2, footprint), position + Vector3.new(0, 1, 0), COLORS.Stone, Enum.Material.Concrete)
    for building = 1, 5 do
        local x = ((building - 1) % 3 - 1) * (footprint / 3); local z = (math.floor((building - 1) / 3) - 0.5) * (footprint / 2); local height = 7 + ((building + index) % 3) * 3
        part(model, "CityBuilding", Vector3.new(7, height, 7), position + Vector3.new(x, 2 + height / 2, z), theme.Wall, Enum.Material.Brick)
        part(model, "BuildingRoof", Vector3.new(8, 1.2, 8), position + Vector3.new(x, 2 + height + 0.6, z), theme.Accent, Enum.Material.Slate)
    end
    local towerHeight = 12 + index * 2
    for _, x in ipairs({-footprint / 2 + 4, footprint / 2 - 4}) do
        part(model, "CityTower", Vector3.new(5, towerHeight, 5), position + Vector3.new(x, 1 + towerHeight / 2, 0), theme.Wall, Enum.Material.Brick)
        part(model, "CityBeacon", Vector3.new(2.5, 1, 2.5), position + Vector3.new(x, 2 + towerHeight, 0), theme.Accent, Enum.Material.Neon)
    end
    local gate = part(model, "CityGate", Vector3.new(10, 7 + index, 1), position + Vector3.new(0, 4.5 + index / 2, footprint / 2), theme.Accent, Enum.Material.Wood)
    part(model, "CityFlag", Vector3.new(7, 3.5, 0.25), position + Vector3.new(4, 13 + index, 0), theme.Accent, Enum.Material.Fabric)
    label(model, string.format("CITY %d • %s\n%d defenders • +%d/min", index, city.Name, (function() local n = 0; for _, g in ipairs(city.Defenders) do n += g.Count end; return n end)(), city.IncomePerMinute), position + Vector3.new(0, 15 + index, 0), Color3.fromRGB(255, 231, 205), 300)
    local prompt = Instance.new("ProximityPrompt"); prompt.Name, prompt.ActionText, prompt.ObjectText, prompt.KeyboardKeyCode, prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.Parent = "AttackPrompt", "Attack City", city.Name, Enum.KeyCode.E, 0, 12, false, gate
end

function WorldBuilder.build()
    local existing = workspace:FindFirstChild("MergeDominionWorld")
    if existing and existing:GetAttribute("WorldReady") == true and existing:FindFirstChild("ArenaGround") and existing:FindFirstChild("MainBase") and existing:FindFirstChild("SoldierYard") and existing:FindFirstChild("PlayerSpawn") then
        warn("[MergeDominion] WorldBuilder found an existing ready MergeDominionWorld; reusing it.")
        return existing
    end
    if existing then existing:Destroy() end
    local world = Instance.new("Folder"); world.Name, world.Parent = "MergeDominionWorld", workspace
    world:SetAttribute("WorldReady", false)
    world:SetAttribute("BuildVersion", "city-level20-v1")
    part(world, "ArenaGround", Vector3.new(280, 2, 230), Vector3.new(0, -1, 0), COLORS.Ground, Enum.Material.Grass); part(world, "ArenaInset", Vector3.new(262, 0.05, 212), Vector3.new(0, 0.025, 0), COLORS.GroundAccent, Enum.Material.Ground)
    road(world, "MainRoad", Vector3.new(12, 1, 150), Vector3.new(0, -0.2, -18)); road(world, "EastRoad", Vector3.new(100, 1, 10), Vector3.new(52, -0.18, -25)); road(world, "WestRoad", Vector3.new(100, 1, 10), Vector3.new(-52, -0.16, 35)); road(world, "SouthRoad", Vector3.new(12, 1, 100), Vector3.new(52, -0.2, 35)); road(world, "NorthRoad", Vector3.new(12, 1, 100), Vector3.new(-52, -0.2, -35))
    mainBase(world)
    for index, city in ipairs(GameConfig.EnemyCities) do cityZone(world, index, city) end
    local checkpointFolder = Instance.new("Folder"); checkpointFolder.Name, checkpointFolder.Parent = "Checkpoints", world
    checkpoint(checkpointFolder, "MainBaseCheckpoint", "Main Base", Vector3.new(0, 0, 18)); checkpoint(checkpointFolder, "EmberCheckpoint", "Ember Outpost", Vector3.new(0, 0, -88)); checkpoint(checkpointFolder, "StonewatchCheckpoint", "Stonewatch", Vector3.new(83, 0, -25)); checkpoint(checkpointFolder, "FrostkeepCheckpoint", "Frostkeep", Vector3.new(-83, 0, 35))
    for _, item in ipairs({{Vector3.new(-58, 0, 78), 1.2}, {Vector3.new(58, 0, 78), 1}, {Vector3.new(-72, 0, -70), 1.1}, {Vector3.new(72, 0, -70), 1.3}}) do tree(world, item[1], item[2]) end
    for _, position in ipairs({Vector3.new(-38, 0, -22), Vector3.new(42, 0, 70), Vector3.new(-48, 0, 56), Vector3.new(46, 0, -64)}) do rock(world, position, Vector3.new(4, 3, 3)) end
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "PlayerSpawn"
    spawn.Size = Vector3.new(8, 1, 8)
    spawn.Position = Vector3.new(0, 1, 38)
    spawn.Anchored = true
    spawn.Neutral = true
    spawn.AllowTeamChangeOnTouch = false
    spawn.Duration = 0
    spawn.Transparency = 0.2
    spawn.CanCollide = true
    spawn.Parent = world
    world:SetAttribute("WorldReady", true)
    return world
end

return WorldBuilder
