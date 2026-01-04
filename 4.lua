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

-- 1. ОТКЛЮЧЕНИЕ УПРАВЛЕНИЯ И КОЛЛИЗИИ
RunService.Stepped:Connect(function()
    if not _G.MM2FarmLoaded then return end
    local char = Player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hrp then 
            hrp.Anchored = true -- Персонаж не может двигаться сам и не падает
        end
        if hum then 
            hum.PlatformStand = true 
            hum.WalkSpeed = 0 -- Дополнительно блокируем бег
            hum.JumpPower = 0
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

-- 3. ГЛАВНЫЙ ПРОЦЕСС СБОРА
task.spawn(function()
    while _G.MM2FarmLoaded do
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if hrp then
            local target = getBestRandomTarget(hrp)
            
            if target then
                -- А) ЛЕТИМ К МОНЕТКЕ
                while target and target.Parent and target:FindFirstChild("TouchInterest") and _G.MM2FarmLoaded do
                    local hrpPos = hrp.Position
                    local targetPos = target.Position
                    local dist = (targetPos - hrpPos).Magnitude
                    
                    if dist < 0.5 then break end -- Долетели
                    if dist > Settings.MaxDist + 10 then break end -- Слишком далеко
                    
                    local direction = (targetPos - hrpPos).Unit
                    local dt = RunService.Heartbeat:Wait()
                    
                    hrp.CFrame = CFrame.new(hrpPos + direction * (Settings.Speed * dt), targetPos)
                end
                
                -- Б) ЖДЕМ, ПОКА TOUCH INTEREST ПРОПАДЕТ (МОНЕТКА СОБРАНА)
                if target and target:FindFirstChild("TouchInterest") then
                    -- Фиксируем позицию на монетке
                    local connection
                    connection = RunService.Heartbeat:Connect(function()
                        if target and target.Parent and target:FindFirstChild("TouchInterest") then
                            hrp.CFrame = CFrame.new(target.Position)
                        else
                            connection:Disconnect()
                        end
                    end)
                    
                    -- Ждем исчезновения TouchInterest
                    repeat task.wait() 
                    until not target or not target.Parent or not target:FindFirstChild("TouchInterest") or not _G.MM2FarmLoaded
                    
                    if connection then connection:Disconnect() end
                end
            else
                task.wait(0.5) -- Нет монет в радиусе 250, ждем появления
            end
        else
            task.wait(1)
        end
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
            task.wait(3)
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

print("[MM2 Farm] Запущено! Режим ожидания монеты активен.")
