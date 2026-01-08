local script_url = "https://raw.githubusercontent.com/brainburn88/1/refs/heads/main/4.lua"

local teleportFunc = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport)
if teleportFunc then
    teleportFunc([[
        if not game:IsLoaded() then game.Loaded:Wait() end
        repeat task.wait() until game.Players.LocalPlayer
        task.wait(2)
        loadstring(game:HttpGet("]]..script_url..[["))()
    ]])
end

-- ==========================================
-- АВТО-РЕКОННЕКТ (ПРИ КИКЕ ИЛИ ВЫЛЕТЕ)
-- ==========================================
task.spawn(function()
    local TeleportService = game:GetService("TeleportService")
    local GuiService = game:GetService("GuiService")
    
    GuiService.ErrorMessageChanged:Connect(function()
        task.wait(1) 
        TeleportService:Teleport(game.PlaceId, game.Players.LocalPlayer)
    end)
    
    while task.wait(5) do
        local coreGui = game:GetService("CoreGui")
        if coreGui:FindFirstChild("RobloxPromptGui") then
            local prompt = coreGui.RobloxPromptGui:FindFirstChild("promptOverlay")
            if prompt and prompt:FindFirstChild("ErrorPrompt") then
                TeleportService:Teleport(game.PlaceId, game.Players.LocalPlayer)
            end
        end
    end
end)

-- ==========================================
-- ОСНОВНАЯ ЛОГИКА ФАРМА
-- ==========================================
if _G.MM2FarmLoaded then 
    _G.MM2FarmLoaded = false 
    task.wait(0.5)
end
_G.MM2FarmLoaded = true

-- >>>>>> УВЕДОМЛЕНИЕ О СТАРТЕ <<<<<<
task.spawn(function()
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "MM2 Auto Farm | Christmas 2025",
            Text = "Start",
            Duration = 5, 
        })
    end)
end)
-- >>>>>>>>>>>>>>>><<<<<<<<<<<<<<<<<<

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

local Settings = {
    Speed = 25.5,
    MaxDist = 150,
    Resetting = false
}

-- Фикс камеры
Player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam

-- Ноклип
RunService.Stepped:Connect(function()
    if not _G.MM2FarmLoaded then return end
    if Player.Character then
        for _, part in ipairs(Player.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

-- Поиск монет
local function getBestRandomTarget()
    local container = nil
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "CoinContainer" then container = obj break end
    end
    if not container then return nil end
    
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local coinsInRange = {}
    for _, coin in pairs(container:GetChildren()) do
        if coin:IsA("BasePart") and coin:FindFirstChild("TouchInterest") then
            local dist = (hrp.Position - coin.Position).Magnitude
            if dist <= Settings.MaxDist then
                table.insert(coinsInRange, {obj = coin, dist = dist})
            end
        end
    end

    if #coinsInRange == 0 then return nil end
    table.sort(coinsInRange, function(a, b) return a.dist < b.dist end)
    local count = math.min(3, #coinsInRange)
    return coinsInRange[math.random(1, count)].obj
end

-- Цикл Твина
task.spawn(function()
    local currentRotation = nil
    while true do
        if not _G.MM2FarmLoaded then break end
        
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")

        if Settings.Resetting or not hrp or not hum or hum.Health <= 0 then
            currentRotation = nil
            task.wait(1)
        else
            if not currentRotation then currentRotation = hrp.CFrame.Rotation end
            local target = getBestRandomTarget()
            
            if target then
                local dist = (target.Position - hrp.Position).Magnitude
                local tweenTime = dist / Settings.Speed
                local tween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {
                    CFrame = CFrame.new(target.Position) * currentRotation
                })
                tween:Play()
                
                local completed = false
                local conn = tween.Completed:Connect(function() completed = true end)
                
                while not completed and _G.MM2FarmLoaded and not Settings.Resetting do
                    if not target or not target.Parent or not target:FindFirstChild("TouchInterest") then
                        tween:Cancel()
                        break
                    end
                    task.wait()
                end
                if conn then conn:Disconnect() end

                if target and target.Parent and target:FindFirstChild("TouchInterest") and not Settings.Resetting then
                    local waitStart = tick()
                    repeat 
                        if hrp and hrp.Parent then hrp.CFrame = CFrame.new(target.Position) * currentRotation end
                        task.wait()
                    until not target or not target.Parent or not target:FindFirstChild("TouchInterest") or (tick() - waitStart > 2) or Settings.Resetting
                end
            else
                task.wait(0.5)
            end
        end
        task.wait()
    end
end)

-- Авто-ресет
task.spawn(function()
    local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 30)
    if remotes then
        local coinEvent = remotes:WaitForChild("Gameplay", 10)
        if coinEvent then 
            coinEvent = coinEvent:WaitForChild("CoinCollected", 10)
            if coinEvent then
                coinEvent.OnClientEvent:Connect(function(_, cur, max)
                    if tonumber(cur) >= tonumber(max) and Player.Character and not Settings.Resetting then
                        Settings.Resetting = true
                        Player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
                        Player.Character:BreakJoints()
                        task.wait(3)
                        Player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
                        Settings.Resetting = false
                    end
                end)
            end
        end
    end
end)


local vu = game:GetService("VirtualUser")
Player.Idled:Connect(function()
    vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)
