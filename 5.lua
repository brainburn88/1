local script_url = "https://raw.githubusercontent.com/brainburn88/1/refs/heads/main/5.lua"

local teleportFunc = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport)
if teleportFunc then
    teleportFunc([[
        if not game:IsLoaded() then game.Loaded:Wait() end
        repeat task.wait() until game.Players.LocalPlayer
        task.wait(2)
        loadstring(game:HttpGet("]]..script_url..[["))()
    ]])
end

-- АВТО-РЕКОННЕКТ
task.spawn(function()
    local TeleportService = game:GetService("TeleportService")
    local GuiService = game:GetService("GuiService")
    
    GuiService.ErrorMessageChanged:Connect(function()
        task.wait(1) 
        TeleportService:Teleport(game.PlaceId, game.Players.LocalPlayer)
    end)
    
    while task.wait(5) do
        local coreGui = game:GetService("CoreGui")
        local prompt = coreGui:FindFirstChild("RobloxPromptGui") and coreGui.RobloxPromptGui:FindFirstChild("promptOverlay")
        if prompt and prompt:FindFirstChild("ErrorPrompt") then
            TeleportService:Teleport(game.PlaceId, game.Players.LocalPlayer)
        end
    end
end)

if _G.MM2FarmLoaded then 
    _G.MM2FarmLoaded = false 
    task.wait(0.5)
end
_G.MM2FarmLoaded = true

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

local Settings = {
    Speed = 25,
    MaxDist = 150,
    Resetting = false
}

-- Фикс камеры
Player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam

-- Ноклип (оптимизированный)
local noclipConn
noclipConn = RunService.Stepped:Connect(function()
    if not _G.MM2FarmLoaded then 
        if noclipConn then noclipConn:Disconnect() end
        return 
    end
    if Player.Character then
        for _, part in ipairs(Player.Character:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

-- УЛУЧШЕННЫЙ ПОИСК МОНЕТ (Без GetDescendants)
local function getBestRandomTarget()
    -- Ищем контейнер напрямую в workspace (рекурсивно, но эффективно)
    local container = workspace:FindFirstChild("CoinContainer", true)
    
    if not container or #container:GetChildren() == 0 then return nil end
    
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local coinsInRange = {}
    local children = container:GetChildren()
    
    for i = 1, #children do
        local coin = children[i]
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

-- ЦИКЛ ФАРМА (Без утечек)
task.spawn(function()
    local currentRotation = nil
    while _G.MM2FarmLoaded do
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
                
                local completed = false
                local conn -- Резервируем переменную для события
                
                conn = tween.Completed:Connect(function()
                    completed = true
                    if conn then conn:Disconnect() end -- Сразу отключаем
                end)
                
                tween:Play()
                
                -- Безопасное ожидание завершения
                while not completed and _G.MM2FarmLoaded and not Settings.Resetting do
                    if not target or not target.Parent or not target:FindFirstChild("TouchInterest") then
                        tween:Cancel()
                        break
                    end
                    task.wait()
                end
                
                if conn then conn:Disconnect() end
                tween:Destroy() -- Очищаем память
            else
                task.wait(1) -- Ждем появления монет
            end
        end
        task.wait()
    end
end)

-- Авто-ресет и сбор статы
task.spawn(function()
    local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 30)
    local gameplay = remotes and remotes:WaitForChild("Gameplay", 10)
    local coinEvent = gameplay and gameplay:WaitForChild("CoinCollected", 10)
    
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
end)

-- Анти-АФК
local vu = game:GetService("VirtualUser")
Player.Idled:Connect(function()
    vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)
