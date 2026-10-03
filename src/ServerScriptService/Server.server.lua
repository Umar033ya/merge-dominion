local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local remotes = Instance.new("Folder"); remotes.Name = "Remotes"; remotes.Parent = ReplicatedStorage
local actionEvent = Instance.new("RemoteEvent"); actionEvent.Name = "Action"; actionEvent.Parent = remotes
local stateEvent = Instance.new("RemoteEvent"); stateEvent.Name = "State"; stateEvent.Parent = remotes
local resultEvent = Instance.new("RemoteEvent"); resultEvent.Name = "BattleResult"; resultEvent.Parent = remotes
local sprintEvent = Instance.new("RemoteEvent"); sprintEvent.Name = "Sprint"; sprintEvent.Parent = remotes

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local DataService = require(script.Parent.Services.DataService)
local CombatService = require(script.Parent.Services.CombatService)
local WorldBuilder = require(script.Parent.Services.WorldBuilder)

local generationTimers = {}
local mergeSelections = {}
local sprintStates = {}
local handleSoldierPrompt

local function totalSoldiers(state)
    local total = 0
    for level = 1, GameConfig.MaxSoldierLevel do
        total += state.Soldiers[level]
    end
    return total
end

local function generationInterval(state)
    return GameConfig.GenerationIntervals[state.GenerationLevel] or GameConfig.GenerationIntervals[1]
end

local function nextUpgradeCost(state)
    return GameConfig.GenerationUpgradeCosts[state.GenerationLevel]
end

local function snapshot(player, state)
    local interval = generationInterval(state)
    return {
        Currency = state.Currency,
        Soldiers = {[1] = state.Soldiers[1], [2] = state.Soldiers[2], [3] = state.Soldiers[3]},
        Conquered = state.Conquered,
        GenerationLevel = state.GenerationLevel,
        GenerationInterval = interval,
        GenerationRemaining = math.max(0, math.ceil(generationTimers[player] or interval)),
        NextUpgradeCost = nextUpgradeCost(state),
        SoldierCount = totalSoldiers(state),
        MaxSoldiers = GameConfig.MaxSoldiers,
    }
end

local function sendState(player)
    local state = DataService.get(player)
    if state then stateEvent:FireClient(player, snapshot(player, state)) end
end

local function setSelectedVisual(model, selected)
    if not model or not model.Parent then return end
    local highlight = model:FindFirstChild("SelectionHighlight")
    if selected and not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "SelectionHighlight"
        highlight.FillColor = Color3.fromRGB(255, 225, 89)
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.45
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = model
    elseif not selected and highlight then
        highlight:Destroy()
    end
end

local function clearMergeSelection(player)
    local selected = mergeSelections[player]
    if selected then setSelectedVisual(selected, false) end
    mergeSelections[player] = nil
end

local function soldierFolder(player)
    local world = workspace:FindFirstChild("MergeDominionWorld")
    return world and world:FindFirstChild("Units_" .. player.UserId)
end

local function isOwnedSoldier(player, model)
    local folder = soldierFolder(player)
    return model and model:IsA("Model") and folder and model.Parent == folder and model:GetAttribute("OwnerUserId") == player.UserId and typeof(model:GetAttribute("Level")) == "number"
end

