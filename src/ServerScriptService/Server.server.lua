local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder"); remotes.Name = "Remotes"; remotes.Parent = ReplicatedStorage
local function getRemote(name)
    local remote = remotes:FindFirstChild(name); if remote and not remote:IsA("RemoteEvent") then remote:Destroy(); remote = nil end; remote = remote or Instance.new("RemoteEvent"); remote.Name, remote.Parent = name, remotes; return remote
end
local actionEvent = getRemote("Action")
local stateEvent = getRemote("State")
local resultEvent = getRemote("BattleResult")
local sprintEvent = getRemote("Sprint")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local worldBuilderOk, WorldBuilder = pcall(require, script.Parent.Services.WorldBuilder)
if not worldBuilderOk then
    warn("[MergeDominion] WorldBuilder module failed to load; no player spawn will be allowed: " .. tostring(WorldBuilder))
    error(WorldBuilder, 0)
end

local function buildWorldOrFail()
    local lastError
    for attempt = 1, 2 do
        local ok, result = xpcall(WorldBuilder.build, debug.traceback)
        if ok and result and result:GetAttribute("WorldReady") == true then
            local required = {"ArenaGround", "MainBase", "SoldierYard", "Checkpoints", "PlayerSpawn"}
            for _, name in ipairs(required) do
                if not result:FindFirstChild(name) then
                    ok = false
                    result = "missing required world object: " .. name
                    break
                end
            end
            if ok then
                for _, city in ipairs(GameConfig.EnemyCities) do
                    local model = result:FindFirstChild(city.Id)
                    if not model or not model:FindFirstChild("AttackPrompt", true) or not model:FindFirstChild("Defenders") or #model.Defenders:GetChildren() == 0 then
                        ok = false
                        result = "missing city, attack prompt, or visible defenders: " .. city.Id
                        break
                    end
                end
            end
        end
        if ok then
            print("[MergeDominion] World ready before player initialization: " .. result:GetFullName())
            return result
        end
        lastError = result
        warn("[MergeDominion] World build attempt " .. attempt .. " failed: " .. tostring(result))
        task.wait()
    end
    error("[MergeDominion] WorldBuilder failed after retries: " .. tostring(lastError), 0)
end

-- Build and validate the physical world before loading persistence or connecting players.
local world = buildWorldOrFail()

local DataService = require(script.Parent.Services.DataService)
local CombatService = require(script.Parent.Services.CombatService)

local generationTimers, mergeSelections, sprintStates, cityCooldowns, initializedPlayers = {}, {}, {}, {}, {}
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
local function armyPosition(location)
    if location == "MainBase" then return GameConfig.SoldierYardPosition end
    for _, city in ipairs(GameConfig.EnemyCities) do if city.Id == location then return city.Position end end
    return GameConfig.SoldierYardPosition
end
local function defenderSummary(city)
    local parts = {}
    for _, group in ipairs(city.Defenders) do table.insert(parts, group.Count .. " × L" .. group.Level) end
    return table.concat(parts, ", ")
end
local function citySummary(state)
    local summary = {}
    for _, city in ipairs(GameConfig.EnemyCities) do summary[city.Id] = {Name = city.Name, Defenders = defenderSummary(city), IncomePerMinute = city.IncomePerMinute, Conquered = state.Conquered[city.Id] == true, Stationed = state.ArmyLocation == city.Id, StationedCount = state.ArmyLocation == city.Id and totalSoldiers(state) or 0, Distance = math.floor((city.Position - armyPosition(state.ArmyLocation)).Magnitude), Target = state.ArmyDestination == city.Id} end
    return summary
end
local function snapshot(player, state)
    local soldiers = {}
    for level = 1, GameConfig.MaxSoldierLevel do soldiers[level] = state.Soldiers[level] end
    local interval = generationInterval(state)
    local distance = nil
    if state.ArmyDestination then for _, city in ipairs(GameConfig.EnemyCities) do if city.Id == state.ArmyDestination then distance = math.floor((city.Position - armyPosition(state.ArmyLocation)).Magnitude); break end end end
    return {Currency = state.Currency, Soldiers = soldiers, Conquered = state.Conquered, Cities = citySummary(state), TotalIncomePerMinute = totalCityIncome(state), HighestLevel = highestLevel(state), GenerationLevel = state.GenerationLevel, GenerationInterval = interval, GenerationRemaining = math.max(0, math.ceil(generationTimers[player] or interval)), NextUpgradeCost = nextUpgradeCost(state), SoldierCount = totalSoldiers(state), MaxSoldiers = GameConfig.MaxSoldiers, ArmyLocation = state.ArmyLocation, ArmyStatus = state.ArmyStatus, ArmyDestination = state.ArmyDestination, ArmyDistance = distance}
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

