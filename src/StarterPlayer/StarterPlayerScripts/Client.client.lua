local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local action, stateEvent, resultEvent, sprintEvent = remotes.Action, remotes.State, remotes.BattleResult, remotes.Sprint
local bases = {{Name = "Ember Outpost", Defenders = "2 × Level 1", Color = Color3.fromRGB(207, 79, 67)}, {Name = "Stonewatch", Defenders = "3 × Level 2", Color = Color3.fromRGB(220, 122, 67)}, {Name = "Frostkeep", Defenders = "5 × Level 2", Color = Color3.fromRGB(126, 130, 219)}}
local state = {
    Currency = 0,
    Soldiers = {[1] = 0, [2] = 0, [3] = 0},
    Conquered = {},
    GenerationInterval = 60,
    GenerationRemaining = 60,
    NextUpgradeCost = 50,
    SoldierCount = 0,
    MaxSoldiers = 20,
}

local gui = Instance.new("ScreenGui"); gui.Name, gui.ResetOnSpawn, gui.Parent = "MergeDominionUI", false, player:WaitForChild("PlayerGui")
local function panel(parent, size, position, color)
    local f = Instance.new("Frame"); f.Size, f.Position, f.BackgroundColor3, f.BorderSizePixel, f.Parent = size, position, color, 0, parent
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 12); corner.Parent = f
    return f
end
local function text(parent, value, size, position, font, color)
    local t = Instance.new("TextLabel"); t.BackgroundTransparency, t.Size, t.Position, t.Text, t.Font, t.TextColor3, t.TextSize, t.TextXAlignment, t.Parent = 1, size, position, value, font or Enum.Font.Gotham, color or Color3.new(1,1,1), 16, Enum.TextXAlignment.Left, parent
    return t
end
local function button(parent, value, size, position, color)
    local b = Instance.new("TextButton"); b.Size, b.Position, b.Text, b.Font, b.TextColor3, b.TextSize, b.BackgroundColor3, b.AutoButtonColor, b.Parent = size, position, value, Enum.Font.GothamBold, Color3.new(1,1,1), 14, color, true, parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = b
    return b