local function addSoldierVisual(player, level, ordinal)
    local world = workspace:FindFirstChild("MergeDominionWorld"); if not world then return end
    local folder = world:FindFirstChild("Units_" .. player.UserId)
    if not folder then folder = Instance.new("Folder"); folder.Name = "Units_" .. player.UserId; folder.Parent = world end

    local stats = GameConfig.SoldierStats[level]
    local model = Instance.new("Model")
    model.Name = "Soldier_L" .. level
    model:SetAttribute("OwnerUserId", player.UserId)
    model:SetAttribute("Level", level)
    model:SetAttribute("SoldierId", string.format("%d_%d_%d", player.UserId, level, ordinal))
    model.Parent = folder

    local position = Vector3.new(-12 + (ordinal % 8) * 4, 1.9, 28 + math.floor(ordinal / 8) * 5)
    local body = Instance.new("Part")
    body.Name = "Body"
    body.Size = Vector3.new(2.8, 3, 2.8)
    body.Shape = Enum.PartType.Ball
    body.Color = stats.Color
    body.Material = Enum.Material.SmoothPlastic
    body.Anchored = true
    body.CanCollide = false
    body.CanTouch = false
    body.Position = position
    body.Parent = model

    local belt = Instance.new("Part")
    belt.Name = "AccentBelt"
    belt.Size = Vector3.new(2.3, 0.5, 2.3)
    belt.Shape = Enum.PartType.Ball
    belt.Color = stats.AccentColor
    belt.Material = Enum.Material.Neon
    belt.Anchored = true
    belt.CanCollide = false
    belt.CanTouch = false
    belt.Position = position - Vector3.new(0, 0.35, 0)
    belt.Parent = model

    for _, x in ipairs({-0.42, 0.42}) do
        local eye = Instance.new("Part")
        eye.Name = "Eye"
        eye.Size = Vector3.new(0.28, 0.28, 0.28)
        eye.Shape = Enum.PartType.Ball
        eye.Color = Color3.fromRGB(31, 42, 55)
        eye.Material = Enum.Material.SmoothPlastic
        eye.Anchored = true
        eye.CanCollide = false
        eye.CanTouch = false
        eye.Position = position + Vector3.new(x, 0.45, -1.18)
        eye.Parent = model
    end

    local card = Instance.new("BillboardGui")
    card.Name = "SoldierCard"
    card.Size = UDim2.fromOffset(112, 42)
    card.StudsOffset = Vector3.new(0, 2.9, 0)
    card.AlwaysOnTop = true
    card.MaxDistance = 90
    card.Adornee = body
    card.Parent = model

    local cardFrame = Instance.new("Frame")
    cardFrame.Size = UDim2.fromScale(1, 1)
    cardFrame.BackgroundColor3 = Color3.fromRGB(21, 31, 45)
    cardFrame.BackgroundTransparency = 0.12
    cardFrame.BorderSizePixel = 0
    cardFrame.Parent = card
    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent = cardFrame
    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = stats.AccentColor
    cardStroke.Thickness = 1.5
    cardStroke.Transparency = 0.15
    cardStroke.Parent = cardFrame

    local identity = Instance.new("TextLabel")
    identity.BackgroundTransparency = 1
    identity.Size = UDim2.new(1, -8, 0, 17)
    identity.Position = UDim2.fromOffset(4, 3)
    identity.Text = stats.Name
    identity.Font = Enum.Font.GothamBold
    identity.TextColor3 = stats.AccentColor
    identity.TextSize = 12
    identity.TextXAlignment = Enum.TextXAlignment.Center
    identity.Parent = cardFrame

    local levelText = Instance.new("TextLabel")
    levelText.BackgroundTransparency = 1
    levelText.Size = UDim2.new(1, -8, 0, 16)
    levelText.Position = UDim2.fromOffset(4, 20)
    levelText.Text = "LEVEL " .. level
    levelText.Font = Enum.Font.GothamMedium
    levelText.TextColor3 = Color3.fromRGB(235, 242, 249)
    levelText.TextSize = 11
    levelText.TextXAlignment = Enum.TextXAlignment.Center
    levelText.Parent = cardFrame

    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "MergePrompt"
    prompt.ActionText = "Select / Merge"
    prompt.ObjectText = stats.Name .. " • Level " .. level
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = body
    prompt.Triggered:Connect(function(triggeringPlayer)
        if handleSoldierPrompt then handleSoldierPrompt(triggeringPlayer, model) end
    end)
end

local function syncSoldierVisuals(player, state)
    clearMergeSelection(player)
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

handleSoldierPrompt = function(player, model)
    local state = DataService.get(player)
    if not state or not isOwnedSoldier(player, model) then return end
    local level = model:GetAttribute("Level")
    if level >= GameConfig.MaxSoldierLevel then
        resultEvent:FireClient(player, {Message = "Level 3 soldiers cannot merge further."})
        return
    end

    local selected = mergeSelections[player]
    if selected and not isOwnedSoldier(player, selected) then
        clearMergeSelection(player)
        selected = nil
    end
    if not selected then
        mergeSelections[player] = model
        setSelectedVisual(model, true)
        resultEvent:FireClient(player, {Message = "Selected Level " .. level .. ". Choose another Level " .. level .. " soldier."})
        return
    end
    if selected == model then
        clearMergeSelection(player)
        resultEvent:FireClient(player, {Message = "Merge selection cleared."})
        return
    end
    local selectedLevel = selected:GetAttribute("Level")
    if selectedLevel ~= level then
        resultEvent:FireClient(player, {Message = "Same level required."})
        return
    end
    if state.Soldiers[level] < 2 then
        clearMergeSelection(player)
        syncSoldierVisuals(player, state)
        resultEvent:FireClient(player, {Message = "Those soldiers are no longer available."})
        return
    end

    state.Soldiers[level] -= 2
    state.Soldiers[level + 1] += 1
    syncSoldierVisuals(player, state)
    resultEvent:FireClient(player, {Message = "Two Level " .. level .. " soldiers merged into Level " .. (level + 1) .. "."})
    sendState(player)