local function soldierPart(model, name, size, position, color, material, shape, rotation)
    local item = Instance.new("Part")
    item.Name, item.Size, item.Position, item.Color, item.Material = name, size, position, color, material or Enum.Material.SmoothPlastic
    item.Shape, item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = shape or Enum.PartType.Block, true, false, false, false
    if rotation then item.CFrame = CFrame.new(position) * CFrame.Angles(rotation.X, rotation.Y, rotation.Z) end
    item.Parent = model
    return item
end

local function meshSoldierPart(model, name, size, position, color, material, meshType, meshScale, rotation)
    local item = soldierPart(model, name, size, position, color, material, Enum.PartType.Block, rotation)
    local mesh = Instance.new("SpecialMesh")
    mesh.Name = "Mesh"
    mesh.MeshType = meshType
    mesh.Scale = meshScale or Vector3.one
    mesh.Parent = item
    return item
end

local function addWeapon(model, level, base, stats)
    if level == 3 or (level >= 5 and level % 4 == 1) then
        meshSoldierPart(model, "SwordBlade", Vector3.new(0.22, 2.5, 0.45), base + Vector3.new(1.25, 0.15, -0.15), Color3.fromRGB(225, 235, 245), Enum.Material.Metal, Enum.MeshType.Wedge, Vector3.new(0.8, 1, 0.45), Vector3.new(0, 0, math.rad(-18)))
        meshSoldierPart(model, "SwordHilt", Vector3.new(1.1, 0.2, 0.25), base + Vector3.new(1.25, -1.05, -0.15), stats.AccentColor, Enum.Material.Metal, Enum.MeshType.Cylinder, Vector3.new(1, 0.7, 1))
    elseif level == 4 or (level >= 6 and level % 4 == 2) then
        meshSoldierPart(model, "Bow", Vector3.new(0.2, 2.8, 0.2), base + Vector3.new(1.35, 0.2, -0.05), stats.AccentColor, Enum.Material.Wood, Enum.MeshType.Wedge, Vector3.new(0.65, 1, 0.65), Vector3.new(0, 0, math.rad(-20)))
        meshSoldierPart(model, "BowGrip", Vector3.new(0.12, 1.1, 0.12), base + Vector3.new(1.35, 0.2, -0.05), Color3.fromRGB(245, 235, 190), Enum.Material.Wood, Enum.MeshType.Cylinder, Vector3.new(1, 0.7, 1))
    elseif level >= 8 then
        meshSoldierPart(model, "EnergyStaff", Vector3.new(0.25, 3.2, 0.25), base + Vector3.new(1.25, 0.4, 0), stats.AccentColor, Enum.Material.Metal, Enum.MeshType.Cylinder, Vector3.new(0.8, 1, 0.8))
        meshSoldierPart(model, "StaffCrystal", Vector3.new(0.65, 0.65, 0.65), base + Vector3.new(1.25, 2.05, 0), stats.AccentColor, Enum.Material.Neon, Enum.MeshType.Sphere, Vector3.new(1, 1, 1))
    end
end

