local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local WorldBuilder = {}

local function part(parent, name, size, position, color, material)
    local p = Instance.new("Part")
    p.Name, p.Size, p.Position, p.Color, p.Material = name, size, position, color, material or Enum.Material.SmoothPlastic
    p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end
local function label(parent, text, position, color)
    local gui = Instance.new("BillboardGui")
    gui.Name, gui.Size, gui.StudsOffset, gui.AlwaysOnTop = "Nameplate", UDim2.fromOffset(220, 48), Vector3.new(0, 8, 0), true
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency, t.Size, t.Text, t.TextColor3, t.TextScaled, t.Font = 1, UDim2.fromScale(1, 1), text, color, true, Enum.Font.GothamBold
    t.Parent, gui.Parent = gui, parent
    gui.Adornee = part(parent, "LabelAnchor", Vector3.new(1, 1, 1), position, Color3.new(1,1,1))
end

function WorldBuilder.build()
    local old = workspace:FindFirstChild("MergeDominionWorld")
    if old then old:Destroy() end
    local world = Instance.new("Folder"); world.Name = "MergeDominionWorld"; world.Parent = workspace
    part(world, "Arena", Vector3.new(280, 1, 230), Vector3.new(0, -1, 0), Color3.fromRGB(27, 44, 59), Enum.Material.Slate)
    part(world, "MainBase", Vector3.new(42, 12, 42), Vector3.new(0, 6, 62), Color3.fromRGB(55, 136, 214), Enum.Material.Metal)
    label(world, "MAIN BASE • SAFE", Vector3.new(0, 12, 62), Color3.fromRGB(170, 225, 255))
    for index, enemy in ipairs(GameConfig.EnemyBases) do
        local model = Instance.new("Model"); model.Name = enemy.Id; model:SetAttribute("BaseId", enemy.Id); model.Parent = world
        part(model, "Base", Vector3.new(30, 9, 30), enemy.Position + Vector3.new(0, 4.5, 0), Color3.fromRGB(165, 65 + index * 15, 65), Enum.Material.Brick)
        part(model, "Beacon", Vector3.new(4, 16, 4), enemy.Position + Vector3.new(0, 14, 0), Color3.fromRGB(255, 90, 70), Enum.Material.Neon)
        label(model, string.format("%d  •  %s", index, enemy.Name), enemy.Position, Color3.fromRGB(255, 210, 190))
    end
    local spawn = Instance.new("SpawnLocation"); spawn.Name, spawn.Size, spawn.Position, spawn.Anchored = "PlayerSpawn", Vector3.new(8, 1, 8), Vector3.new(0, 13, 62), true
    spawn.Neutral, spawn.Transparency, spawn.Parent = true, 1, world
    return world
end
return WorldBuilder
