-- ==========================================
-- MM2 FAST FARM (STRICT 250 DISTANCE)
-- ==========================================

if _G.MM2FarmLoaded then return end
_G.MM2FarmLoaded = true

local Settings = {
    Speed = 27,
    MaxDist = 250 -- Строгая проверка дистанции
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

-- Мгновенный Queue на телепорт
local function setupQueue()
    local qot = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)
    if qot then
        -- Вставь сюда ссылку на свой основной скрипт (Raw)
        qot([[loadstring(game:HttpGet("https://raw.githubusercontent.com/brainburn88/1/refs/heads/main/4.lua"))()]])
    end
end
setupQueue()

-- Быстрый поиск папки с монетами
local function getCoinContainer()
    for _, obj in ipairs(workspace:GetChildren()) do
        local container = obj:FindFirstChild("CoinContainer")
        if container then return container end
    end
    return nil
end

-- Поиск ближайшей монеты В ПРЕДЕЛАХ дистанции
local function getBestTarget(hrp)
    local container = getCoinContainer()
    if not container then return nil end

    local closest = nil
    local shortestDist = Settings.MaxDist -- Ищем только в этом радиусе

    local coins = container:GetChildren()
    for i = 1, #coins do
        local coin = coins[i]
        if coin:IsA("BasePart") and coin:FindFirstChild("TouchInterest") then
            local dist = (hrp.Position - coin.Position).Magnitude
            if dist < shortestDist then
                shortestDist = dist
                closest = coin
            end
        end
    end
    return closest
end

-- Стабилизация и коллизия (без лагов)
local function stabilize(char, hrp)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp:FindFirstChild("FarmVelocity") then
        local bv = Instance.new("BodyVelocity")
        bv.Name = "FarmVelocity"
        bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bv.Velocity = Vector3.new(0,0,0)
        bv.Parent = hrp
        
        local bg = Instance.new("BodyGyro")
        bg.Name = "FarmGyro"
        bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        bg.Parent = hrp
    end
    
    if hum then hum.PlatformStand = true end
    hrp.FarmGyro.CFrame = hrp.CFrame -- Держим ровно

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end

-- Основной цикл (самый быстрый метод в Roblox)
RunService.Heartbeat:Connect(function(dt)
    if not _G.MM2FarmLoaded then return end
    
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    stabilize(char, hrp)

    -- Проверка дистанции происходит ТУТ (каждый кадр)
    local target = getBestTarget(hrp)
    
    if target then
        local targetPos = target.Position
        local direction = (targetPos - hrp.Position).Unit
        -- Плавное, но быстрое перемещение
        hrp.CFrame = CFrame.new(hrp.Position + direction * (Settings.Speed * dt)) * hrp.CFrame.Rotation
    end
end)

-- Авто-ресет при полной сумке
task.spawn(function()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
    local coinEvent = remotes and remotes:WaitForChild("Gameplay", 5):WaitForChild("CoinCollected", 5)
    if coinEvent then
        coinEvent.OnClientEvent:Connect(function(_, current, max)
            if current >= max then
                if Player.Character and Player.Character:FindFirstChild("Humanoid") then
                    Player.Character.Humanoid.Health = 0
                    print("[MM2 Farm] Сумка полна, ресет...")
                end
            end
        end)
    end
end)

-- Anti-AFK
local vu = game:GetService("VirtualUser")
Player.Idled:Connect(function()
    vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

-- Быстрый реконнект при ошибках
game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
    if child.Name == "ErrorPrompt" then
        TeleportService:Teleport(game.PlaceId, Player)
    end
end)

print("[MM2 Farm] Запущено. Радиус: " .. Settings.MaxDist .. ", Скорость: " .. Settings.Speed)