local function addSoldierVisual(player, level, ordinal, origin)
    local world = workspace:FindFirstChild("MergeDominionWorld"); if not world then return end
    local folder = world:FindFirstChild("Units_" .. player.UserId); if not folder then folder = Instance.new("Folder"); folder.Name = "Units_" .. player.UserId; folder.Parent = world end
    local stats = GameConfig.SoldierStats[level]; local model = Instance.new("Model"); model.Name = "Soldier_L" .. level; model:SetAttribute("OwnerUserId", player.UserId); model:SetAttribute("Level", level); model:SetAttribute("SoldierId", string.format("%d_%d_%d", player.UserId, level, ordinal)); model.Parent = folder
    origin = origin or GameConfig.SoldierYardPosition
    local position = origin + Vector3.new(-12 + (ordinal % 8) * 4, 0, -8 + math.floor(ordinal / 8) * 5)
    local base = position + Vector3.new(0, 0.6, 0)
    local torso = meshSoldierPart(model, "Torso", Vector3.new(1.65, 2.05, 1.05), base + Vector3.new(0, 2.2, 0), stats.Color, Enum.Material.SmoothPlastic, Enum.MeshType.Torso, Vector3.new(1.05, 1.05, 1.05))
    meshSoldierPart(model, "LeftLeg", Vector3.new(0.55, 1.45, 0.65), base + Vector3.new(-0.43, 0.65, 0), Color3.fromRGB(42, 57, 76), Enum.Material.SmoothPlastic, Enum.MeshType.Cylinder, Vector3.new(0.85, 1, 0.85))
    meshSoldierPart(model, "RightLeg", Vector3.new(0.55, 1.45, 0.65), base + Vector3.new(0.43, 0.65, 0), Color3.fromRGB(42, 57, 76), Enum.Material.SmoothPlastic, Enum.MeshType.Cylinder, Vector3.new(0.85, 1, 0.85))
    meshSoldierPart(model, "LeftBoot", Vector3.new(0.7, 0.35, 0.95), base + Vector3.new(-0.43, -0.2, -0.12), Color3.fromRGB(28, 34, 45), Enum.Material.SmoothPlastic, Enum.MeshType.Wedge, Vector3.new(1, 1, 1))
    meshSoldierPart(model, "RightBoot", Vector3.new(0.7, 0.35, 0.95), base + Vector3.new(0.43, -0.2, -0.12), Color3.fromRGB(28, 34, 45), Enum.Material.SmoothPlastic, Enum.MeshType.Wedge, Vector3.new(1, 1, 1))
    for _, arm in ipairs({-1, 1}) do
        meshSoldierPart(model, arm == -1 and "LeftArm" or "RightArm", Vector3.new(0.5, 1.65, 0.58), base + Vector3.new(arm * 1.1, 2.2, 0), stats.Color, Enum.Material.SmoothPlastic, Enum.MeshType.Cylinder, Vector3.new(0.85, 1, 0.85), Vector3.new(0, 0, math.rad(-arm * 8)))
        meshSoldierPart(model, arm == -1 and "LeftGlove" or "RightGlove", Vector3.new(0.55, 0.45, 0.65), base + Vector3.new(arm * 1.13, 1.25, -0.02), stats.AccentColor, Enum.Material.SmoothPlastic, Enum.MeshType.Sphere, Vector3.new(1, 0.8, 1))
    end
    local head = meshSoldierPart(model, "Head", Vector3.new(1.45, 1.45, 1.35), base + Vector3.new(0, 4.05, 0), Color3.fromRGB(255, 205, 164), Enum.Material.SmoothPlastic, Enum.MeshType.Head, Vector3.new(1.05, 1.05, 1.05))
    meshSoldierPart(model, "Helmet", Vector3.new(1.65, 0.62, 1.5), base + Vector3.new(0, 4.72, 0), stats.AccentColor, Enum.Material.Metal, Enum.MeshType.Sphere, Vector3.new(1.1, 0.55, 1.05))
    soldierPart(model, "HelmetBrim", Vector3.new(1.8, 0.16, 0.7), base + Vector3.new(0, 4.48, -0.42), stats.AccentColor, Enum.Material.Metal)
    soldierPart(model, "Visor", Vector3.new(1.05, 0.22, 0.12), base + Vector3.new(0, 4.08, -0.66), Color3.fromRGB(31, 42, 55), Enum.Material.Glass)
    for _, x in ipairs({-0.25, 0.25}) do meshSoldierPart(model, "Eye", Vector3.new(0.16, 0.16, 0.08), base + Vector3.new(x, 4.15, -0.7), Color3.fromRGB(31, 42, 55), Enum.Material.SmoothPlastic, Enum.MeshType.Sphere, Vector3.new(1, 1, 0.5)) end
    soldierPart(model, "UtilityBelt", Vector3.new(1.75, 0.28, 1.12), base + Vector3.new(0, 1.45, 0), stats.AccentColor, Enum.Material.Metal)
    if level >= 2 then soldierPart(model, "TacticalVest", Vector3.new(1.25, 1.1, 1.16), base + Vector3.new(0, 2.35, -0.58), stats.AccentColor, Enum.Material.Metal) end
    if level >= 5 then
        for _, x in ipairs({-0.82, 0.82}) do meshSoldierPart(model, "ShoulderArmor", Vector3.new(0.7, 0.38, 0.78), base + Vector3.new(x, 3.05, 0), stats.AccentColor, Enum.Material.Metal, Enum.MeshType.Sphere, Vector3.new(1, 0.7, 1)) end
    end
    if level >= 9 then meshSoldierPart(model, "ChestEmblem", Vector3.new(0.42, 0.42, 0.12), base + Vector3.new(0, 2.7, -0.67), stats.AccentColor, Enum.Material.Neon, Enum.MeshType.Sphere, Vector3.new(1, 1, 0.5)) end
    if level >= 10 then soldierPart(model, "TacticalPack", Vector3.new(1.2, 1.25, 0.38), base + Vector3.new(0, 2.25, 0.62), stats.Color, Enum.Material.Metal) end
    if level >= 11 then soldierPart(model, "EliteVisor", Vector3.new(1.25, 0.18, 0.14), base + Vector3.new(0, 4.22, -0.7), stats.AccentColor, Enum.Material.Neon) end
    if level == 12 then soldierPart(model, "EliteBanner", Vector3.new(0.16, 1.7, 0.16), base + Vector3.new(-1.3, 2.55, 0), stats.AccentColor, Enum.Material.Metal) end
    if level >= 13 then
        soldierPart(model, "CommanderCrest", Vector3.new(0.25, 1.05, 0.25), base + Vector3.new(0, 5.25, 0), stats.AccentColor, Enum.Material.Neon)
        soldierPart(model, "CommanderCape", Vector3.new(1.55, 1.9, 0.18), base + Vector3.new(0, 2.15, 0.65), stats.Color, Enum.Material.Fabric)
    end
    if level >= 17 then meshSoldierPart(model, "LegendaryAura", Vector3.new(2.5, 0.16, 2.5), base + Vector3.new(0, 5.35, 0), stats.AccentColor, Enum.Material.Neon, Enum.MeshType.Cylinder, Vector3.new(1, 0.35, 1)) end
    if level == 20 then
        meshSoldierPart(model, "LegendaryCrown", Vector3.new(1.25, 0.35, 1.25), base + Vector3.new(0, 5.55, 0), stats.AccentColor, Enum.Material.Neon, Enum.MeshType.Cylinder, Vector3.new(1, 0.6, 1))
        local effect = Instance.new("ParticleEmitter"); effect.Name, effect.Color, effect.Rate, effect.Lifetime, effect.Speed, effect.Parent = "LegendarySparkles", ColorSequence.new(stats.AccentColor), 8, NumberRange.new(0.5, 1), NumberRange.new(1, 2), torso
    end
    addWeapon(model, level, base, stats)

    local card = Instance.new("BillboardGui"); card.Name, card.Size, card.StudsOffset, card.AlwaysOnTop, card.MaxDistance, card.Adornee, card.Parent = "SoldierCard", UDim2.fromOffset(112, 42), Vector3.new(0, 3.25, 0), true, 90, torso, model
    local frame = Instance.new("Frame"); frame.Size, frame.BackgroundColor3, frame.BackgroundTransparency, frame.BorderSizePixel, frame.Parent = UDim2.fromScale(1, 1), Color3.fromRGB(21, 31, 45), 0.12, 0, card; local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = frame; local stroke = Instance.new("UIStroke"); stroke.Color, stroke.Thickness, stroke.Parent = stats.AccentColor, 1.5, frame
    local identity = Instance.new("TextLabel"); identity.BackgroundTransparency, identity.Size, identity.Position, identity.Text, identity.Font, identity.TextColor3, identity.TextSize, identity.TextXAlignment, identity.Parent = 1, UDim2.new(1, -8, 0, 17), UDim2.fromOffset(4, 3), stats.Name, Enum.Font.GothamBold, stats.AccentColor, 12, Enum.TextXAlignment.Center, frame
    local levelText = Instance.new("TextLabel"); levelText.BackgroundTransparency, levelText.Size, levelText.Position, levelText.Text, levelText.Font, levelText.TextColor3, levelText.TextSize, levelText.TextXAlignment, levelText.Parent = 1, UDim2.new(1, -8, 0, 16), UDim2.fromOffset(4, 20), "LEVEL " .. level, Enum.Font.GothamMedium, Color3.fromRGB(235, 242, 249), 11, Enum.TextXAlignment.Center, frame
    local prompt = Instance.new("ProximityPrompt"); prompt.Name, prompt.ActionText, prompt.ObjectText, prompt.KeyboardKeyCode, prompt.HoldDuration, prompt.MaxActivationDistance, prompt.RequiresLineOfSight, prompt.Parent = "MergePrompt", "Select / Merge", stats.Name .. " • Level " .. level, Enum.KeyCode.E, 0, 10, false, torso
    prompt.Triggered:Connect(function(triggeringPlayer) if handleSoldierPrompt then handleSoldierPrompt(triggeringPlayer, model) end end)
