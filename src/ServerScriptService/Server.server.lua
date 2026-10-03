local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local DataService = require(script.Parent.Services.DataService)
local CombatService = require(script.Parent.Services.CombatService)
local WorldBuilder = require(script.Parent.Services.WorldBuilder)

local remotes = Instance.new("Folder"); remotes.Name = "Remotes"; remotes.Parent = ReplicatedStorage
local actionEvent = Instance.new("RemoteEvent"); actionEvent.Name = "Action"; actionEvent.Parent = remotes
local stateEvent = Instance.new("RemoteEvent"); stateEvent.Name = "State"; stateEvent.Parent = remotes
local resultEvent = Instance.new("RemoteEvent"); resultEvent.Name = "BattleResult"; resultEvent.Parent = remotes

local function snapshot(state)
    return {Currency = state.Currency, Soldiers = {[1] = state.Soldiers[1], [2] = state.Soldiers[2], [3] = state.Soldiers[3]}, Conquered = state.Conquered}
end
local function sendState(player)
    local state = DataService.get(player)
    if state then stateEvent:FireClient(player, snapshot(state)) end
end
local function addSoldierVisual(player, level, ordinal)
    local world = workspace:FindFirstChild("MergeDominionWorld"); if not world then return end
    local folder = world:FindFirstChild("Units_" .. player.UserId)
    if not folder then folder = Instance.new("Folder"); folder.Name = "Units_" .. player.UserId; folder.Parent = world end
    local stats = GameConfig.SoldierStats[level]
    local model = Instance.new("Model"); model.Name = "Soldier_L" .. level; model.Parent = folder
    local body = Instance.new("Part"); body.Name, body.Size, body.Color, body.Material = "Body", Vector3.new(2.5, 3.5, 2.5), stats.Color, Enum.Material.Neon
    body.Anchored, body.Position, body.Parent = true, Vector3.new(-12 + (ordinal % 8) * 4, 3, 28 + math.floor(ordinal / 8) * 5), model
    model:SetAttribute("Level", level)
end
local function syncSoldierVisuals(player, state)
    local world = workspace:FindFirstChild("MergeDominionWorld"); if not world then return end
    local folderName = "Units_" .. player.UserId
    local oldFolder = world:FindFirstChild(folderName)
    if oldFolder then oldFolder:Destroy() end
    local ordinal = 0
    for level = 1, GameConfig.MaxSoldierLevel do
        for _ = 1, state.Soldiers[level] do
            addSoldierVisual(player, level, ordinal)
            ordinal += 1
        end
    end
end
local function cleanupSoldierVisuals(player)
    local world = workspace:FindFirstChild("MergeDominionWorld")
    local folder = world and world:FindFirstChild("Units_" .. player.UserId)
    if folder then folder:Destroy() end
end
local function handleAction(player, action, value)
    local state = DataService.get(player); if not state then return end
    if typeof(action) ~= "string" then return end
    if action == "RequestState" then sendState(player); return end
    if action == "Spawn" then
        if state.Currency < GameConfig.SoldierCost then resultEvent:FireClient(player, {Message = "Need " .. GameConfig.SoldierCost .. " coins to recruit."}); return end
        state.Currency -= GameConfig.SoldierCost; state.Soldiers[1] += 1; syncSoldierVisuals(player, state); resultEvent:FireClient(player, {Message = "Level 1 soldier recruited."})
    elseif action == "Merge" then
        local merged = false
        for level = 1, GameConfig.MaxSoldierLevel - 1 do
            if state.Soldiers[level] >= 2 then state.Soldiers[level] -= 2; state.Soldiers[level + 1] += 1; merged = true; break end
        end
        if merged then syncSoldierVisuals(player, state) end
        resultEvent:FireClient(player, {Message = merged and "Two soldiers merged into a higher level." or "You need two matching soldiers to merge."})
    elseif action == "Attack" then
        local index = tonumber(value); local enemy = index and GameConfig.EnemyBases[index]
        if not enemy then return end
        if state.Conquered[enemy.Id] then resultEvent:FireClient(player, {Message = enemy.Name .. " is already conquered."}); return end
        local outcome = CombatService.resolve(state, enemy)
        if outcome.Won then state.Conquered[enemy.Id] = true; state.Currency += outcome.Reward end
        outcome.Message = outcome.Won and ("Victory! " .. enemy.Name .. " conquered. +" .. outcome.Reward .. " coins.") or ("Defeat. Need more power for " .. enemy.Name .. ".")
        resultEvent:FireClient(player, outcome)
    end
    sendState(player)
end

WorldBuilder.build()
local function initializePlayer(player)
    DataService.load(player)
    local state = DataService.get(player)
    if state then syncSoldierVisuals(player, state) end
    task.defer(function() sendState(player) end)
    task.spawn(function()
        while player.Parent do task.wait(GameConfig.PassiveIncomeSeconds); local state = DataService.get(player); if state then state.Currency += GameConfig.PassiveIncomeAmount; resultEvent:FireClient(player, {Message = "+" .. GameConfig.PassiveIncomeAmount .. " passive coins."}); sendState(player) end end
    end)
end
Players.PlayerAdded:Connect(initializePlayer)
Players.PlayerRemoving:Connect(cleanupSoldierVisuals)
for _, player in Players:GetPlayers() do task.spawn(initializePlayer, player) end
actionEvent.OnServerEvent:Connect(handleAction)
