local script_url = "https://raw.githubusercontent.com/brainburn88/1/refs/heads/main/5.lua"

-- Безопасный телепорт
local teleportFunc = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport)
if teleportFunc then
    teleportFunc([[
        if not game:IsLoaded() then game.Loaded:Wait() end
        repeat task.wait() until game.Players.LocalPlayer
        task.wait(2)
        loadstring(game:HttpGet("]]..script_url..[["))()
    ]])
end

-- Очистка старых сессий
if _G.MM2FarmLoaded then 
    _G.MM2FarmLoaded = false 
    task.wait(0.5) 
end
_G.MM2FarmLoaded = true

-- Кэширование сервисов (главная оптимизация)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local VirtualUser = game:GetService("VirtualUser")

local Player = Players.LocalPlayer

local Settings = {
    Speed = 25,
    MaxDist = 160,
    Resetting = false,
    CoinContainer = nil,  -- Кэш контейнера
    LastContainerCheck = 0
}

Player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam

-- Таблица для хранения соединений (для очистки)
local Connections = {}

-- Ноклип (оптимизированный)
Connections.Noclip = RunService.Stepped:Connect(function()
    if not _G.MM2FarmLoaded then 
        for _, conn in pairs(Connections) do
            if conn then pcall(function() conn:Disconnect() end) end
        end
        return 
    end
    
    local char = Player.Character
    if not char then return end
    
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.CanCollide then 
            part.CanCollide = false 
        end
    end
end)

-- Кэшированный поиск контейнера (проверка раз в 2 секунды)
local function getCoinContainer()
    local now = tick()
    if Settings.CoinContainer and Settings.CoinContainer.Parent and (now - Settings.LastContainerCheck) < 2 then
        return Settings.CoinContainer
    end
    
    Settings.LastContainerCheck = now
    Settings.CoinContainer = workspace:FindFirstChild("CoinContainer", true)
    return Settings.CoinContainer
end

-- Оптимизированный поиск монет
local function getBestRandomTarget()
    local container = getCoinContainer()
    if not container then return nil end
    
    local char = Player.Character
    if not char then return nil end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local hrpPos = hrp.Position
    local maxDistSq = Settings.MaxDist * Settings.MaxDist -- Избегаем sqrt
    local coinsInRange = {}
    local count = 0

    for _, coin in ipairs(container:GetChildren()) do
        if coin:IsA("BasePart") and coin:FindFirstChild("TouchInterest") then
            local distSq = (hrpPos - coin.Position).Magnitude -- Используем квадрат расстояния
            if distSq <= maxDistSq then
                count += 1
                coinsInRange[count] = {obj = coin, dist = distSq}
            end
        end
    end

    if count == 0 then return nil end
    
    -- Быстрая сортировка только если нужно
    if count > 1 then
        table.sort(coinsInRange, function(a, b) return a.dist < b.dist end)
    end
    
    return coinsInRange[math.random(1, math.min(3, count))].obj
end

-- ОСНОВНОЙ ЦИКЛ ФАРМА (оптимизированный)
task.spawn(function()
    local currentRotation = nil
    local activeTween = nil
    
    while _G.MM2FarmLoaded do
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")

        if Settings.Resetting or not hrp or not hum or hum.Health <= 0 then
            currentRotation = nil
            if activeTween then 
                activeTween:Cancel() 
                activeTween = nil 
            end
            task.wait(1)
            continue
        end
        
        currentRotation = currentRotation or hrp.CFrame.Rotation
        local target = getBestRandomTarget()
        
        if not target then
            currentRotation = nil
            task.wait(0.5) -- Уменьшено время ожидания
            continue
        end
        
        local dist = (target.Position - hrp.Position).Magnitude
        local tweenTime = dist / Settings.Speed
        
        activeTween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {
            CFrame = CFrame.new(target.Position) * currentRotation
        })
        
        activeTween:Play()
        
        -- Упрощенное ожидание
        local startTime = tick()
        local maxWait = tweenTime + 0.3
        
        repeat
            task.wait(0.05) -- Фиксированный интервал
        until not _G.MM2FarmLoaded 
            or Settings.Resetting 
            or not target.Parent 
            or not target:FindFirstChild("TouchInterest")
            or (tick() - startTime) > maxWait
        
        if activeTween then
            activeTween:Cancel()
            activeTween = nil
        end
        
        task.wait(0.03) -- Минимальная пауза между итерациями
    end
end)

-- Авто-ресет (оптимизированный)
task.spawn(function()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
    if not remotes then return end
    
    local gameplay = remotes:WaitForChild("Gameplay", 10)
    if not gameplay then return end
    
    local coinEvent = gameplay:WaitForChild("CoinCollected", 10)
    if not coinEvent then return end
    
    if Connections.Coin then Connections.Coin:Disconnect() end
    
    Connections.Coin = coinEvent.OnClientEvent:Connect(function(_, cur, max)
        local current, maximum = tonumber(cur), tonumber(max)
        if current and maximum and current >= maximum and Player.Character and not Settings.Resetting then
            Settings.Resetting = true
            pcall(function() Player.Character:BreakJoints() end)
            task.wait(3)
            Settings.Resetting = false
        end
    end)
end)

-- Анти-АФК и Реконнект (объединено)
task.spawn(function()
    Connections.Error = GuiService.ErrorMessageChanged:Connect(function()
        task.wait(1) 
        pcall(function() TeleportService:Teleport(game.PlaceId, Player) end)
    end)
    
    Connections.Idle = Player.Idled:Connect(function()
        local cam = workspace.CurrentCamera
        if cam then
            VirtualUser:Button2Down(Vector2.zero, cam.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.zero, cam.CFrame)
        end
    end)
end)