end
local function playMergeEffect(position, color)
    local world = workspace:FindFirstChild("MergeDominionWorld"); if not world then return end
    local anchor = Instance.new("Part")
    anchor.Name, anchor.Size, anchor.Position, anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.Transparency, anchor.Parent = "MergeBurst", Vector3.new(1, 1, 1), position, true, false, false, false, 1, world
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name, emitter.Color, emitter.LightEmission, emitter.Rate, emitter.Lifetime, emitter.Speed, emitter.SpreadAngle, emitter.Parent = "MergeParticles", ColorSequence.new(color), 0.7, 0, NumberRange.new(0.35, 0.7), NumberRange.new(4, 8), Vector2.new(360, 360), anchor
    emitter:Emit(18)
    Debris:AddItem(anchor, 1.2)
end
local function syncSoldierVisuals(player, state, mergePosition, mergeColor)
    clearMergeSelection(player); local world = workspace:FindFirstChild("MergeDominionWorld"); if not world then return end
    local oldFolder = world:FindFirstChild("Units_" .. player.UserId); if oldFolder then oldFolder:Destroy() end
    local ordinal = 0
    local origin = armyPosition(state.ArmyLocation)
    for level = 1, GameConfig.MaxSoldierLevel do for _ = 1, state.Soldiers[level] do addSoldierVisual(player, level, ordinal, origin); ordinal += 1 end end
    if mergePosition then playMergeEffect(mergePosition, mergeColor or Color3.fromRGB(255, 225, 89)) end
