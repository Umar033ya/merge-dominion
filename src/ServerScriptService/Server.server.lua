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

local generationTimers, mergeSelections, sprintStates, cityCooldowns = {}, {}, {}, {}
local handleSoldierPrompt

local function totalSoldiers(state)
    local total = 0
    for level = 1, GameConfig.MaxSoldierLevel do total += state.Soldiers[level] end
    return total
end
local function highestLevel(state)
    for level = GameConfig.MaxSoldierLevel, 1, -1 do if state.Soldiers[level] > 0 then return level end end
    return 0
end
local function generationInterval(state) return GameConfig.GenerationIntervals[state.GenerationLevel] or GameConfig.GenerationIntervals[1] end
local function nextUpgradeCost(state) return GameConfig.GenerationUpgradeCosts[state.GenerationLevel] end
local function totalCityIncome(state)
    local total = 0
    for _, city in ipairs(GameConfig.EnemyCities) do if state.Conquered[city.Id] then total += city.IncomePerMinute end end
    return total
end
local function defenderSummary(city)
    local parts = {}
    for _, group in ipairs(city.Defenders) do table.insert(parts, group.Count .. " × L" .. group.Level) end
    return table.concat(parts, ", ")
end
local function citySummary(state)
    local summary = {}
    for _, city in ipairs(GameConfig.EnemyCities) do summary[city.Id] = {Name = city.Name, Defenders = defenderSummary(city), IncomePerMinute = city.IncomePerMinute, Conquered = state.Conquered[city.Id] == true} end
    return summary
end
local function snapshot(player, state)
    local soldiers = {}
    for level = 1, GameConfig.MaxSoldierLevel do soldiers[level] = state.Soldiers[level] end
    local interval = generationInterval(state)
    return {Currency = state.Currency, Soldiers = soldiers, Conquered = state.Conquered, Cities = citySummary(state), TotalIncomePerMinute = totalCityIncome(state), HighestLevel = highestLevel(state), GenerationLevel = state.GenerationLevel, GenerationInterval = interval, GenerationRemaining = math.max(0, math.ceil(generationTimers[player] or interval)), NextUpgradeCost = nextUpgradeCost(state), SoldierCount = totalSoldiers(state), MaxSoldiers = GameConfig.MaxSoldiers}
end
local function sendState(player)
    local state = DataService.get(player); if state then stateEvent:FireClient(player, snapshot(player, state)) end
end

local function setSelectedVisual(model, selected)
    if not model or not model.Parent then return end
    local highlight = model:FindFirstChild("SelectionHighlight")
    if selected and not highlight then
        highlight = Instance.new("Highlight"); highlight.Name = "SelectionHighlight"; highlight.FillColor = Color3.fromRGB(255, 225, 89); highlight.OutlineColor = Color3.fromRGB(255, 255, 255); highlight.FillTransparency = 0.45; highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; highlight.Parent = model
    elseif not selected and highlight then highlight:Destroy() end
end
local function clearMergeSelection(player)
    local selected = mergeSelections[player]; if selected then setSelectedVisual(selected, false) end; mergeSelections[player] = nil
end
local function soldierFolder(player)
    local world = workspace:FindFirstChild("MergeDominionWorld"); return world and world:FindFirstChild("Units_" .. player.UserId)
end
local function isOwnedSoldier(player, model)
    local folder = soldierFolder(player)
    return model and model:IsA("Model") and folder and model.Parent == folder and model:GetAttribute("OwnerUserId") == player.UserId and typeof(model:GetAttribute("Level")) == "number"
end

