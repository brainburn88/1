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
        task.wait(1.5) -- Ждем подольше для полной загрузки карты и персонажа
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

-- ПОЛНАЯ ЗАМОРОЗКА И ОТКЛЮЧЕНИЕ КОЛЛИЗИИ
-- Используем Stepped, так как он срабатывает ПЕРЕД физикой
RunService.Stepped:Connect(function()
    if not _G.MM2FarmLoaded then return end
    local char = Player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        if hrp then
            -- 1. Полная заморозка (Якорь)
            -- Это на 100% останавливает гравитацию и любые толчки
            hrp.Anchored = true 
            hrp.Velocity = Vector3.new(0,0,0)
        end
        
        if hum then
            hum.PlatformStand = true -- Отключает состояние ходьбы/падения
        end

        -- 2. Полное отключение коллизии всех частей тела
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                part.CanTouch = true -- Оставляем для сбора монет
            end
        end
    end
end)

-- Функция поиска монеты (строго 250 дистанция)
local function getTarget(hrp)
    local container = nil
    for _, v in ipairs(workspace:GetChildren()) do
        if v:FindFirstChild("CoinContainer") then 
            container = v.CoinContainer 
            break 
        end
    end
    
    if not container then return nil end

    local best = nil
    local lastDist = Settings.MaxDist

    for _, v in ipairs(container:GetChildren()) do
        if v:IsA("BasePart") and v:FindFirstChild("TouchInterest") then
            local d = (hrp.Position - v.Position).Magnitude
            if d < lastDist then
                lastDist = d
                best = v
            end
        end
    end
    return best
end

-- ЦИКЛ ПЕРЕМЕЩЕНИЯ (Heartbeat)
RunService.Heartbeat:Connect(function(dt)
    if not _G.MM2FarmLoaded then return end
    
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local target = getTarget(hrp)
    
    if target then
        -- Движение через CFrame (так как Anchored = true, это единственный способ)
        local targetPos = target.Position
        local direction = (targetPos - hrp.Position).Unit
        
        -- Перемещаем персонажа к монете
        hrp.CFrame = hrp.CFrame + (direction * (Settings.Speed * dt))
    end
end)

-- Авто-ресет при полной сумке
task.spawn(function()
    local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 20)
    if remotes then
        local coinEvent = remotes:WaitForChild("Gameplay"):WaitForChild("CoinCollected")
        coinEvent.OnClientEvent:Connect(function(_, cur, max)
            if tonumber(cur) >= tonumber(max) and Player.Character then
                _G.MM2FarmLoaded = false -- Останавливаем циклы перед ресетом
                Player.Character:BreakJoints()
                task.wait(2)
                _G.MM2FarmLoaded = true
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

print("[MM2 Farm] ТОТАЛЬНАЯ ЗАМОРОЗКА И КОЛЛИЗИЯ ВКЛЮЧЕНЫ.")