end

handleSoldierPrompt = function(player, model)
    local state = DataService.get(player); if not state or not isOwnedSoldier(player, model) then return end
    if state.ArmyStatus == "Traveling" or state.ArmyStatus == "Arriving" or state.ArmyStatus == "Fighting" then resultEvent:FireClient(player, {Message = "Your army is currently engaged in a campaign."}); return end
    local level = model:GetAttribute("Level")
    if level >= GameConfig.MaxSoldierLevel then resultEvent:FireClient(player, {Message = "Level 20 soldiers cannot merge further."}); return end
    local selected = mergeSelections[player]
    if selected and not isOwnedSoldier(player, selected) then clearMergeSelection(player); selected = nil end
    if not selected then mergeSelections[player] = model; setSelectedVisual(model, true); resultEvent:FireClient(player, {Message = "Selected Level " .. level .. ". Choose another Level " .. level .. " soldier."}); return end
    if selected == model then clearMergeSelection(player); resultEvent:FireClient(player, {Message = "Merge selection cleared."}); return end
    if selected:GetAttribute("Level") ~= level then resultEvent:FireClient(player, {Message = "Same level required."}); return end
    if state.Soldiers[level] < 2 then clearMergeSelection(player); syncSoldierVisuals(player, state); resultEvent:FireClient(player, {Message = "Those soldiers are no longer available."}); return end
    local mergePosition = selected:GetPivot().Position
    state.Soldiers[level] -= 2; state.Soldiers[level + 1] += 1; syncSoldierVisuals(player, state, mergePosition, GameConfig.SoldierStats[level + 1].AccentColor); resultEvent:FireClient(player, {Message = "Two Level " .. level .. " soldiers merged into Level " .. (level + 1) .. "."}); sendState(player)
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
    local territory = model:FindFirstChild("TerritoryRing"); if territory then territory.Transparency = 0.78; territory.Color = Color3.fromRGB(114, 205, 245) end
    local badgeAnchor = model:FindFirstChild("ControlledBadgeAnchor") or Instance.new("Part"); badgeAnchor.Name, badgeAnchor.Size, badgeAnchor.Position, badgeAnchor.Anchored, badgeAnchor.Transparency, badgeAnchor.CanCollide, badgeAnchor.CanTouch, badgeAnchor.CanQuery, badgeAnchor.Parent = "ControlledBadgeAnchor", Vector3.new(1, 1, 1), city.Position + Vector3.new(0, 16, 0), true, 1, false, false, false, model
    local badge = badgeAnchor:FindFirstChild("ControlledBadge") or Instance.new("BillboardGui"); badge.Name, badge.Size, badge.StudsOffset, badge.AlwaysOnTop, badge.MaxDistance, badge.Adornee, badge.Parent = "ControlledBadge", UDim2.fromOffset(240, 42), Vector3.new(0, 0, 0), true, 400, badgeAnchor, badgeAnchor
    local badgeText = badge:FindFirstChild("Text") or Instance.new("TextLabel"); badgeText.Name, badgeText.BackgroundTransparency, badgeText.Size, badgeText.Text, badgeText.TextColor3, badgeText.TextScaled, badgeText.Font, badgeText.Parent = "Text", 1, UDim2.fromScale(1, 1), "CONTROLLED • +" .. city.IncomePerMinute .. "/MIN", Color3.fromRGB(139, 255, 190), true, Enum.Font.GothamBold, badge
    local prompt = model:FindFirstChild("AttackPrompt", true); if prompt then prompt.ActionText, prompt.ObjectText = "Controlled Base", city.Name .. " • +" .. city.IncomePerMinute .. "/min" end
    local defenders = model:FindFirstChild("Defenders"); if defenders then defenders:Destroy() end