local function addSoldierVisual(player, level, ordinal)
    local world = workspace:FindFirstChild("MergeDominionWorld"); if not world then return end
    local folder = world:FindFirstChild("Units_" .. player.UserId); if not folder then folder = Instance.new("Folder"); folder.Name = "Units_" .. player.UserId; folder.Parent = world end
    local stats = GameConfig.SoldierStats[level]; local model = Instance.new("Model"); model.Name = "Soldier_L" .. level; model:SetAttribute("OwnerUserId", player.UserId); model:SetAttribute("Level", level); model:SetAttribute("SoldierId", string.format("%d_%d_%d", player.UserId, level, ordinal)); model.Parent = folder
    local position = Vector3.new(-12 + (ordinal % 8) * 4, 1.9, 28 + math.floor(ordinal / 8) * 5)
    local body = Instance.new("Part"); body.Name, body.Size, body.Shape, body.Color, body.Material, body.Anchored, body.CanCollide, body.CanTouch, body.Position, body.Parent = "Body", Vector3.new(2.8, 3, 2.8), Enum.PartType.Ball, stats.Color, Enum.Material.SmoothPlastic, true, false, false, position, model
    local accent = Instance.new("Part"); accent.Name, accent.Size, accent.Shape, accent.Color, accent.Material, accent.Anchored, accent.CanCollide, accent.CanTouch, accent.Position, accent.Parent = "AccentBelt", Vector3.new(2.3, 0.5, 2.3), Enum.PartType.Ball, stats.AccentColor, Enum.Material.Neon, true, false, false, position - Vector3.new(0, 0.35, 0), model
    for _, x in ipairs({-0.42, 0.42}) do local eye = Instance.new("Part"); eye.Name, eye.Size, eye.Shape, eye.Color, eye.Anchored, eye.CanCollide, eye.CanTouch, eye.Position, eye.Parent = "Eye", Vector3.new(0.28, 0.28, 0.28), Enum.PartType.Ball, Color3.fromRGB(31, 42, 55), true, false, false, position + Vector3.new(x, 0.45, -1.18), model end
    local tier = stats.Tier
    if tier >= 1 then
        for _, x in ipairs({-1.45, 1.45}) do local armor = Instance.new("Part"); armor.Name, armor.Size, armor.Color, armor.Material, armor.Anchored, armor.CanCollide, armor.CanTouch, armor.Position, armor.Parent = "Armor", Vector3.new(0.45, 1.1, 1.7), stats.AccentColor, Enum.Material.Metal, true, false, false, position + Vector3.new(x, 0, 0), model end
    end
    if tier >= 2 then local halo = Instance.new("Part"); halo.Name, halo.Shape, halo.Size, halo.Color, halo.Material, halo.Anchored, halo.CanCollide, halo.CanTouch, halo.Position, halo.Parent = "EliteHalo", Enum.PartType.Cylinder, Vector3.new(3.5, 0.2, 3.5), stats.AccentColor, Enum.Material.Neon, true, false, false, position + Vector3.new(0, 1.9, 0), model end end
    if tier >= 3 then local cape = Instance.new("Part"); cape.Name, cape.Size, cape.Color, cape.Material, cape.Anchored, cape.CanCollide, cape.CanTouch, cape.Position, cape.Parent = "CommanderCape", Vector3.new(2.2, 2.5, 0.25), stats.Color, Enum.Material.Fabric, true, false, false, position + Vector3.new(0, -0.1, 1.35), model end end
    if level == 20 then local effect = Instance.new("ParticleEmitter"); effect.Name, effect.Color, effect.Rate, effect.Lifetime, effect.Speed, effect.Parent = "LegendarySparkles", ColorSequence.new(stats.AccentColor), 8, NumberRange.new(0.5, 1), NumberRange.new(1, 2), body end

    local card = Instance.new("BillboardGui"); card.Name, card.Size, card.StudsOffset, card.AlwaysOnTop, card.MaxDistance, card.Adornee, card.Parent = "SoldierCard", UDim2.fromOffset(112, 42), Vector3.new(0, 2.9, 0), true, 90, body, model
    local frame = Instance.new("Frame"); frame.Size, frame.BackgroundColor3, frame.BackgroundTransparency, frame.BorderSizePixel, frame.Parent = UDim2.fromScale(1, 1), Color3.fromRGB(21, 31, 45), 0.12, 0, card; local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = frame; local stroke = Instance.new("UIStroke"); stroke.Color, stroke.Thickness, stroke.Parent = stats.AccentColor, 1.5, frame
    local identity = Instance.new("TextLabel"); identity.BackgroundTransparency, identity.Size, identity.Position, identity.Text, identity.Font, identity.TextColor3, identity.TextSize, identity.TextXAlignment, identity.Parent = 1, UDim2.new(1, -8, 0, 17), UDim2.fromOffset(4, 3), stats.Name, Enum.Font.GothamBold, stats.AccentColor, 12, Enum.TextXAlignment.Center, frame
    local levelText = Instance.new("TextLabel"); levelText.BackgroundTransparency, levelText.Size, levelText.Position, levelText.Text, levelText.Font, levelText.TextColor3, levelText.TextSize, levelText.TextXAlignment, levelText.Parent = 1, UDim2.new(1, -8, 0, 16), UDim2.fromOffset(4, 20), "LEVEL " .. level, Enum.Font.GothamMedium, Color3.fromRGB(235, 242, 249), 11, Enum.TextXAlignment.Center, frame
    local prompt = Instance.new("ProximityPrompt"); prompt.Name, prompt.ActionText, prompt.ObjectText, prompt.KeyboardKeyCode, prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.Parent = "MergePrompt", "Select / Merge", stats.Name .. " • Level " .. level, Enum.KeyCode.E, 0, 10, false, body
    prompt.Triggered:Connect(function(triggeringPlayer) if handleSoldierPrompt then handleSoldierPrompt(triggeringPlayer, model) end end)
