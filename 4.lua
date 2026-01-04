-- ВСТАВЬ СВОЮ ССЫЛКУ НИЖЕ (Raw Pastebin)
local script_url = "https://raw.githubusercontent.com/brainburn88/1/refs/heads/main/2.lua"

-- ==========================================
-- МЕХАНИКА QUEUE ON TELEPORT (ИЗ SLAP BATTLES)
-- ==========================================
local teleportFunc = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport)
if teleportFunc then
    teleportFunc([[
        if not game:IsLoaded() then
            game.Loaded:Wait()
        end
        repeat task.wait() until game.Players.LocalPlayer
        task.wait(0.25)
        loadstring(game:HttpGet("]]..script_url..[["))()
    ]])
end

-- ==========================================
-- ОСНОВНАЯ ЛОГИКА (БЫСТРАЯ ФЕРМА)
-- ==========================================
if _G.MM2FarmLoaded then return end
_G.MM2FarmLoaded = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

local Settings = {
    Speed = 27,
    MaxDist = 250 -- СТРОГАЯ ПРОВЕРКА 250
}

-- Поиск контейнера монет
local function getCoinContainer()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:FindFirstChild("CoinContainer") then return obj.CoinContainer end
    end
    return nil
end

-- Поиск лучшей цели (каждый раз проверка дистанции 250)
local function getTarget(hrp)
    local container = getCoinContainer()
    if not container then return nil end

    local best = nil
    local lastDist = Settings.MaxDist -- Ищем только в этом радиусе

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

-- Главный цикл перемещения
RunService.Heartbeat:Connect(function(dt)
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Отключаем коллизию (каждый кадр)
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end

    -- Проверка дистанции 250 происходит прямо здесь
    local target = getTarget(hrp)
    
    if target then
        local targetPos = target.Position
        local direction = (targetPos - hrp.Position).Unit
        
        -- Убираем физику, чтобы не трясло
        hrp.Velocity = Vector3.new(0,0,0)
        
        -- Движение CFrame (максимально быстрое)
        hrp.CFrame = hrp.CFrame + (direction * (Settings.Speed * dt))
    end
end)

-- Авто-ресет при полной сумке
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

print("[MM2 Farm] Запущено! Reconnect: OK, Dist: 250")
