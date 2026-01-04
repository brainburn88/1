-- УКАЖИ СВОЮ ССЫЛКУ (Raw Pastebin)
local script_url = "https://raw.githubusercontent.com/brainburn88/1/refs/heads/main/4.lua"

-- ==========================================
-- МЕХАНИКА QUEUE ON TELEPORT (ИЗ SLAP BATTLES)
-- ==========================================
local teleportFunc = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport)
if teleportFunc then
    teleportFunc([[
        if not game:IsLoaded() then game.Loaded:Wait() end
        repeat task.wait() until game.Players.LocalPlayer
        task.wait(1)
        loadstring(game:HttpGet("]]..script_url..[["))()
    ]])
end

-- ==========================================
-- ОСНОВНАЯ ЛОГИКА
-- ==========================================
if _G.MM2FarmLoaded then return end
_G.MM2FarmLoaded = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

local Settings = {
    Speed = 27,
    MaxDist = 250
}

-- 1. ФУНКЦИЯ ЗАМОРОЗКИ (ТВОЙ МЕТОД, НО УСИЛЕННЫЙ)
local function applyFreeze(char)
    if not char then return end
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    -- Создаем или обновляем Velocity
    local bv = hrp:FindFirstChild("StableVelocity")
    if not bv then
        bv = Instance.new("BodyVelocity")
        bv.Name = "StableVelocity"
        bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent = hrp
    end

    -- Создаем или обновляем Gyro
    local bg = hrp:FindFirstChild("StableGyro")
    if not bg then
        bg = Instance.new("BodyGyro")
        bg.Name = "StableGyro"
        bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
        bg.Parent = hrp
    end
    bg.CFrame = hrp.CFrame

    hum.PlatformStand = true
end

-- Обновление при каждом спавне
Player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    applyFreeze(char)
end)

-- Постоянная проверка в цикле (чтобы не упал)
RunService.Stepped:Connect(function()
    local char = Player.Character
    if char then
        applyFreeze(char)
        -- Ноклип
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

-- 2. ПОИСК СЛУЧАЙНОЙ МОНЕТЫ ИЗ 3-х БЛИЖАЙШИХ
local function getBestRandomTarget(hrp)
    local container = nil
    for _, obj in pairs(workspace:GetChildren()) do
        if obj:FindFirstChild("CoinContainer") then 
            container = obj.CoinContainer 
            break 
        end
    end
    if not container then return nil end

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

    -- Сортировка по дистанции
    table.sort(coinsInRange, function(a, b) return a.dist < b.dist end)
    
    -- Выбор рандома из топ-3
    local count = math.min(3, #coinsInRange)
    return coinsInRange[math.random(1, count)].obj
end

-- 3. ЦИКЛ ПЕРЕМЕЩЕНИЯ
local currentTarget = nil

RunService.Heartbeat:Connect(function(dt)
    if not _G.MM2FarmLoaded then return end
    
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Если цели нет, ищем новую
    if not currentTarget or not currentTarget.Parent or not currentTarget:FindFirstChild("TouchInterest") then
        currentTarget = getBestRandomTarget(hrp)
    end

    if currentTarget then
        local targetPos = currentTarget.Position
        local currentPos = hrp.Position
        
        -- Проверка дистанции 250
        if (targetPos - currentPos).Magnitude > Settings.MaxDist + 5 then
            currentTarget = nil
            return
        end

        -- Движение
        local direction = (targetPos - currentPos).Unit
        hrp.CFrame = CFrame.new(currentPos + direction * (Settings.Speed * dt)) * hrp.CFrame.Rotation
    end
end)

-- 4. АВТО-РЕСЕТ
task.spawn(function()
    local r = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 30)
    local c = r:WaitForChild("Gameplay", 30):WaitForChild("CoinCollected", 30)
    c.OnClientEvent:Connect(function(_, cur, max)
        if tonumber(cur) >= tonumber(max) and Player.Character then
            Player.Character:BreakJoints()
        end
    end)
end)

-- Anti-AFK
local vu = game:GetService("VirtualUser")
Player.Idled:Connect(function()
    vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

print("[MM2 Farm] Исправлено: Заморозка активна всегда, персонаж не упадет.")
