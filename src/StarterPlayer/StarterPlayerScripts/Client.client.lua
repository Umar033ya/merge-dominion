local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local action, stateEvent, resultEvent, sprintEvent = remotes.Action, remotes.State, remotes.BattleResult, remotes.Sprint
local cities = {{Id = "EmberOutpost", Name = "Ember Outpost", Defenders = "Early • +25/min"}, {Id = "Stonewatch", Name = "Stonewatch", Defenders = "Early • +40/min"}, {Id = "Frostkeep", Name = "Frostkeep", Defenders = "Early • +55/min"}, {Id = "Sunspire", Name = "Sunspire", Defenders = "Middle • +70/min"}, {Id = "NightfallCitadel", Name = "Nightfall Citadel", Defenders = "Middle • +85/min"}, {Id = "Ironvale", Name = "Ironvale", Defenders = "Middle • +105/min"}, {Id = "Moonharbor", Name = "Moonharbor", Defenders = "Middle • +125/min"}, {Id = "Cindercrest", Name = "Cindercrest", Defenders = "Late • +150/min"}, {Id = "VerdantReach", Name = "Verdant Reach", Defenders = "Late • +180/min"}, {Id = "Dragonspire", Name = "Dragonspire", Defenders = "Late • +230/min"}}
local state = {Currency = 0, Soldiers = {}, Conquered = {}, Cities = {}, GenerationInterval = 60, GenerationRemaining = 60, GenerationLevel = 1, SpawnLevel = 1, NextSpawnLevel = 2, NextSpawnLevelCost = 250, NextUpgradeCost = 50, SoldierCount = 0, MaxSoldiers = 20, HighestLevel = 0, TotalIncomePerMinute = 0, ArmyLocation = "MainBase", ArmyStatus = "Idle"}
for level = 1, 20 do state.Soldiers[level] = 0 end
local function normalizeState(nextState)
    if type(nextState) ~= "table" then return state end
    nextState.Soldiers = type(nextState.Soldiers) == "table" and nextState.Soldiers or {}
    for level = 1, 20 do nextState.Soldiers[level] = tonumber(nextState.Soldiers[level]) or 0 end
    nextState.Cities = type(nextState.Cities) == "table" and nextState.Cities or {}
    nextState.Conquered = type(nextState.Conquered) == "table" and nextState.Conquered or {}
    nextState.Currency = tonumber(nextState.Currency) or 0; nextState.SoldierCount = tonumber(nextState.SoldierCount) or 0; nextState.MaxSoldiers = tonumber(nextState.MaxSoldiers) or 20
    nextState.GenerationInterval = tonumber(nextState.GenerationInterval) or 60; nextState.GenerationRemaining = tonumber(nextState.GenerationRemaining) or nextState.GenerationInterval; nextState.SpawnLevel = tonumber(nextState.SpawnLevel) or 1
    return nextState
end

local gui = Instance.new("ScreenGui"); gui.Name, gui.ResetOnSpawn, gui.Parent = "MergeDominionUI", false, player:WaitForChild("PlayerGui")
local function panel(parent, size, position, color) local f = Instance.new("Frame"); f.Size, f.Position, f.BackgroundColor3, f.BorderSizePixel, f.Parent = size, position, color, 0, parent; local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 12); c.Parent = f; return f end
local function text(parent, value, size, position, font, color) local t = Instance.new("TextLabel"); t.BackgroundTransparency, t.Size, t.Position, t.Text, t.Font, t.TextColor3, t.TextSize, t.TextXAlignment, t.Parent = 1, size, position, value, font or Enum.Font.Gotham, color or Color3.new(1,1,1), 16, Enum.TextXAlignment.Left, parent; return t end
local function button(parent, value, size, position, color) local b = Instance.new("TextButton"); b.Size, b.Position, b.Text, b.Font, b.TextColor3, b.TextSize, b.BackgroundColor3, b.AutoButtonColor, b.Parent = size, position, value, Enum.Font.GothamBold, Color3.new(1,1,1), 14, color, true, parent; local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = b; return b end
local function formatTime(seconds) seconds = math.max(0, math.floor(tonumber(seconds) or 0)); return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60) end

