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

-- Полная очистка предыдущей сессии
local function cleanup()
    _G.MM2FarmLoaded = false
    
    -- Очистка старых соединений из _G
    if _G.MM2Connections then
        for name, conn in pairs(_G.MM2Connections) do
            if conn and typeof(conn) == "RBXScriptConnection" then
                pcall(function() conn:Disconnect() end)
            end
        end
        table.clear(_G.MM2Connections)
    end
    
    if _G.CoinConn then
        pcall(function() _G.CoinConn:Disconnect() end)
        _G.CoinConn = nil
    end
    
    -- Очистка кэшей
    if _G.MM2Settings then
        _G.MM2Settings.CoinContainer = nil
        table.clear(_G.MM2Settings)
    end
end

if _G.MM2FarmLoaded then 
    cleanup()
    task.wait(0.5) 
end

_G.MM2FarmLoaded = true

-- Кэширование сервисов
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local VirtualUser = game:GetService("VirtualUser")

local Player = Players.LocalPlayer

-- Глобальные настройки для доступа при очистке
_G.MM2Settings = {
    Speed = 25,
    MaxDist = 160,
    MaxDistSq = 160 * 160, -- Предрасчет
    Resetting = false,
    CoinContainer = nil,
    LastContainerCheck = 0
}
local Settings = _G.MM2Settings

-- Глобальная таблица соединений
_G.MM2Connections = {}
local Connections = _G.MM2Connections

-- Переиспользуемая таблица для монет (избегаем создания новой каждый кадр)
local coinBuffer = {}
local coinBufferSize = 0

Player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam

-- Безопасное отключение соединения
local function safeDisconnect(name)
    local conn = Connections[name]
    if conn and typeof(conn) == "RBXScriptConnection" then
        pcall(function() conn:Disconnect() end)
        Connections[name] = nil
    end
end

-- Полная очистка при выгрузке
local function fullCleanup()
    _G.MM2FarmLoaded = false
    
    for name in pairs(Connections) do
        safeDisconnect(name)
    end
    
    Settings.CoinContainer = nil
    table.clear(coinBuffer)
    coinBufferSize = 0
end

