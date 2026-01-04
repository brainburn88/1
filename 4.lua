-- Убираем старые процессы, если они были
if _G.MM2_Cleanup then
    _G.MM2_Cleanup()
end

local connections = {}
local function AddConn(conn) table.insert(connections, conn) end

-- Функция очистки
_G.MM2_Cleanup = function()
    _G.MM2FarmLoaded = false
    for _, c in ipairs(connections) do
        if c then c:Disconnect() end
    end
    table.clear(connections)
    print("[MM2 Farm] Предыдущие процессы остановлены.")
end

_G.MM2FarmLoaded = true

local script_url = "https://raw.githubusercontent.com/brainburn88/1/refs/heads/main/4.lua"

-- Механика QueueOnTeleport
local teleportFunc = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport)
if teleportFunc then
    teleportFunc([[
        repeat task.wait() until game:IsLoaded()
        loadstring(game:HttpGet("]]..script_url..[["))()
    ]])
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local Player = Players.LocalPlayer

local Settings = { Speed = 27, MaxDist = 300, Resetting = false }

-- Оптимизированный поиск контейнера
local coinContainer = nil
local function updateContainer()
    if coinContainer and coinContainer.Parent then return coinContainer end
    for _, obj in ipairs(workspace:GetChildren()) do -- Ищем только в корне сначала
        if obj.Name == "CoinContainer" then coinContainer = obj return obj end
    end
    -- Если не нашли в корне, ищем глубже, но один раз
    coinContainer = workspace:FindFirstChild("CoinContainer", true)
    return coinContainer
end

-- Ноклип (Оптимизированный)
AddConn(RunService.Stepped:Connect(function()
    if not _G.MM2FarmLoaded or not Player.Character then return end
    for _, part in ipairs(Player.Character:GetChildren()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end))

-- Поиск лучшей монеты
local function getBestRandomTarget()
    local container = updateContainer()
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
    return coinsInRange[math.random(1, math.min(3, #coinsInRange))].obj
end

-- Основной цикл фарма
task.spawn(function()
    while _G.MM2FarmLoaded do
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if not Settings.Resetting and hrp then
            local target = getBestRandomTarget()
            if target then
                local dist = (target.Position - hrp.Position).Magnitude
                local tween = TweenService:Create(hrp, TweenInfo.new(dist/Settings.Speed, Enum.EasingStyle.Linear), {
                    CFrame = CFrame.new(target.Position)
                })
                tween:Play()
                
                -- Ждем завершения или исчезновения монеты
                local active = true
                local c = tween.Completed:Connect(function() active = false end)
                
                while active and _G.MM2FarmLoaded and not Settings.Resetting do
                    if not target or not target.Parent then break end
                    task.wait()
                end
                
                tween:Cancel()
                tween:Destroy() -- Очистка памяти после твина
                c:Disconnect()
            end
        end
        task.wait(0.1)
    end
end)

-- Авто-реконнект (Исправлен цикл)
task.spawn(function()
    while _G.MM2FarmLoaded do
        local coreGui = game:GetService("CoreGui")
        local prompt = coreGui:FindFirstChild("RobloxPromptGui")
        if prompt and prompt:FindFirstChild("promptOverlay") then
             TeleportService:Teleport(game.PlaceId, Player)
        end
        task.wait(5)
    end
end)

-- Авто-ресет
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 30)
if remotes then
    local coinEvent = remotes:WaitForChild("Gameplay"):WaitForChild("CoinCollected")
    AddConn(coinEvent.OnClientEvent:Connect(function(_, cur, max)
        if tonumber(cur) >= tonumber(max) and not Settings.Resetting then
            Settings.Resetting = true
            if Player.Character then Player.Character:BreakJoints() end
            task.wait(3)
            Settings.Resetting = false
        end
    end))
end

-- Anti-AFK
AddConn(Player.Idled:Connect(function()
    game:GetService("VirtualUser"):CaptureController()
    game:GetService("VirtualUser"):ClickButton2(Vector2.new())
end))

print("[MM2 Farm] Запущено без утечек.")
