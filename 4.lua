-- УКАЖИ СВОЮ ССЫЛКУ (Raw Pastebin)
local script_url = "https://raw.githubusercontent.com/brainburn88/1/refs/heads/main/4.lua"

-- ==========================================
-- МЕХАНИКА QUEUE ON TELEPORT
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
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

local Settings = {
    Speed = 27,
    MaxDist = 250
}

local currentRotation = nil

-- 1. ФИКС КАМЕРЫ (Чтобы не дрожала при проходе сквозь стены)
-- Мы ставим режим Invisicam, чтобы камера игнорировала коллизию объектов
Player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam

-- 2. ПОЛНЫЙ НОКЛИП
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

-- 3. ПОИСК СЛУЧАЙНОЙ МОНЕТЫ
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

-- 4. ГЛАВНЫЙ ЦИКЛ С ТВИНОМ
task.spawn(function()
    while _G.MM2FarmLoaded do
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if hrp then
            if not currentRotation then currentRotation = hrp.CFrame.Rotation end
            local target = getBestRandomTarget(hrp)
            
            if target then
                local dist = (target.Position - hrp.Position).Magnitude
                local tweenTime = dist / Settings.Speed
                
                local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear)
                local tween = TweenService:Create(hrp, tweenInfo, {
                    CFrame = CFrame.new(target.Position) * currentRotation
                })
                
                tween:Play()
                
                local completed = false
                local conn
                conn = tween.Completed:Connect(function() completed = true end)
                
                repeat 
                    task.wait() 
                    if not target or not target.Parent or not target:FindFirstChild("TouchInterest") then
                        tween:Cancel()
                        completed = true
                    end
                until completed or not _G.MM2FarmLoaded
                if conn then conn:Disconnect() end

                if target and target.Parent and target:FindFirstChild("TouchInterest") then
                    local waitStart = tick()
                    repeat 
                        hrp.CFrame = CFrame.new(target.Position) * currentRotation
                        task.wait()
                    until not target or not target.Parent or not target:FindFirstChild("TouchInterest") or (tick() - waitStart > 3) or not _G.MM2FarmLoaded
                end
            else
                task.wait(0.5)
            end
        else
            task.wait(1)
        end
    end
end)

-- 5. АВТО-РЕСЕТ ПРИ ПОЛНОЙ СУМКЕ
task.spawn(function()
    local r = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 30)
    local c = r:WaitForChild("Gameplay", 30):WaitForChild("CoinCollected", 30)
    c.OnClientEvent:Connect(function(_, cur, max)
        if tonumber(cur) >= tonumber(max) and Player.Character then
            -- При ресете возвращаем камеру в дефолт на секунду, чтобы избежать багов сброса
            Player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom
            _G.MM2FarmLoaded = false
            Player.Character:BreakJoints()
            task.wait(2)
            Player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
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

print("[MM2 Farm] Запущено! Камера зафиксирована (Invisicam).")
