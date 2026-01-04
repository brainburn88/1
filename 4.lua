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

local currentTarget = nil
local isWaitingForCoin = false

-- 1. БЛОКИРОВКА УПРАВЛЕНИЯ, ПАДЕНИЯ И КОЛЛИЗИИ
RunService.Stepped:Connect(function()
    if not _G.MM2FarmLoaded then return end
    local char = Player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        
        if hrp then
            hrp.Velocity = Vector3.new(0,0,0) -- Обнуляем падение
            hrp.RotVelocity = Vector3.new(0,0,0)
        end
        
        if hum then
            hum.PlatformStand = true -- Отключаем физику гуманоида
            hum.WalkSpeed = 0
        end

        -- Ноклип
        for _, part in ipairs(char:GetDescendants()) do
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
    table.sort(coinsInRange, function(a, b) return a.dist < b.dist end)
    
    local count = math.min(3, #coinsInRange)
    return coinsInRange[math.random(1, count)].obj
end

-- 3. ГЛАВНЫЙ ЦИКЛ ПЕРЕМЕЩЕНИЯ И ОЖИДАНИЯ
task.spawn(function()
    while _G.MM2FarmLoaded do
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if hrp then
            local target = getBestRandomTarget(hrp)
            
            if target then
                -- А) ПОЛЕТ К ЦЕЛИ
                while target and target.Parent and target:FindFirstChild("TouchInterest") and _G.MM2FarmLoaded do
                    local hrpPos = hrp.Position
                    local targetPos = target.Position
                    local dist = (targetPos - hrpPos).Magnitude
                    
                    if dist < 0.5 then break end -- Долетели вплотную
                    if dist > Settings.MaxDist + 20 then break end -- Цель исчезла/далеко
                    
                    local direction = (targetPos - hrpPos).Unit
                    local dt = RunService.Heartbeat:Wait()
                    
                    -- Двигаем персонажа (CFrame форсинг заменяет заморозку)
                    hrp.CFrame = CFrame.new(hrpPos + direction * (Settings.Speed * dt), targetPos)
                end
                
                -- Б) ОЖИДАНИЕ СБОРА (ПОКА ПРОПАДЕТ TOUCHINTEREST)
                if target and target:FindFirstChild("TouchInterest") then
                    isWaitingForCoin = true
                    
                    -- Удерживаем позицию на монетке, пока она не соберется
                    local waitStart = tick()
                    repeat 
                        hrp.CFrame = CFrame.new(target.Position) -- "Прилипаем" к монетке
                        RunService.Heartbeat:Wait()
                    until not target or not target.Parent or not target:FindFirstChild("TouchInterest") or (tick() - waitStart > 3) or not _G.MM2FarmLoaded
                    
                    isWaitingForCoin = false
                end
            else
                -- Если монет нет, просто держим текущую позицию, чтобы не падать
                local stayPos = hrp.CFrame
                repeat 
                    hrp.CFrame = stayPos
                    RunService.Heartbeat:Wait()
                until getBestRandomTarget(hrp) or not _G.MM2FarmLoaded
            end
        end
        task.wait()
    end
end)

-- 4. АВТО-РЕСЕТ ПРИ ПОЛНОЙ СУМКЕ
task.spawn(function()
    local r = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 30)
    local c = r:WaitForChild("Gameplay", 30):WaitForChild("CoinCollected", 30)
    c.OnClientEvent:Connect(function(_, cur, max)
        if tonumber(cur) >= tonumber(max) and Player.Character then
            _G.MM2FarmLoaded = false
            Player.Character:BreakJoints()
            task.wait(2)
            _G.MM2FarmLoaded = true
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

print("[MM2 Farm] Запущено: Без Anchored, ожидание TouchInterest, рандом ТОП-3.")
