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
        task.wait(1.5) 
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

-- ФУНКЦИЯ ПОЛНОЙ СТАБИЛИЗАЦИИ (ЗАМОРОЗКА)
local function stabilize(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    -- Создаем "замораживающие" объекты, если их нет
    local bv = hrp:FindFirstChild("FarmVelocity") or Instance.new("BodyVelocity")
    bv.Name = "FarmVelocity"
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge) -- Бесконечная сила (не дает падать)
    bv.Velocity = Vector3.new(0, 0, 0) -- Скорость ноль (заморозка)
    bv.Parent = hrp

    local bg = hrp:FindFirstChild("FarmGyro") or Instance.new("BodyGyro")
    bg.Name = "FarmGyro"
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge) -- Не дает крутиться
    bg.P = 9e4
    bg.CFrame = hrp.CFrame
    bg.Parent = hrp

    hum.PlatformStand = true -- Отключает гравитацию гуманоида
end

-- ПОЛНЫЙ НОКЛИП (КАЖДЫЙ КАДР)
RunService.Stepped:Connect(function()
    if not _G.MM2FarmLoaded then return end
    local char = Player.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

-- Поиск монеты (строго 250)
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

    -- Применяем заморозку
    stabilize(char)

    local target = getTarget(hrp)
    if target then
        -- Движение
        local targetPos = target.Position
        local direction = (targetPos - hrp.Position).Unit
        
        -- Плавно перемещаем CFrame, пока BodyVelocity держит нас в воздухе
        hrp.CFrame = hrp.CFrame + (direction * (Settings.Speed * dt))
        
        -- Обновляем гироскоп, чтобы смотреть на цель (опционально)
        if hrp:FindFirstChild("FarmGyro") then
            hrp.FarmGyro.CFrame = CFrame.new(hrp.Position, targetPos)
        end
    end
end)

-- Авто-ресет
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

print("[MM2 Farm] Загружено: Стабильный полет и Ноклип.")