end
local function syncSoldierVisuals(player, state)
    clearMergeSelection(player); local world = workspace:FindFirstChild("MergeDominionWorld"); if not world then return end
    local oldFolder = world:FindFirstChild("Units_" .. player.UserId); if oldFolder then oldFolder:Destroy() end
    local ordinal = 0
    for level = 1, GameConfig.MaxSoldierLevel do for _ = 1, state.Soldiers[level] do addSoldierVisual(player, level, ordinal); ordinal += 1 end end
end

handleSoldierPrompt = function(player, model)
    local state = DataService.get(player); if not state or not isOwnedSoldier(player, model) then return end
    local level = model:GetAttribute("Level")
    if level >= GameConfig.MaxSoldierLevel then resultEvent:FireClient(player, {Message = "Level 20 soldiers cannot merge further."}); return end
    local selected = mergeSelections[player]
    if selected and not isOwnedSoldier(player, selected) then clearMergeSelection(player); selected = nil end
    if not selected then mergeSelections[player] = model; setSelectedVisual(model, true); resultEvent:FireClient(player, {Message = "Selected Level " .. level .. ". Choose another Level " .. level .. " soldier."}); return end
    if selected == model then clearMergeSelection(player); resultEvent:FireClient(player, {Message = "Merge selection cleared."}); return end
    if selected:GetAttribute("Level") ~= level then resultEvent:FireClient(player, {Message = "Same level required."}); return end
    if state.Soldiers[level] < 2 then clearMergeSelection(player); syncSoldierVisuals(player, state); resultEvent:FireClient(player, {Message = "Those soldiers are no longer available."}); return end
    state.Soldiers[level] -= 2; state.Soldiers[level + 1] += 1; syncSoldierVisuals(player, state); resultEvent:FireClient(player, {Message = "Two Level " .. level .. " soldiers merged into Level " .. (level + 1) .. "."}); sendState(player)
end
local function cleanupSoldierVisuals(player)
    clearMergeSelection(player); local world = workspace:FindFirstChild("MergeDominionWorld"); local folder = world and world:FindFirstChild("Units_" .. player.UserId); if folder then folder:Destroy() end
end

local function removeBattleLosses(state)
    local loss = math.max(1, math.floor(totalSoldiers(state) * 0.2)); local removed = 0
    for level = GameConfig.MaxSoldierLevel, 1, -1 do
        local take = math.min(state.Soldiers[level], loss - removed); state.Soldiers[level] -= take; removed += take; if removed >= loss then break end
    end
    return removed
end
local function setCityConquered(city, player)
    local world = workspace:FindFirstChild("MergeDominionWorld"); local model = world and world:FindFirstChild(city.Id); if not model then return end
    model:SetAttribute("Conquered", true); model:SetAttribute("ConqueredByUserId", player.UserId)
    local flag = model:FindFirstChild("CityFlag"); if flag then flag.Color = Color3.fromRGB(114, 205, 245) end
    local gate = model:FindFirstChild("CityGate"); if gate then gate.Color = Color3.fromRGB(45, 126, 205) end
end
local function attackCity(player, city)
    local state = DataService.get(player); if not state then return end
    if state.Conquered[city.Id] then resultEvent:FireClient(player, {Message = city.Name .. " is already conquered."}); return end
    local now = os.clock(); local readyAt = cityCooldowns[player] or 0
    if now < readyAt then resultEvent:FireClient(player, {Message = "Battle cooldown: " .. math.ceil(readyAt - now) .. "s remaining."}); return end
    cityCooldowns[player] = now + GameConfig.CityAttackCooldown
    local outcome = CombatService.resolve(state, city)
    if outcome.Won then
        state.Conquered[city.Id] = true; state.Currency += outcome.Reward; setCityConquered(city, player)
        resultEvent:FireClient(player, {Won = true, Message = "VICTORY! " .. city.Name .. " conquered. +" .. outcome.Reward .. " coins. +" .. city.IncomePerMinute .. " coins/min secured. Power " .. outcome.PlayerPower .. " vs " .. outcome.EnemyPower .. "."})
    else
        local lost = removeBattleLosses(state); syncSoldierVisuals(player, state)
        resultEvent:FireClient(player, {Won = false, Message = "DEFEAT at " .. city.Name .. ". Lost " .. lost .. " soldiers. Power " .. outcome.PlayerPower .. " vs " .. outcome.EnemyPower .. ". Recover and try again."})
    end
    sendState(player)