end
local function createDestinationMarker(city)
    local campaign = world:FindFirstChild("CampaignMarkers") or Instance.new("Folder"); campaign.Name, campaign.Parent = "CampaignMarkers", world
    local marker = Instance.new("Model"); marker.Name = "Destination_" .. city.Id; marker.Parent = campaign
    local pad = Instance.new("Part"); pad.Name, pad.Shape, pad.Size, pad.Position, pad.Color, pad.Material, pad.Anchored, pad.CanCollide, pad.CanTouch, pad.CanQuery = "TargetPad", Enum.PartType.Cylinder, Vector3.new(10, 0.25, 10), city.Position + Vector3.new(0, 0.3, 0), Color3.fromRGB(255, 213, 104), Enum.Material.Neon, true, false, false, false; pad.Parent = marker
    local gui = Instance.new("BillboardGui"); gui.Name, gui.Size, gui.StudsOffset, gui.AlwaysOnTop, gui.MaxDistance, gui.Adornee, gui.Parent = "TargetLabel", UDim2.fromOffset(190, 34), Vector3.new(0, 4, 0), true, 400, pad, marker
    local label = Instance.new("TextLabel"); label.BackgroundTransparency, label.Size, label.Text, label.TextColor3, label.TextScaled, label.Font = 1, UDim2.fromScale(1, 1), "ARMY DESTINATION\n" .. city.Name, Color3.fromRGB(255, 238, 151), true, Enum.Font.GothamBold; label.Parent = gui
    return marker
end
local function moveArmyModels(player, fromPosition, toPosition, city)
    local folder = soldierFolder(player); if not folder then return end
    local offsets = {}
    for _, model in ipairs(folder:GetChildren()) do if model:IsA("Model") then offsets[model] = model:GetPivot().Position - fromPosition end end
    local points = {fromPosition}
    if (fromPosition - GameConfig.SoldierYardPosition).Magnitude > 2 and (toPosition - GameConfig.MainBasePosition).Magnitude > 2 then table.insert(points, GameConfig.MainBasePosition) end
    table.insert(points, toPosition)
    local totalLength = 0
    for index = 1, #points - 1 do totalLength += (points[index + 1] - points[index]).Magnitude end
    local marker = createDestinationMarker(city)
    local elapsed = 0
    for segment = 1, #points - 1 do
        local startPosition, endPosition = points[segment], points[segment + 1]
        local segmentLength = (endPosition - startPosition).Magnitude
        local segmentTime = GameConfig.ArmyTravelSeconds * segmentLength / math.max(totalLength, 1)
        local started = os.clock()
        while os.clock() - started < segmentTime do
            if not player.Parent then if marker.Parent then marker:Destroy() end; return end
            local alpha = math.clamp((os.clock() - started) / segmentTime, 0, 1)
            local center = startPosition:Lerp(endPosition, alpha)
            local direction = (endPosition - startPosition).Unit
            elapsed += 0.12
            for model, offset in pairs(offsets) do if model.Parent then local bob = Vector3.new(0, math.abs(math.sin(elapsed * 9 + model:GetAttribute("Level") * 0.3)) * 0.16, 0); model:PivotTo(CFrame.lookAt(center + offset + bob, center + offset + direction)) end end
            task.wait(0.12)
        end
    end
    for model, offset in pairs(offsets) do if model.Parent then model:PivotTo(CFrame.new(toPosition + offset)) end end
    if marker.Parent then marker:Destroy() end
end
local function spawnHitEffect(model, color)
    if not model or not model.Parent then return end
    local anchor = Instance.new("Part"); anchor.Name, anchor.Size, anchor.Position, anchor.Anchored, anchor.CanCollide, anchor.Transparency, anchor.Parent = "BattleHit", Vector3.new(0.4, 0.4, 0.4), model:GetPivot().Position + Vector3.new(0, 2.2, 0), true, false, 1, world
    local emitter = Instance.new("ParticleEmitter"); emitter.Color, emitter.Rate, emitter.Lifetime, emitter.Speed, emitter.Parent = ColorSequence.new(color), 0, NumberRange.new(0.15, 0.3), NumberRange.new(3, 5), anchor; emitter:Emit(5)
    local gui = Instance.new("BillboardGui"); gui.Size, gui.StudsOffset, gui.AlwaysOnTop, gui.Adornee, gui.Parent = UDim2.fromOffset(60, 24), Vector3.new(0, 1, 0), true, anchor, anchor
    local text = Instance.new("TextLabel"); text.BackgroundTransparency, text.Size, text.Text, text.TextColor3, text.TextScaled, text.Font = 1, UDim2.fromScale(1, 1), "HIT", color, true, Enum.Font.GothamBold; text.Parent = gui
    Debris:AddItem(anchor, 0.55)
