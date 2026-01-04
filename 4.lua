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
        task.wait(1) -- Увеличил ожидание для надежности
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

-- Функция для ПОЛНОЙ очистки физики и коллизии (то, что не работало)
local function stabilizeCharacter(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    
    if hrp and hum then
        -- "Заморозка"
        hum.PlatformStand = true
        hrp.Velocity = Vector3.new(0,0,0)
        hrp.RotVelocity = Vector3.new(0,0,0)
        
        -- Отключение коллизии (проход через стены)
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                part.Velocity = Vector3.new(0,0,0) -- Чтобы не дергало
            end
        end
    end
end

-- Поиск монеты в радиусе 250
local function getTarget(hrp)
    local container = nil
    for _, v in ipairs(workspace:GetChildren()) do
        if v:FindFirstChild("CoinContainer") then container = v.CoinContainer break end
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

-- ГЛАВНЫЙ ЦИКЛ (Heartbeat)
RunService.Heartbeat:Connect(function(dt)
    if not _G.MM2FarmLoaded then return end
    
    local char = Player.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- ПРИНУДИТЕЛЬНО каждый кадр отключаем коллизию и физику
    stabilizeCharacter(char)

    -- Поиск цели (строго 250)
    local target = getTarget(hrp)
    
    if target then
        local targetPos = target.Position
        local direction = (targetPos - hrp.Position).Unit
        
        -- Мгновенное перемещение CFrame
        hrp.CFrame = hrp.CFrame + (direction * (Settings.Speed * dt))
    end
end)

-- Авто-ресет
task.spawn(function()
    local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 10)
    if remotes then
        remotes.Gameplay.CoinCollected.OnClientEvent:Connect(function(_, cur, max)
            if cur >= max and Player.Character then
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

print("[MM2 Farm] Запущено! Стабилизация активна.")