end
local function formatTime(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

local menuButton = button(gui, "MENU", UDim2.fromOffset(112, 42), UDim2.fromOffset(24, 24), Color3.fromRGB(43, 143, 207))
local root = panel(gui, UDim2.fromOffset(430, 600), UDim2.fromOffset(24, 76), Color3.fromRGB(17, 25, 36))
root.Visible = false
local menuOpen = false
local function setMenuOpen(open)
    menuOpen = open
    root.Visible = open
    menuButton.Text = open and "CLOSE MENU" or "MENU"
end
menuButton.MouseButton1Click:Connect(function() setMenuOpen(not menuOpen) end)

text(root, "MERGE DOMINION", UDim2.fromOffset(390, 36), UDim2.fromOffset(20, 16), Enum.Font.GothamBlack, Color3.fromRGB(121, 210, 255)).TextSize = 25
text(root, "Main Base → Soldier Yard → Frontier", UDim2.fromOffset(390, 24), UDim2.fromOffset(20, 50), Enum.Font.Gotham, Color3.fromRGB(170, 185, 201)).TextSize = 14
local currency = text(root, "COINS  0", UDim2.fromOffset(390, 32), UDim2.fromOffset(20, 84), Enum.Font.GothamBold, Color3.fromRGB(255, 213, 104)); currency.TextSize = 21
local generation = text(root, "", UDim2.fromOffset(390, 38), UDim2.fromOffset(20, 119), Enum.Font.GothamBold, Color3.fromRGB(203, 255, 214)); generation.TextSize = 14; generation.TextYAlignment = Enum.TextYAlignment.Center
local upgrade = button(root, "", UDim2.fromOffset(380, 34), UDim2.fromOffset(20, 158), Color3.fromRGB(55, 145, 105)); upgrade.MouseButton1Click:Connect(function() action:FireServer("UpgradeGeneration") end)
text(root, "YOUR ARMY", UDim2.fromOffset(380, 22), UDim2.fromOffset(20, 204), Enum.Font.GothamBold, Color3.fromRGB(170, 185, 201)).TextSize = 13
local inventory = text(root, "", UDim2.fromOffset(380, 60), UDim2.fromOffset(20, 226), Enum.Font.GothamBold, Color3.fromRGB(235, 240, 247)); inventory.TextSize = 18; inventory.TextYAlignment = Enum.TextYAlignment.Top
text(root, "Walk to a soldier and press E to select it for merging.", UDim2.fromOffset(380, 30), UDim2.fromOffset(20, 293), Enum.Font.GothamMedium, Color3.fromRGB(203, 214, 225)).TextSize = 13
text(root, "ENEMY FRONTIER", UDim2.fromOffset(380, 22), UDim2.fromOffset(20, 345), Enum.Font.GothamBold, Color3.fromRGB(170, 185, 201)).TextSize = 13
local list = {}
for i, base in ipairs(bases) do
    local row = panel(root, UDim2.fromOffset(380, 50), UDim2.fromOffset(20, 370 + (i - 1) * 57), Color3.fromRGB(28, 39, 54))
    text(row, i .. "  " .. base.Name, UDim2.fromOffset(230, 24), UDim2.fromOffset(12, 5), Enum.Font.GothamBold, Color3.new(1,1,1)).TextSize = 15
    local status = text(row, base.Defenders, UDim2.fromOffset(230, 19), UDim2.fromOffset(12, 28), Enum.Font.Gotham, Color3.fromRGB(180, 194, 210)); status.TextSize = 12
    local attack = button(row, "ATTACK", UDim2.fromOffset(100, 32), UDim2.fromOffset(267, 9), base.Color); attack.MouseButton1Click:Connect(function() action:FireServer("Attack", i) end)
    list[i] = {Status = status, Button = attack}
end
local result = text(root, "Select a frontier base to attack.", UDim2.fromOffset(380, 28), UDim2.fromOffset(20, 556), Enum.Font.GothamBold, Color3.fromRGB(255, 213, 104)); result.TextSize = 13

local function render()
    currency.Text = "COINS  " .. state.Currency
    generation.Text = string.format("GENERATION  %ds  •  NEXT SOLDIER IN %s\nCAPACITY  %d / %d", state.GenerationInterval, state.SoldierCount >= state.MaxSoldiers and "READY / FULL" or formatTime(state.GenerationRemaining), state.SoldierCount, state.MaxSoldiers)
    inventory.Text = string.format("Level 1   %d\nLevel 2   %d\nLevel 3   %d", state.Soldiers[1], state.Soldiers[2], state.Soldiers[3])
    if state.NextUpgradeCost then
        upgrade.Text = "UPGRADE SPEED  •  " .. state.NextUpgradeCost .. " COINS"
        upgrade.Active = state.Currency >= state.NextUpgradeCost
        upgrade.AutoButtonColor = upgrade.Active
        upgrade.BackgroundColor3 = upgrade.Active and Color3.fromRGB(55, 145, 105) or Color3.fromRGB(68, 82, 86)
    else
        upgrade.Text = "GENERATION SPEED MAXED"
        upgrade.Active = false
        upgrade.AutoButtonColor = false
        upgrade.BackgroundColor3 = Color3.fromRGB(68, 82, 86)
    end
    for i, base in ipairs(bases) do
        local id = ({"EmberOutpost", "Stonewatch", "Frostkeep"})[i]
        local conquered = state.Conquered[id] == true
        list[i].Status.Text = conquered and "CONQUERED • TERRITORY SECURED" or base.Defenders
        list[i].Status.TextColor3 = conquered and Color3.fromRGB(112, 238, 163) or Color3.fromRGB(180, 194, 210)
        list[i].Button.Text = conquered and "SECURED" or "ATTACK"
        list[i].Button.Active = not conquered
        list[i].Button.AutoButtonColor = not conquered
    end
end

local sprintHeld = false
local function setSprint(held)
    if sprintHeld == held then return end
    sprintHeld = held
    sprintEvent:FireServer(held)
end
local function sprintAction(_, inputState)
    if inputState == Enum.UserInputState.Begin then
        setSprint(true)
    elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
        setSprint(false)
    end
    return Enum.ContextActionResult.Pass
end
ContextActionService:BindAction("MergeDominionSprint", sprintAction, true, Enum.KeyCode.LeftShift)
ContextActionService:SetTitle("MergeDominionSprint", "SPRINT")
task.spawn(function()
    while player.Parent do
        task.wait(0.2)
        if sprintHeld then sprintEvent:FireServer(true) end
    end
end)

stateEvent.OnClientEvent:Connect(function(nextState)
    state = nextState
    render()
end)
resultEvent.OnClientEvent:Connect(function(payload)
    result.Text = payload.Message or ""
    result.TextColor3 = payload.Won and Color3.fromRGB(112, 238, 163) or Color3.fromRGB(255, 213, 104)
    render()
end)
render()
action:FireServer("RequestState")