end

local function handleAction(player, action)
    local state = DataService.get(player); if not state or typeof(action) ~= "string" then return end
    if action == "RequestState" then sendState(player); return end
    if action == "UpgradeGeneration" then
        local cost, nextInterval = nextUpgradeCost(state), GameConfig.GenerationIntervals[state.GenerationLevel + 1]
        if not cost or not nextInterval then resultEvent:FireClient(player, {Message = "Soldier generation is already at maximum speed."}); return end
        if state.Currency < cost then resultEvent:FireClient(player, {Message = "Need " .. cost .. " coins for the next generation upgrade."}); return end
        state.Currency -= cost; state.GenerationLevel += 1; generationTimers[player] = math.min(generationTimers[player] or nextInterval, nextInterval); resultEvent:FireClient(player, {Message = "Soldier generation upgraded to " .. nextInterval .. " seconds."}); sendState(player)
    end
end

local function runGeneration(player)
    while player.Parent do
        task.wait(1); local state = DataService.get(player); if not state then break end
        local interval, remaining = generationInterval(state), generationTimers[player] or generationInterval(state)
        if totalSoldiers(state) >= GameConfig.MaxSoldiers then remaining = 0 else remaining -= 1; if remaining <= 0 then state.Soldiers[1] += 1; syncSoldierVisuals(player, state); remaining = interval; resultEvent:FireClient(player, {Message = "A Level 1 soldier was generated in the Soldier Yard."}) end end
        generationTimers[player] = remaining; sendState(player)
    end
end
local function runCityIncome(player)
    while player.Parent do
        task.wait(GameConfig.CityIncomeSeconds); local state = DataService.get(player); if not state then break end
        local income = totalCityIncome(state); if income > 0 then state.Currency += income; resultEvent:FireClient(player, {Message = "+" .. income .. " city income collected."}); sendState(player) end
    end
end
local function setupSprint(player)
    sprintStates[player] = {Requested = false, LastSignal = 0}
    player.CharacterAdded:Connect(function(character) local humanoid = character:WaitForChild("Humanoid", 5); if humanoid then humanoid.WalkSpeed = GameConfig.DefaultWalkSpeed end end)
end
sprintEvent.OnServerEvent:Connect(function(player, wantsSprint) if typeof(wantsSprint) == "boolean" and sprintStates[player] then sprintStates[player].Requested, sprintStates[player].LastSignal = wantsSprint, os.clock() end end)
RunService.Heartbeat:Connect(function(deltaTime)
    for player, sprint in pairs(sprintStates) do local character = player.Character; local humanoid = character and character:FindFirstChildOfClass("Humanoid"); if humanoid then if sprint.Requested and os.clock() - sprint.LastSignal > 0.6 then sprint.Requested = false end; local target = sprint.Requested and GameConfig.SprintWalkSpeed or GameConfig.DefaultWalkSpeed; humanoid.WalkSpeed += (target - humanoid.WalkSpeed) * math.min(1, deltaTime * 12) end end
end)

local world = WorldBuilder.build()
for _, city in ipairs(GameConfig.EnemyCities) do local model = world:FindFirstChild(city.Id); local prompt = model and model:FindFirstChild("AttackPrompt", true); if prompt then prompt.Triggered:Connect(function(player) attackCity(player, city) end) end end
local function initializePlayer(player)
    DataService.load(player); local state = DataService.get(player); if state then generationTimers[player] = generationInterval(state); syncSoldierVisuals(player, state); task.defer(function() sendState(player) end); task.spawn(runGeneration, player); task.spawn(runCityIncome, player) end
end
Players.PlayerAdded:Connect(setupSprint); Players.PlayerAdded:Connect(initializePlayer)
Players.PlayerRemoving:Connect(function(player) generationTimers[player], sprintStates[player], cityCooldowns[player] = nil, nil, nil; cleanupSoldierVisuals(player) end)
for _, player in Players:GetPlayers() do setupSprint(player); task.spawn(initializePlayer, player) end
actionEvent.OnServerEvent:Connect(handleAction)