end
local function showBattle(player, city)
    local folder = soldierFolder(player); local cityModel = world:FindFirstChild(city.Id); local enemies = cityModel and cityModel:FindFirstChild("Defenders")
    local highlights = {}
    local combatants = {}
    for _, container in ipairs({folder, enemies}) do if container then for _, model in ipairs(container:GetChildren()) do if model:IsA("Model") then local highlight = Instance.new("Highlight"); highlight.FillColor = container == folder and Color3.fromRGB(100, 210, 255) or Color3.fromRGB(255, 95, 75); highlight.OutlineColor = highlight.FillColor; highlight.FillTransparency = 0.35; highlight.Parent = model; table.insert(highlights, highlight) end end end end
    if folder then for _, model in ipairs(folder:GetChildren()) do if model:IsA("Model") then table.insert(combatants, model) end end end
    if enemies then for _, model in ipairs(enemies:GetChildren()) do if model:IsA("Model") then table.insert(combatants, model) end end end
    local playerCenter = city.Position + Vector3.new(0, 0, -10); if folder and #folder:GetChildren() > 0 then playerCenter = folder:GetChildren()[1]:GetPivot().Position end
    local enemyCenter = city.Position + Vector3.new(0, 0, 10); if enemies and #enemies:GetChildren() > 0 then enemyCenter = enemies:GetChildren()[1]:GetPivot().Position end
    if folder then for _, model in ipairs(folder:GetChildren()) do if model:IsA("Model") then local p = model:GetPivot().Position; model:PivotTo(CFrame.lookAt(p, Vector3.new(enemyCenter.X, p.Y, enemyCenter.Z))) end end end
    if enemies then for _, model in ipairs(enemies:GetChildren()) do if model:IsA("Model") then local p = model:GetPivot().Position; model:PivotTo(CFrame.lookAt(p, Vector3.new(playerCenter.X, p.Y, playerCenter.Z))) end end end
    resultEvent:FireClient(player, {Message = "BATTLE! Your army is engaging the defenders of " .. city.Name .. "."})
    local started = os.clock()
    local lastHit = 0
    while os.clock() - started < GameConfig.BattleSeconds do
        if not player.Parent then for _, highlight in ipairs(highlights) do if highlight.Parent then highlight:Destroy() end end; return end
        for _, highlight in ipairs(highlights) do if highlight.Parent then highlight.FillTransparency = 0.2 + ((os.clock() % 0.8) * 0.3) end end
        for index, model in ipairs(combatants) do if model.Parent then local position = model:GetPivot().Position; local direction = index % 2 == 0 and 1 or -1; local target = model:GetAttribute("EnemyLevel") and playerCenter or enemyCenter; local nextPosition = position + Vector3.new(direction * 0.35, 0, math.sin(os.clock() * 8 + index) * 0.3); model:PivotTo(CFrame.lookAt(nextPosition, Vector3.new(target.X, nextPosition.Y, target.Z))) end end
        if os.clock() - lastHit > 0.55 and #combatants > 0 then lastHit = os.clock(); local target = combatants[math.floor(os.clock() * 10) % #combatants + 1]; spawnHitEffect(target, target:GetAttribute("EnemyLevel") and Color3.fromRGB(255, 105, 90) or Color3.fromRGB(125, 220, 255)) end
        task.wait(0.25)
    end
    for _, highlight in ipairs(highlights) do if highlight.Parent then highlight:Destroy() end end
end
local function runAttackSequenceUnsafe(player, city, state, fromPosition)
    moveArmyModels(player, fromPosition, city.Position, city)
    if not player.Parent then return end
    state.ArmyStatus = "Arriving"; sendState(player); resultEvent:FireClient(player, {Message = "Your army has arrived at " .. city.Name .. ". Forming up at the gate."}); task.wait(1)
    state.ArmyStatus = "Fighting"; sendState(player); showBattle(player, city)
    local outcome = CombatService.resolve(state, city)
    state.ArmyDestination = nil
    if outcome.Won then
        state.Conquered[city.Id] = true; state.Currency += outcome.Reward; state.ArmyLocation = city.Id; state.ArmyStatus = "Stationed"; setCityConquered(city, player); syncSoldierVisuals(player, state)
        resultEvent:FireClient(player, {Won = true, Message = "VICTORY! " .. city.Name .. " conquered. Your surviving army is stationed here. +" .. outcome.Reward .. " coins. +" .. city.IncomePerMinute .. " coins/min secured. Power " .. outcome.PlayerPower .. " vs " .. outcome.EnemyPower .. "."})
    else
        local lost = removeBattleLosses(state); state.ArmyLocation = city.Id; state.ArmyStatus = "Stationed"; syncSoldierVisuals(player, state)
        resultEvent:FireClient(player, {Won = false, Message = "DEFEAT at " .. city.Name .. ". Lost " .. lost .. " soldiers. Survivors remain stationed near the battle site. Power " .. outcome.PlayerPower .. " vs " .. outcome.EnemyPower .. "."})
    end
    sendState(player)