-- Ноклип
Connections.Noclip = RunService.Stepped:Connect(function()
    if not _G.MM2FarmLoaded then 
        fullCleanup()
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

-- Кэшированный поиск контейнера
local function getCoinContainer()
    local now = tick()
    
    -- Проверяем валидность кэша
    if Settings.CoinContainer then
        if not Settings.CoinContainer.Parent then
            Settings.CoinContainer = nil -- Очищаем невалидную ссылку
        elseif (now - Settings.LastContainerCheck) < 2 then
            return Settings.CoinContainer
        end
    end
    
    Settings.LastContainerCheck = now
    Settings.CoinContainer = workspace:FindFirstChild("CoinContainer", true)
    return Settings.CoinContainer
end

-- Оптимизированный поиск монет с переиспользованием буфера
local function getBestRandomTarget()
    local container = getCoinContainer()
    if not container then return nil end
    
    local char = Player.Character
    if not char then return nil end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local hrpPos = hrp.Position
    local maxDistSq = Settings.MaxDistSq
    
    -- Очищаем буфер (переиспользуем таблицу)
    coinBufferSize = 0

    for _, coin in ipairs(container:GetChildren()) do
        if coin:IsA("BasePart") then
            local touch = coin:FindFirstChild("TouchInterest")
            if touch then
                local delta = hrpPos - coin.Position
                local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
                
                if distSq <= maxDistSq then
                    coinBufferSize += 1
                    
                    -- Переиспользуем существующие записи или создаем новые
                    if coinBuffer[coinBufferSize] then
                        coinBuffer[coinBufferSize].obj = coin
                        coinBuffer[coinBufferSize].dist = distSq
                    else
                        coinBuffer[coinBufferSize] = {obj = coin, dist = distSq}
                    end
                end
            end
        end
    end

    if coinBufferSize == 0 then return nil end
    
    if coinBufferSize > 1 then
        -- Сортируем только используемую часть
        table.sort(coinBuffer, function(a, b) 
            if not a or not b then return false end
            return a.dist < b.dist 
        end)
    end
    
    local selected = coinBuffer[math.random(1, math.min(3, coinBufferSize))]
    return selected and selected.obj
end

-- ОСНОВНОЙ ЦИКЛ ФАРМА
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
                pcall(function() 
                    activeTween:Cancel() 
                    activeTween:Destroy() 
                end)
                activeTween = nil 
            end
            task.wait(1)
            continue
        end
        
        currentRotation = currentRotation or hrp.CFrame.Rotation
        local target = getBestRandomTarget()
        
        if not target then
            currentRotation = nil
            task.wait(0.5)
            continue
        end
        
        local targetPos = target.Position
        local dist = (targetPos - hrp.Position).Magnitude
        local tweenTime = dist / Settings.Speed
        
        -- Уничтожаем предыдущий tween если есть
        if activeTween then
            pcall(function() 
                activeTween:Cancel()
                activeTween:Destroy() 
            end)
        end
        
        activeTween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {
            CFrame = CFrame.new(targetPos) * currentRotation
        })
        
        activeTween:Play()
        
        local startTime = tick()
        local maxWait = tweenTime + 0.3
        
        repeat
            task.wait(0.05)
        until not _G.MM2FarmLoaded 
            or Settings.Resetting 
            or not target.Parent 
            or not target:FindFirstChild("TouchInterest")
            or (tick() - startTime) > maxWait
        
        -- Обязательно уничтожаем tween
        if activeTween then
            pcall(function() 
                activeTween:Cancel()
                activeTween:Destroy() 
            end)
            activeTween = nil
        end
        
        task.wait(0.03)
    end
    
    -- Очистка при выходе из цикла
    if activeTween then
        pcall(function() 
            activeTween:Cancel()
            activeTween:Destroy() 
        end)
    end
end)

-- Авто-ресет
task.spawn(function()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
    if not remotes then return end
    
    local gameplay = remotes:WaitForChild("Gameplay", 10)
    if not gameplay then return end
    
    local coinEvent = gameplay:WaitForChild("CoinCollected", 10)
    if not coinEvent then return end
    
    safeDisconnect("Coin")
    
    Connections.Coin = coinEvent.OnClientEvent:Connect(function(_, cur, max)
        if not _G.MM2FarmLoaded then return end
        
        local current, maximum = tonumber(cur), tonumber(max)
        if current and maximum and current >= maximum and Player.Character and not Settings.Resetting then
            Settings.Resetting = true
            pcall(function() Player.Character:BreakJoints() end)
            task.wait(3)
            Settings.Resetting = false
        end
    end)
end)

-- Анти-АФК и Реконнект
task.spawn(function()
    safeDisconnect("Error")
    safeDisconnect("Idle")
    
    Connections.Error = GuiService.ErrorMessageChanged:Connect(function()
        if not _G.MM2FarmLoaded then return end
        task.wait(1) 
        pcall(function() TeleportService:Teleport(game.PlaceId, Player) end)
    end)
    
    Connections.Idle = Player.Idled:Connect(function()
        if not _G.MM2FarmLoaded then return end
        local cam = workspace.CurrentCamera
        if cam then
            VirtualUser:Button2Down(Vector2.zero, cam.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.zero, cam.CFrame)
        end
    end)
end)

-- Очистка при удалении персонажа (предотвращает утечки)
Connections.CharRemoving = Player.CharacterRemoving:Connect(function(char)
    -- Очищаем ссылки на части персонажа
    Settings.Resetting = true
    task.wait(0.1)
end)

Connections.CharAdded = Player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    Settings.Resetting = false
end)
