-- ==========================================
-- НАСТРОЙКИ И ССЫЛКА
-- ==========================================
local script_url = "https://raw.githubusercontent.com/brainburn88/1/refs/heads/main/4.lua"

-- ==========================================
-- ОЧИСТКА ПРЕДЫДУЩЕГО ЗАПУСКА (STOP LEAKS)
-- ==========================================
if _G.MM2_Cleanup then
    _G.MM2_Cleanup()
end

local connections = {}
local function AddConn(conn) table.insert(connections, conn) end

_G.MM2FarmLoaded = true
_G.MM2_Cleanup = function()
    _G.MM2FarmLoaded = false
    for _, c in ipairs(connections) do
        if c then c:Disconnect() end
    end
    table.clear(connections)
    print("[MM2 Farm] Предыдущие процессы остановлены.")
end

-- ==========================================
-- МЕХАНИКА QUEUE ON TELEPORT
-- ==========================================
local teleportFunc = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport)
if teleportFunc then
    teleportFunc([[
        repeat task.wait() until game:IsLoaded()
        loadstring(game:HttpGet("]]..script_url..[["))()
    ]])
end

-- ==========================================
-- ПЕРЕМЕННЫЕ
-- ==========================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local Player = Players.LocalPlayer

local Settings = {
    Speed = 27,
    MaxDist = 400,
    Resetting = false
}

-- ==========================================
-- АВТО-РЕКОННЕКТ (ПРИ КИКЕ/ОШИБКЕ)
-- ==========================================
local function reconnect()
    if teleportFunc then
        teleportFunc([[
            repeat task.wait() until game:IsLoaded()
            loadstring(game:HttpGet("]]..script_url..[["))()
        ]])
    end
    TeleportService:Teleport(game.PlaceId, Player)
end

-- Отслеживание окна ошибки
AddConn(GuiService.ErrorMessageChanged:Connect(function()
    task.wait(1)
    reconnect()
end))

-- Ручная проверка интерфейса на наличие кика
task.spawn(function()
    while _G.MM2FarmLoaded do
        local coreGui = game:GetService("CoreGui")
        local prompt = coreGui:FindFirstChild("RobloxPromptGui")
        if prompt then
            local overlay = prompt:FindFirstChild("promptOverlay")
            if overlay and overlay:FindFirstChild("ErrorPrompt") then
                reconnect()
                break
            end
        end
        task.wait(3)
    end
end)

-- ==========================================
-- ЛОГИКА ФАРМА
-- ==========================================

-- Фикс камеры
Player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam

-- Ноклип (Оптимизированный)
AddConn(RunService.Stepped:Connect(function()
    if not _G.MM2FarmLoaded or not Player.Character then return end
    for _, part in ipairs(Player.Character:GetChildren()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end))

-- Поиск контейнера монет (Кэширование)
local coinContainer = nil
local function getCoinContainer()
    if coinContainer and coinContainer.Parent then return coinContainer end
    coinContainer = workspace:FindFirstChild("CoinContainer", true)
    return coinContainer
end

-- Поиск цели
local function getBestRandomTarget()
    local container = getCoinContainer()
    if not container or not Player.Character then return nil end
    
    local hrp = Player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local coinsInRange = {}
    local children = container:GetChildren()
    
    for i = 1, #children do
        local coin = children[i]
        if coin:IsA("BasePart") and coin:FindFirstChild("TouchInterest") then
            local dist = (hrp.Position - coin.Position).Magnitude
            if dist <= Settings.MaxDist then
                table.insert(coinsInRange, {obj = coin, dist = dist})
            end
        end
    end

    if #coinsInRange == 0 then return nil end
    table.sort(coinsInRange, function(a, b) return a.dist < b.dist end)
    
    -- Выбираем одну из 3 ближайших (для рандомизации)
    local count = math.min(3, #coinsInRange)
    return coinsInRange[math.random(1, count)].obj
end

-- Цикл движения
task.spawn(function()
    local currentRotation = nil
    while _G.MM2FarmLoaded do
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if not Settings.Resetting and hrp then
            if not currentRotation then currentRotation = hrp.CFrame.Rotation end
            
            local target = getBestRandomTarget()
            if target then
                local dist = (target.Position - hrp.Position).Magnitude
                local tweenTime = dist / Settings.Speed
                
                local tween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {
                    CFrame = CFrame.new(target.Position) * currentRotation
                })
                
                local active = true
                local completedConn = tween.Completed:Connect(function() active = false end)
                
                tween:Play()
                
                -- Ждем пока летим или пока монета не исчезнет
                while active and _G.MM2FarmLoaded and not Settings.Resetting do
                    if not target or not target.Parent or not target:FindFirstChild("TouchInterest") then
                        break
                    end
                    task.wait()
                end
                
                tween:Cancel()
                tween:Destroy() -- Очистка памяти
                completedConn:Disconnect()
            else
                task.wait(0.5) -- Ждем монеты
            end
        end
        task.wait()
    end
end)

-- ==========================================
-- АВТО-РЕСЕТ (КОГДА СУМКА ПОЛНАЯ)
-- ==========================================
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 30)
if remotes then
    local gameplayRemotes = remotes:FindFirstChild("Gameplay")
    if gameplayRemotes then
        local coinEvent = gameplayRemotes:WaitForChild("CoinCollected", 10)
        if coinEvent then
            AddConn(coinEvent.OnClientEvent:Connect(function(_, cur, max)
                if tonumber(cur) >= tonumber(max) and not Settings.Resetting then
                    Settings.Resetting = true
                    print("[MM2 Farm] Сумка полная, ресет...")
                    if Player.Character then
                        Player.Character:BreakJoints()
                    end
                    task.wait(3)
                    Settings.Resetting = false
                end
            end))
        end
    end
end

-- ==========================================
-- ANTI-AFK
-- ==========================================
AddConn(Player.Idled:Connect(function()
    local vu = game:GetService("VirtualUser")
    vu:CaptureController()
    vu:ClickButton2(Vector2.new())
end))

print("[MM2 Farm] Скрипт успешно запущен.")
print("[MM2 Farm] Авто-реконнект активен.")
