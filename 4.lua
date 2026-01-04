-- ==========================================
-- НАСТРОЙКИ
-- ==========================================
local script_url = "https://raw.githubusercontent.com/brainburn88/1/refs/heads/main/4.lua"
local sessionID = tick()
_G.CurrentMM2Session = sessionID

-- ==========================================
-- ОЧИСТКА
-- ==========================================
if _G.MM2_Cleanup then _G.MM2_Cleanup() end
local connections = {}
local function AddConn(conn) table.insert(connections, conn) end

_G.MM2FarmLoaded = true
_G.MM2_Cleanup = function()
    _G.MM2FarmLoaded = false
    _G.CurrentMM2Session = nil
    for _, c in ipairs(connections) do if c then c:Disconnect() end end
    table.clear(connections)
end

-- ==========================================
-- СЕРВИСЫ
-- ==========================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local Settings = { Speed = 27, MaxDist = 400, Resetting = false }
local isReconnecting = false -- ПРЕДОХРАНИТЕЛЬ

-- ==========================================
-- УМНЫЙ АВТО-РЕКОННЕКТ
-- ==========================================
local function reconnect()
    if isReconnecting then return end -- Если уже перезаходим, ничего не делаем
    isReconnecting = true 
    
    warn("[MM2 Farm] Попытка перезахода...")
    
    local tf = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport)
    if tf then
        pcall(function()
            tf([[loadstring(game:HttpGet("]]..script_url..[["))()]])
        end)
    end
    
    -- Небольшая пауза перед самим телепортом для стабильности
    task.wait(1)
    
    -- Попытка телепорта
    local success, err = pcall(function()
        TeleportService:Teleport(game.PlaceId, Player)
    end)
    
    if not success then
        isReconnecting = false -- Если телепорт не удался (например, сервер полон), разрешаем попытку позже
    end
end

-- Проверка через GUI (самый надежный метод)
task.spawn(function()
    while _G.MM2FarmLoaded and _G.CurrentMM2Session == sessionID do
        if not isReconnecting then
            local coreGui = game:GetService("CoreGui")
            local prompt = coreGui:FindFirstChild("RobloxPromptGui")
            if prompt then
                local overlay = prompt:FindFirstChild("promptOverlay")
                if overlay and overlay:FindFirstChild("ErrorPrompt") then
                    reconnect()
                end
            end
        end
        task.wait(5) -- Проверяем раз в 5 секунд, чтобы не спамить
    end
end)

-- Проверка через системное событие (только если есть реальное сообщение об ошибке)
AddConn(GuiService.ErrorMessageChanged:Connect(function()
    task.wait(2) -- Даем время окну ошибки отрисоваться
    reconnect()
end))

-- ==========================================
-- ЛОГИКА ФАРМА (БЕЗ УТЕЧЕК)
-- ==========================================

-- Ноклип
AddConn(RunService.Stepped:Connect(function()
    if _G.CurrentMM2Session ~= sessionID or not Player.Character then return end
    for _, part in ipairs(Player.Character:GetChildren()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end))

local coinContainer = nil
local function getTarget()
    if not coinContainer or not coinContainer.Parent then
        coinContainer = workspace:FindFirstChild("CoinContainer", true)
    end
    if not coinContainer or not Player.Character then return nil end
    local hrp = Player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local coins = {}
    local children = coinContainer:GetChildren()
    for i = 1, #children do
        local c = children[i]
        if c:IsA("BasePart") and c:FindFirstChild("TouchInterest") then
            local d = (hrp.Position - c.Position).Magnitude
            if d <= Settings.MaxDist then table.insert(coins, {o = c, d = d}) end
        end
    end
    if #coins == 0 then return nil end
    table.sort(coins, function(a, b) return a.d < b.d end)
    return coins[math.random(1, math.min(3, #coins))].o
end

-- Цикл Твина
task.spawn(function()
    while _G.MM2FarmLoaded and _G.CurrentMM2Session == sessionID do
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not Settings.Resetting and hrp then
            local target = getTarget()
            if target then
                local dist = (target.Position - hrp.Position).Magnitude
                local tween = TweenService:Create(hrp, TweenInfo.new(dist/Settings.Speed, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target.Position)})
                local active = true
                local c = tween.Completed:Connect(function() active = false end)
                tween:Play()
                while active and _G.MM2FarmLoaded and not Settings.Resetting and target.Parent do task.wait() end
                tween:Cancel()
                tween:Destroy()
                c:Disconnect()
            end
        end
        task.wait(0.1)
    end
end)

-- Авто-ресет
pcall(function()
    local rem = ReplicatedStorage:WaitForChild("Remotes")
    local gameplay = rem:WaitForChild("Gameplay")
    local coinEv = gameplay:WaitForChild("CoinCollected")
    AddConn(coinEv.OnClientEvent:Connect(function(_, cur, max)
        if tonumber(cur) >= tonumber(max) and not Settings.Resetting then
            Settings.Resetting = true
            if Player.Character then Player.Character:BreakJoints() end
            task.wait(3)
            Settings.Resetting = false
        end
    end))
end)

-- Anti-AFK
AddConn(Player.Idled:Connect(function()
    local vu = game:GetService("VirtualUser")
    vu:CaptureController()
    vu:ClickButton2(Vector2.new())
end))

print("[MM2] Скрипт запущен. Сессия:", sessionID)