end

local function cleanupSoldierVisuals(player)
    clearMergeSelection(player)
    local world = workspace:FindFirstChild("MergeDominionWorld")
    local folder = world and world:FindFirstChild("Units_" .. player.UserId)
    if folder then folder:Destroy() end
end

local function handleAction(player, action, value)
    local state = DataService.get(player); if not state then return end
    if typeof(action) ~= "string" then return end

    if action == "RequestState" then
        sendState(player)
        return
    elseif action == "UpgradeGeneration" then
        local currentInterval = generationInterval(state)
        local cost = nextUpgradeCost(state)
        local nextInterval = GameConfig.GenerationIntervals[state.GenerationLevel + 1]
        if not cost or not nextInterval then
            resultEvent:FireClient(player, {Message = "Soldier generation is already at maximum speed."})
            return
        end
        if currentInterval <= nextInterval then
            resultEvent:FireClient(player, {Message = "Generation speed is already at the configured interval."})
            return
        end
        if state.Currency < cost then
            resultEvent:FireClient(player, {Message = "Need " .. cost .. " coins for the next generation upgrade."})
            return
        end
        state.Currency -= cost
        state.GenerationLevel += 1
        generationTimers[player] = math.min(generationTimers[player] or nextInterval, nextInterval)
        resultEvent:FireClient(player, {Message = "Soldier generation upgraded to " .. nextInterval .. " seconds."})
    elseif action == "Attack" then
        local index = tonumber(value); local enemy = index and GameConfig.EnemyBases[index]
        if not enemy then return end
        if state.Conquered[enemy.Id] then
            resultEvent:FireClient(player, {Message = enemy.Name .. " is already conquered."})
            return
        end
        local outcome = CombatService.resolve(state, enemy)
        if outcome.Won then state.Conquered[enemy.Id] = true; state.Currency += outcome.Reward end
        outcome.Message = outcome.Won and ("Victory! " .. enemy.Name .. " conquered. +" .. outcome.Reward .. " coins.") or ("Defeat. Need more power for " .. enemy.Name .. ".")
        resultEvent:FireClient(player, outcome)
    end
    sendState(player)
end

local function runGeneration(player)
    while player.Parent do
        task.wait(1)
        local state = DataService.get(player)
        if not state then break end

        local interval = generationInterval(state)
        local remaining = generationTimers[player] or interval
        if totalSoldiers(state) >= GameConfig.MaxSoldiers then
            remaining = 0
        else
            remaining -= 1
            if remaining <= 0 then
                state.Soldiers[1] += 1
                syncSoldierVisuals(player, state)
                remaining = interval
                resultEvent:FireClient(player, {Message = "A Level 1 soldier was generated in the Soldier Yard."})
            end
        end
        generationTimers[player] = remaining
        sendState(player)
    end
end

local function setupSprint(player)
    sprintStates[player] = {Requested = false, LastSignal = 0}
    player.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then humanoid.WalkSpeed = GameConfig.DefaultWalkSpeed end
    end)
end

sprintEvent.OnServerEvent:Connect(function(player, wantsSprint)
    if typeof(wantsSprint) ~= "boolean" then return end
    local sprint = sprintStates[player]
    if not sprint then return end
    sprint.Requested = wantsSprint
    sprint.LastSignal = os.clock()
end)

RunService.Heartbeat:Connect(function(deltaTime)
    for player, sprint in pairs(sprintStates) do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if sprint.Requested and os.clock() - sprint.LastSignal > 0.6 then sprint.Requested = false end
            local target = sprint.Requested and GameConfig.SprintWalkSpeed or GameConfig.DefaultWalkSpeed
            humanoid.WalkSpeed += (target - humanoid.WalkSpeed) * math.min(1, deltaTime * 12)
        end
    end
end)

WorldBuilder.build()
local function initializePlayer(player)
    DataService.load(player)
    local state = DataService.get(player)
    if state then
        generationTimers[player] = generationInterval(state)
        syncSoldierVisuals(player, state)
        task.defer(function() sendState(player) end)
        task.spawn(runGeneration, player)
    end
end

Players.PlayerAdded:Connect(setupSprint)
Players.PlayerAdded:Connect(initializePlayer)
Players.PlayerRemoving:Connect(function(player)
    generationTimers[player] = nil
    sprintStates[player] = nil
    cleanupSoldierVisuals(player)
end)
for _, player in Players:GetPlayers() do
    setupSprint(player)
    task.spawn(initializePlayer, player)
end
actionEvent.OnServerEvent:Connect(handleAction)