local menuButton = button(gui, "MENU", UDim2.fromOffset(112, 42), UDim2.fromOffset(24, 24), Color3.fromRGB(43, 143, 207))
local root = panel(gui, UDim2.fromOffset(450, 800), UDim2.fromOffset(24, 76), Color3.fromRGB(17, 25, 36)); root.Visible = false
local menuOpen = false
local function setMenuOpen(open) menuOpen = open; root.Visible = open; menuButton.Text = open and "CLOSE MENU" or "MENU" end
menuButton.MouseButton1Click:Connect(function() setMenuOpen(not menuOpen) end)
text(root, "MERGE DOMINION", UDim2.fromOffset(410, 36), UDim2.fromOffset(20, 16), Enum.Font.GothamBlack, Color3.fromRGB(121, 210, 255)).TextSize = 25
text(root, "Travel to a city and press E to attack", UDim2.fromOffset(410, 24), UDim2.fromOffset(20, 50), Enum.Font.Gotham, Color3.fromRGB(170, 185, 201)).TextSize = 14
local currency = text(root, "COINS  0", UDim2.fromOffset(410, 32), UDim2.fromOffset(20, 84), Enum.Font.GothamBold, Color3.fromRGB(255, 213, 104)); currency.TextSize = 21
local generation = text(root, "", UDim2.fromOffset(410, 38), UDim2.fromOffset(20, 119), Enum.Font.GothamBold, Color3.fromRGB(203, 255, 214)); generation.TextSize = 14
local upgrade = button(root, "", UDim2.fromOffset(410, 34), UDim2.fromOffset(20, 158), Color3.fromRGB(55, 145, 105)); upgrade.MouseButton1Click:Connect(function() action:FireServer("UpgradeGeneration") end)
local spawnUpgrade = button(root, "", UDim2.fromOffset(410, 34), UDim2.fromOffset(20, 196), Color3.fromRGB(77, 113, 174)); spawnUpgrade.MouseButton1Click:Connect(function() action:FireServer("UpgradeSpawnLevel") end)
local army = text(root, "", UDim2.fromOffset(410, 54), UDim2.fromOffset(20, 240), Enum.Font.GothamBold, Color3.fromRGB(235, 240, 247)); army.TextSize = 15; army.TextYAlignment = Enum.TextYAlignment.Top
text(root, "ENEMY CITIES • WALK THERE AND PRESS E", UDim2.fromOffset(410, 24), UDim2.fromOffset(20, 309), Enum.Font.GothamBold, Color3.fromRGB(170, 185, 201)).TextSize = 13
local cityList = Instance.new("ScrollingFrame"); cityList.Size, cityList.Position, cityList.BackgroundTransparency, cityList.BorderSizePixel, cityList.ScrollBarThickness, cityList.CanvasSize, cityList.Parent = UDim2.fromOffset(410, 300), UDim2.fromOffset(20, 336), 1, 0, 6, UDim2.fromOffset(0, #cities * 57), root
local cityRows = {}
for i, city in ipairs(cities) do
    local row = panel(cityList, UDim2.fromOffset(390, 50), UDim2.fromOffset(0, (i - 1) * 57), Color3.fromRGB(28, 39, 54))
    text(row, i .. "  " .. city.Name, UDim2.fromOffset(250, 24), UDim2.fromOffset(12, 5), Enum.Font.GothamBold, Color3.new(1,1,1)).TextSize = 15
    local status = text(row, city.Defenders, UDim2.fromOffset(370, 19), UDim2.fromOffset(12, 28), Enum.Font.Gotham, Color3.fromRGB(180, 194, 210)); status.TextSize = 12
    cityRows[city.Id] = status
end
local result = text(root, "Explore the roads to find the city attack prompts.", UDim2.fromOffset(410, 42), UDim2.fromOffset(20, 650), Enum.Font.GothamBold, Color3.fromRGB(255, 213, 104)); result.TextSize = 13; result.TextWrapped = true
local income = text(root, "", UDim2.fromOffset(410, 40), UDim2.fromOffset(20, 720), Enum.Font.GothamBold, Color3.fromRGB(112, 238, 163)); income.TextSize = 14

local function inventorySummary()
    local parts = {}
    for level = 1, 20 do if (state.Soldiers[level] or 0) > 0 then table.insert(parts, "L" .. level .. " × " .. state.Soldiers[level]) end end
    return #parts > 0 and table.concat(parts, "   ") or "No soldiers yet"
end
local function render()
    currency.Text = "COINS  " .. state.Currency
    generation.Text = string.format("GENERATION %ds • COUNTDOWN %s\nSPAWN LEVEL %d • CAPACITY %d / %d%s", state.GenerationInterval, state.SoldierCount >= state.MaxSoldiers and "ARMY FULL" or formatTime(state.GenerationRemaining), state.SpawnLevel or 1, state.SoldierCount, state.MaxSoldiers, state.SoldierCount >= state.MaxSoldiers and " • ARMY FULL" or "")
    local destination = state.ArmyDestination and (" → " .. state.ArmyDestination .. " (" .. (state.ArmyDistance or 0) .. " studs)") or ""
    army.Text = "ACTIVE ARMY  " .. inventorySummary() .. "\nHIGHEST LEVEL  " .. (state.HighestLevel or 0) .. "  •  TOTAL  " .. state.SoldierCount .. "\n" .. string.upper(state.ArmyStatus or "IDLE") .. " FROM " .. (state.ArmyLocation or "MainBase") .. destination
    if state.NextUpgradeCost then upgrade.Text = "UPGRADE SPEED • " .. state.NextUpgradeCost .. " COINS"; upgrade.Active = state.Currency >= state.NextUpgradeCost; upgrade.AutoButtonColor = upgrade.Active; upgrade.BackgroundColor3 = upgrade.Active and Color3.fromRGB(55, 145, 105) or Color3.fromRGB(68, 82, 86) else upgrade.Text = "GENERATION SPEED MAXED"; upgrade.Active = false; upgrade.AutoButtonColor = false; upgrade.BackgroundColor3 = Color3.fromRGB(68, 82, 86) end
    if state.NextSpawnLevel and state.NextSpawnLevelCost then spawnUpgrade.Text = "UPGRADE TO LEVEL " .. state.NextSpawnLevel .. " • " .. state.NextSpawnLevelCost .. " COINS"; spawnUpgrade.Active = state.Currency >= state.NextSpawnLevelCost; spawnUpgrade.AutoButtonColor = spawnUpgrade.Active; spawnUpgrade.BackgroundColor3 = spawnUpgrade.Active and Color3.fromRGB(77, 113, 174) or Color3.fromRGB(68, 82, 86) else spawnUpgrade.Text = "SPAWN LEVEL MAXED"; spawnUpgrade.Active = false; spawnUpgrade.AutoButtonColor = false; spawnUpgrade.BackgroundColor3 = Color3.fromRGB(68, 82, 86) end
    for _, city in ipairs(cities) do local cityState = state.Cities[city.Id] or {}; local distance = cityState.Distance and (" • " .. cityState.Distance .. " studs") or ""; cityRows[city.Id].Text = cityState.Conquered and ((cityState.Stationed and "STATIONED " .. (cityState.StationedCount or 0) .. " • " or "CONTROLLED • ") .. "+" .. cityState.IncomePerMinute .. "/min" .. distance) or (cityState.Target and "TARGET • " or "") .. city.Defenders .. distance .. " • " .. (cityState.Defenders or "visible enemy army") end
    income.Text = "PASSIVE CITY INCOME  +" .. (state.TotalIncomePerMinute or 0) .. " COINS / MINUTE"
end

local sprintHeld = false
local function setSprint(held) if sprintHeld == held then return end; sprintHeld = held; sprintEvent:FireServer(held) end
local function sprintAction(_, inputState) if inputState == Enum.UserInputState.Begin then setSprint(true) elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then setSprint(false) end; return Enum.ContextActionResult.Pass end
ContextActionService:BindAction("MergeDominionSprint", sprintAction, true, Enum.KeyCode.LeftShift); ContextActionService:SetTitle("MergeDominionSprint", "SPRINT")
task.spawn(function() while player.Parent do task.wait(0.2); if sprintHeld then sprintEvent:FireServer(true) end end end)
stateEvent.OnClientEvent:Connect(function(nextState) state = normalizeState(nextState); render() end)
resultEvent.OnClientEvent:Connect(function(payload) payload = type(payload) == "table" and payload or {}; result.Text = payload.Message or ""; result.TextColor3 = payload.Won and Color3.fromRGB(112, 238, 163) or Color3.fromRGB(255, 213, 104); render() end)
render(); action:FireServer("RequestState")