end
local function runAttackSequence(player, city, state, fromPosition)
    local ok, errorMessage = xpcall(function() runAttackSequenceUnsafe(player, city, state, fromPosition) end, debug.traceback)
    if not ok then
        warn("[MergeDominion] Campaign failed for " .. player.Name .. " at " .. city.Id .. ": " .. tostring(errorMessage))
        if player.Parent and DataService.get(player) == state then
            state.ArmyStatus, state.ArmyDestination = "Stationed", nil
            syncSoldierVisuals(player, state); resultEvent:FireClient(player, {Won = false, Message = "Campaign interrupted safely. Your army has regrouped at " .. state.ArmyLocation .. "."}); sendState(player)
        end
    end
end
local function attackCity(player, city)
    local state = DataService.get(player); if not state then return end
    if state.Conquered[city.Id] then resultEvent:FireClient(player, {Message = city.Name .. " is already controlled. +" .. city.IncomePerMinute .. " coins/min."}); return end
    if state.ArmyStatus == "Traveling" or state.ArmyStatus == "Arriving" or state.ArmyStatus == "Fighting" then resultEvent:FireClient(player, {Message = "Your army is already on a campaign."}); return end
    if totalSoldiers(state) <= 0 then resultEvent:FireClient(player, {Message = "You need at least one soldier before attacking."}); return end
    local now = os.clock(); local readyAt = cityCooldowns[player] or 0
    if now < readyAt then resultEvent:FireClient(player, {Message = "Battle cooldown: " .. math.ceil(readyAt - now) .. "s remaining."}); return end
    cityCooldowns[player] = now + GameConfig.CityAttackCooldown
    local fromPosition = armyPosition(state.ArmyLocation); state.ArmyDestination = city.Id; state.ArmyStatus = "Traveling"; sendState(player)
    resultEvent:FireClient(player, {Message = "Your army is marching from " .. state.ArmyLocation .. " to " .. city.Name .. "."})
    task.spawn(runAttackSequence, player, city, state, fromPosition)
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
        if totalSoldiers(state) >= GameConfig.MaxSoldiers then remaining = math.max(remaining, interval) else remaining -= 1; if remaining <= 0 then state.Soldiers[1] += 1; if state.ArmyStatus ~= "Traveling" and state.ArmyStatus ~= "Arriving" and state.ArmyStatus ~= "Fighting" then syncSoldierVisuals(player, state) end; remaining = interval; resultEvent:FireClient(player, {Message = "A Level 1 soldier was generated at your active base."}) end end
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
    if sprintStates[player] then return end
    sprintStates[player] = {Requested = false, LastSignal = 0}
    player.CharacterAdded:Connect(function(character) local humanoid = character:WaitForChild("Humanoid", 5); if humanoid then humanoid.WalkSpeed = GameConfig.DefaultWalkSpeed end end)
end
sprintEvent.OnServerEvent:Connect(function(player, wantsSprint) if typeof(wantsSprint) == "boolean" and sprintStates[player] then sprintStates[player].Requested, sprintStates[player].LastSignal = wantsSprint, os.clock() end end)
RunService.Heartbeat:Connect(function(deltaTime)
    for player, sprint in pairs(sprintStates) do local character = player.Character; local humanoid = character and character:FindFirstChildOfClass("Humanoid"); if humanoid then if sprint.Requested and os.clock() - sprint.LastSignal > 0.6 then sprint.Requested = false end; local target = sprint.Requested and GameConfig.SprintWalkSpeed or GameConfig.DefaultWalkSpeed; humanoid.WalkSpeed += (target - humanoid.WalkSpeed) * math.min(1, deltaTime * 12) end end
end)

for _, city in ipairs(GameConfig.EnemyCities) do local model = world:FindFirstChild(city.Id); local prompt = model and model:FindFirstChild("AttackPrompt", true); if prompt then prompt.Triggered:Connect(function(player) attackCity(player, city) end) end end
local function initializePlayer(player)
    if initializedPlayers[player] then return end
    initializedPlayers[player] = true
    local ok, state = pcall(DataService.load, player)
    if not ok then initializedPlayers[player] = nil; warn("[MergeDominion] Player initialization failed for " .. player.Name .. ": " .. tostring(state)); return end
    state = DataService.get(player)
    if state then for _, city in ipairs(GameConfig.EnemyCities) do if state.Conquered[city.Id] then setCityConquered(city, player) end end; generationTimers[player] = generationInterval(state); syncSoldierVisuals(player, state); task.defer(function() sendState(player) end); task.spawn(runGeneration, player); task.spawn(runCityIncome, player) end
end
Players.PlayerAdded:Connect(setupSprint); Players.PlayerAdded:Connect(initializePlayer)
Players.PlayerRemoving:Connect(function(player) initializedPlayers[player], generationTimers[player], sprintStates[player], cityCooldowns[player] = nil, nil, nil, nil; cleanupSoldierVisuals(player) end)
for _, player in Players:GetPlayers() do setupSprint(player); task.spawn(initializePlayer, player) end
actionEvent.OnServerEvent:Connect(handleAction)
