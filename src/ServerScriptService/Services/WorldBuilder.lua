local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local WorldBuilder = {}

local COLORS = {
    Ground = Color3.fromRGB(45, 68, 63), GroundAccent = Color3.fromRGB(63, 91, 78), Road = Color3.fromRGB(118, 103, 83), RoadEdge = Color3.fromRGB(84, 78, 68),
    MainBlue = Color3.fromRGB(45, 126, 205), MainLight = Color3.fromRGB(114, 205, 245), MainDark = Color3.fromRGB(27, 73, 126), Wood = Color3.fromRGB(116, 78, 49), Stone = Color3.fromRGB(99, 108, 117), Leaf = Color3.fromRGB(58, 133, 91), LeafLight = Color3.fromRGB(91, 175, 108),
}
local CITY_COLORS = {
    Ember = {Wall = Color3.fromRGB(176, 70, 55), Accent = Color3.fromRGB(255, 116, 63)}, Stone = {Wall = Color3.fromRGB(116, 124, 136), Accent = Color3.fromRGB(226, 190, 105)}, Frost = {Wall = Color3.fromRGB(76, 111, 160), Accent = Color3.fromRGB(150, 224, 255)}, Sun = {Wall = Color3.fromRGB(190, 136, 55), Accent = Color3.fromRGB(255, 228, 104)}, Night = {Wall = Color3.fromRGB(78, 63, 119), Accent = Color3.fromRGB(203, 137, 255)}, Iron = {Wall = Color3.fromRGB(75, 86, 95), Accent = Color3.fromRGB(208, 220, 230)}, Moon = {Wall = Color3.fromRGB(80, 84, 135), Accent = Color3.fromRGB(170, 186, 255)}, Cinder = {Wall = Color3.fromRGB(135, 61, 48), Accent = Color3.fromRGB(255, 148, 73)}, Verdant = {Wall = Color3.fromRGB(55, 112, 76), Accent = Color3.fromRGB(132, 226, 125)}, Dragon = {Wall = Color3.fromRGB(100, 48, 120), Accent = Color3.fromRGB(255, 108, 140)},
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
    local gui = Instance.new("BillboardGui"); gui.Name, gui.Size, gui.StudsOffset, gui.AlwaysOnTop, gui.MaxDistance = "Nameplate", UDim2.fromOffset(width or 240, 52), Vector3.new(0, 8, 0), true, 500
    local t = Instance.new("TextLabel"); t.BackgroundTransparency, t.Size, t.Text, t.TextColor3, t.TextScaled, t.Font = 1, UDim2.fromScale(1, 1), textValue, color, true, Enum.Font.GothamBold; t.TextStrokeTransparency = 0.45; t.Parent = gui
    local anchor = part(parent, "LabelAnchor", Vector3.new(1, 1, 1), position, Color3.new(1, 1, 1)); anchor.Transparency, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = 1, false, false, false; gui.Adornee, gui.Parent = anchor, parent
end
local function roadBetween(parent, name, fromPosition, toPosition)
    local midpoint = (fromPosition + toPosition) / 2 + Vector3.new(0, 0.18, 0)
    local delta = toPosition - fromPosition
    local length = math.max(12, Vector3.new(delta.X, 0, delta.Z).Magnitude)
    local border = part(parent, name .. "Border", Vector3.new(14, 0.25, length + 2), midpoint, COLORS.RoadEdge, Enum.Material.Slate)
    local road = part(parent, name, Vector3.new(11, 0.3, length), midpoint + Vector3.new(0, 0.16, 0), COLORS.Road, Enum.Material.Ground)
    local angle = math.atan2(delta.X, delta.Z)
    border.CFrame = CFrame.new(border.Position) * CFrame.Angles(0, angle, 0); road.CFrame = CFrame.new(road.Position) * CFrame.Angles(0, angle, 0)
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
    local model = Instance.new("Model"); model.Name, model.Parent = id, parent; model:SetAttribute("CheckpointId", id); model:SetAttribute("Purpose", "SafeTravelCheckpoint")
    cylinder(model, "CheckpointPad", 5, 0.8, position + Vector3.new(0, 0.4, 0), Color3.fromRGB(232, 183, 63), Enum.Material.Metal)
    cylinder(model, "CheckpointGlow", 3.5, 0.18, position + Vector3.new(0, 0.9, 0), Color3.fromRGB(255, 226, 103), Enum.Material.Neon)
    part(model, "CheckpointPost", Vector3.new(0.8, 4, 0.8), position + Vector3.new(0, 2.4, 0), COLORS.Stone, Enum.Material.Metal)
    part(model, "CheckpointFlag", Vector3.new(5, 2, 0.25), position + Vector3.new(2.3, 3.3, 0), Color3.fromRGB(255, 216, 91), Enum.Material.Fabric)
    label(model, "CHECKPOINT\n" .. name, position + Vector3.new(0, 3, 0), Color3.fromRGB(255, 241, 164), 220)
end
local function mainBase(world)
    local p = GameConfig.MainBasePosition
    local model = Instance.new("Model"); model.Name, model.Parent = "MainBase", world; model:SetAttribute("Permanent", true); model:SetAttribute("BaseType", "PlayerMainBase")
    part(model, "Foundation", Vector3.new(48, 2, 42), p + Vector3.new(0, 1, 0), COLORS.MainDark, Enum.Material.Concrete); part(model, "House", Vector3.new(34, 14, 28), p + Vector3.new(0, 9, 2), COLORS.MainBlue, Enum.Material.Metal); part(model, "Roof", Vector3.new(40, 3, 34), p + Vector3.new(0, 17, 2), COLORS.MainDark, Enum.Material.Slate); part(model, "Door", Vector3.new(7, 9, 0.6), p + Vector3.new(0, 6.5, -12.3), COLORS.Wood, Enum.Material.Wood); part(model, "DoorGlow", Vector3.new(4, 5, 0.2), p + Vector3.new(0, 6.5, -12.65), COLORS.MainLight, Enum.Material.Neon)
    for _, x in ipairs({-12, 12}) do part(model, "Window", Vector3.new(6, 5, 0.5), p + Vector3.new(x, 10, -12.5), COLORS.MainLight, Enum.Material.Glass) end
    for _, x in ipairs({-19, 19}) do part(model, "CornerTower", Vector3.new(5, 19, 5), p + Vector3.new(x, 10, 0), COLORS.MainDark, Enum.Material.Metal); part(model, "CornerCap", Vector3.new(7, 2, 7), p + Vector3.new(x, 20.5, 0), COLORS.MainLight, Enum.Material.Neon) end
    part(model, "FlagPole", Vector3.new(0.6, 22, 0.6), p + Vector3.new(0, 28, 2), COLORS.Stone, Enum.Material.Metal); part(model, "Flag", Vector3.new(8, 4, 0.3), p + Vector3.new(4, 34, 2), COLORS.MainLight, Enum.Material.Fabric); label(model, "MAIN BASE • SAFE • PERMANENT", p + Vector3.new(0, 18, 2), Color3.fromRGB(187, 235, 255), 300)
    local yard = Instance.new("Model"); yard.Name, yard.Parent = "SoldierYard", world; yard:SetAttribute("Purpose", "SoldierCreationAndMergeArea"); local y = GameConfig.SoldierYardPosition
    part(yard, "YardFloor", Vector3.new(38, 0.4, 24), y + Vector3.new(0, 0.2, 0), COLORS.GroundAccent, Enum.Material.Ground); part(yard, "YardBorderFront", Vector3.new(38, 1.2, 1), y + Vector3.new(0, 0.8, -12), COLORS.MainLight, Enum.Material.Neon); part(yard, "YardBorderBack", Vector3.new(38, 1.2, 1), y + Vector3.new(0, 0.8, 12), COLORS.MainLight, Enum.Material.Neon); label(yard, "SOLDIER YARD • CREATE & MERGE", y + Vector3.new(0, 4, 0), Color3.fromRGB(203, 255, 214), 280)
end
local function defenderModel(parent, city, level, ordinal, position, theme)
    local stats = GameConfig.SoldierStats[level]; local model = Instance.new("Model"); model.Name = "Defender_L" .. level .. "_" .. ordinal; model:SetAttribute("EnemyLevel", level); model.Parent = parent
    local body = part(model, "Body", Vector3.new(1.4, 2.2, 1.1), position + Vector3.new(0, 1.2, 0), theme.Wall, Enum.Material.Metal)
    local head = part(model, "Head", Vector3.new(1.1, 1.1, 1.1), position + Vector3.new(0, 2.9, 0), theme.Accent, Enum.Material.SmoothPlastic); head.Shape = Enum.PartType.Ball
    local helmet = part(model, "Helmet", Vector3.new(1.3, 0.4, 1.3), position + Vector3.new(0, 3.45, 0), theme.Accent, Enum.Material.Metal); helmet.Shape = Enum.PartType.Ball
    part(model, "Weapon", Vector3.new(0.18, 2.1, 0.18), position + Vector3.new(0.85, 1.2, 0), stats.AccentColor, Enum.Material.Metal)
    label(model, "L" .. level, position + Vector3.new(0, 3.6, 0), stats.AccentColor, 70)
    return model
end
local function cityZone(world, index, city)
    local model = Instance.new("Model"); model.Name, model.Parent = city.Id, world; model:SetAttribute("CityId", city.Id); model:SetAttribute("BaseType", "EnemyCity"); model:SetAttribute("Difficulty", index); model:SetAttribute("IncomePerMinute", city.IncomePerMinute); model:SetAttribute("Conquered", false)
    local theme = CITY_COLORS[city.Theme] or CITY_COLORS.Stone; local position = city.Position; local footprint = 32 + math.min(index, 8) * 2
    part(model, "CityFoundation", Vector3.new(footprint, 2, footprint), position + Vector3.new(0, 1, 0), COLORS.Stone, Enum.Material.Concrete)
    local territory = part(model, "TerritoryRing", Vector3.new(footprint - 4, 0.12, footprint - 4), position + Vector3.new(0, 2.08, 0), Color3.fromRGB(114, 205, 245), Enum.Material.Neon); territory.Shape, territory.Transparency, territory.CanCollide, territory.CanTouch, territory.CanQuery = Enum.PartType.Cylinder, 1, false, false, false
    for building = 1, 5 do local x = ((building - 1) % 3 - 1) * (footprint / 3); local z = (math.floor((building - 1) / 3) - 0.5) * (footprint / 2); local height = 7 + ((building + index) % 3) * 3; part(model, "CityBuilding", Vector3.new(7, height, 7), position + Vector3.new(x, 2 + height / 2, z), theme.Wall, Enum.Material.Brick); part(model, "BuildingRoof", Vector3.new(8, 1.2, 8), position + Vector3.new(x, 2 + height + 0.6, z), theme.Accent, Enum.Material.Slate) end
    local towerHeight = 12 + index * 1.5
    for _, x in ipairs({-footprint / 2 + 4, footprint / 2 - 4}) do part(model, "CityTower", Vector3.new(5, towerHeight, 5), position + Vector3.new(x, 1 + towerHeight / 2, 0), theme.Wall, Enum.Material.Brick); part(model, "CityBeacon", Vector3.new(2.5, 1, 2.5), position + Vector3.new(x, 2 + towerHeight, 0), theme.Accent, Enum.Material.Neon) end
    local gate = part(model, "CityGate", Vector3.new(10, 7 + index / 2, 1), position + Vector3.new(0, 4.5 + index / 4, footprint / 2), theme.Accent, Enum.Material.Wood)
    part(model, "CityWallLeft", Vector3.new(2, 5, footprint), position + Vector3.new(-footprint / 2, 3.5, 0), theme.Wall, Enum.Material.Brick); part(model, "CityWallRight", Vector3.new(2, 5, footprint), position + Vector3.new(footprint / 2, 3.5, 0), theme.Wall, Enum.Material.Brick)
    part(model, "CityFlag", Vector3.new(7, 3.5, 0.25), position + Vector3.new(4, 13 + index, 0), theme.Accent, Enum.Material.Fabric)
    local defenderFolder = Instance.new("Folder"); defenderFolder.Name, defenderFolder.Parent = "Defenders", model
    local ordinal = 0; for _, group in ipairs(city.Defenders) do for _ = 1, group.Count do ordinal += 1; local offset = Vector3.new(((ordinal - 1) % 4 - 1.5) * 4, 0, math.floor((ordinal - 1) / 4) * 4 - 5); defenderModel(defenderFolder, city, group.Level, ordinal, position + offset, theme) end end
    local total = 0; for _, g in ipairs(city.Defenders) do total += g.Count end
    label(model, string.format("CITY %d • %s\n%d visible defenders • +%d/min", index, city.Name, total, city.IncomePerMinute), position + Vector3.new(0, 15 + index, 0), Color3.fromRGB(255, 231, 205), 320)
    local prompt = Instance.new("ProximityPrompt"); prompt.Name, prompt.ActionText, prompt.ObjectText, prompt.KeyboardKeyCode, prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.Parent = "AttackPrompt", "Attack City", city.Name, Enum.KeyCode.E, 0, 14, false, gate
end

function WorldBuilder.build()
    local existing = workspace:FindFirstChild("MergeDominionWorld"); if existing and existing:GetAttribute("WorldReady") == true and existing:GetAttribute("BuildVersion") == "ten-city-army-network-v1" then return existing end; if existing then existing:Destroy() end
    local world = Instance.new("Folder"); world.Name, world.Parent = "MergeDominionWorld", workspace; world:SetAttribute("WorldReady", false); world:SetAttribute("BuildVersion", "ten-city-army-network-v1")
    part(world, "ArenaGround", Vector3.new(560, 2, 520), Vector3.new(0, -1, 110), COLORS.Ground, Enum.Material.Grass); part(world, "ArenaInset", Vector3.new(540, 0.05, 500), Vector3.new(0, 0.025, 110), COLORS.GroundAccent, Enum.Material.Ground)
    mainBase(world)
    local roads = Instance.new("Folder"); roads.Name, roads.Parent = "RoadNetwork", world
    for index, city in ipairs(GameConfig.EnemyCities) do roadBetween(roads, "RoadTo_" .. city.Id, GameConfig.MainBasePosition, city.Position); cityZone(world, index, city) end
    local checkpoints = Instance.new("Folder"); checkpoints.Name, checkpoints.Parent = "Checkpoints", world; checkpoint(checkpoints, "MainBaseCheckpoint", "Main Base", GameConfig.MainBasePosition + Vector3.new(0, 0, -25))
    for index, city in ipairs(GameConfig.EnemyCities) do local towardBase = GameConfig.MainBasePosition:Lerp(city.Position, 0.78); checkpoint(checkpoints, "Checkpoint_" .. city.Id, city.Name, towardBase) end
    for x = -240, 240, 48 do for z = -90, 330, 70 do if math.abs(x) > 30 and math.abs(z - 80) > 35 then tree(world, Vector3.new(x, 0, z), 0.7 + ((math.abs(x) + z) % 3) * 0.12) end end end
    for x = -250, 250, 50 do rock(world, Vector3.new(x, 0, -5 + (x % 4) * 12), Vector3.new(5, 4, 4)) end
    local spawn = Instance.new("SpawnLocation"); spawn.Name, spawn.Size, spawn.Position, spawn.Anchored, spawn.Neutral, spawn.AllowTeamChangeOnTouch, spawn.Duration, spawn.Transparency, spawn.CanCollide, spawn.Parent = "PlayerSpawn", Vector3.new(8, 1, 8), GameConfig.SoldierYardPosition + Vector3.new(0, 1, 0), true, true, false, 0, 0.2, true, world
    world:SetAttribute("WorldReady", true); return world
end

return WorldBuilder
