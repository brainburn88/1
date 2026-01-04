-- УКАЖИ СВОЮ ССЫЛКУ (обязательно Raw Pastebin)
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

-- 1. ТОТАЛЬНАЯ ЗАМОРОЗКА И НОКЛИП
RunService.Stepped:Connect(function()
    if not _G.MM2FarmLoaded then return end
    local char = Player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hrp then
            -- Обнуляем любую физику (заморозка в пространстве)
            hrp.Velocity = Vector3.new(0,0,0)
            hrp.RotVelocity = Vector3.new(0,0,0)
        end
        if hum then
            hum.PlatformStand = true -- Персонаж не пытается встать
        end
        -- Полный проход сквозь стены
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

-- 2. ПОИСК ТРЕХ БЛИЖАЙШИХ И ВЫБОР РАНДОМНОЙ
local function getBestRandomTarget(hrp)
    local container = nil
    for _, v in ipairs(workspace:GetChildren()) do
        if v:FindFirstChild("CoinContainer") then 
            container = v.CoinContainer 
            break 
        end
    end
    if not container then return nil end

    local coinsInRange = {}

    -- Собираем все монеты в радиусе 250
    for _, coin in ipairs(container:GetChildren()) do
        if coin:IsA("BasePart") and coin:FindFirstChild("TouchInterest") then
            local dist = (hrp.Position - coin.Position).Magnitude
            if dist <= Settings.MaxDist then
                table.insert(coinsInRange, {obj = coin, dist = dist})
            end
        end
    end

    if #coinsInRange == 0 then return nil end

    -- Сортируем по дистанции (от меньшей к большей)
    table.sort(coinsInRange, function(a, b) return a.dist < b.dist end)

    -- Берем до 3-х ближайших монет
    local count = math.min(3, #coinsInRange)
    
    -- Выбираем случайную из этих трех
    local randomIndex = math.random(1, count)
    return coinsInRange[randomIndex].obj
end

-- 3. ЦИКЛ ПЕРЕМЕЩЕНИЯ
local currentTarget = nil

RunService.Heartbeat:Connect(function(dt)
    if not _G.MM2FarmLoaded then return end
    
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Если текущая цель пропала или собрана, ищем новую из ТОП-3
    if not currentTarget or not currentTarget.Parent or not currentTarget:FindFirstChild("TouchInterest") then
        currentTarget = getBestRandomTarget(hrp)
    end

    if currentTarget then
        local targetPos = currentTarget.Position
        local dist = (hrp.Position - targetPos).Magnitude
        
        -- Если цель вдруг стала дальше 250 (например, при телепорте карты), сбрасываем
        if dist > Settings.MaxDist + 5 then
            currentTarget = nil
            return
        end

        -- Движение
        local direction = (targetPos - hrp.Position).Unit
        hrp.CFrame = hrp.CFrame + (direction * (Settings.Speed * dt))
        
        -- Поворот персонажа к цели
        hrp.CFrame = CFrame.new(hrp.Position, targetPos)
    end
end)

-- 4. АВТО-РЕСЕТ ПРИ ЗАПОЛНЕНИИ
task.spawn(function()
    local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 20)
    if remotes then
        remotes.Gameplay.CoinCollected.OnClientEvent:Connect(function(_, cur, max)
            if tonumber(cur) >= tonumber(max) and Player.Character then
                Player.Character:BreakJoints()
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

print("[MM2 Farm] Запущено: Рандомные цели (ТОП-3), Заморозка и Ноклип.")
