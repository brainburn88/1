-- ==========================================
-- КОНФИГУРАЦИЯ
-- ==========================================
local script_url = "https://raw.githubusercontent.com/brainburn88/1/refs/heads/main/4.lua"
local sessionID = tick()
_G.CurrentMM2Session = sessionID

-- ==========================================
-- СИСТЕМА ОЧИСТКИ (CLEANUP)
-- ==========================================
if _G.MM2_Cleanup then 
    _G.MM2_Cleanup() 
end

local connections = {}
local function AddConn(conn) 
    table.insert(connections, conn) 
end

_G.MM2FarmLoaded = true
_G.MM2_Cleanup = function()
    _G.MM2FarmLoaded = false
    _G.CurrentMM2Session = nil
    for _, c in ipairs(connections) do 
        if c then c:Disconnect() end 
    end
    table.clear(connections)
    print("[SYSTEM] Память очищена, старые процессы убиты.")
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

local Settings = { Speed = 27, MaxDist = 500, Resetting = false }
local isReconnecting = false

-- ==========================================
-- БЕЗОПАСНЫЙ РЕКОННЕКТ
-- ==========================================
local function safeReconnect()
    if isReconnecting then return end
    isReconnecting = true
    
    local tf = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport)
    if tf then
        pcall(function()
            tf([[loadstring(game:HttpGet("]]..script_url..[["))()]])
        end)
    end
    
    task.wait(1)
    pcall(function() TeleportService:Teleport(game.PlaceId, Player) end)
end

-- Ловим кик/ошибки
AddConn(GuiService.ErrorMessageChanged:Connect(function()
    task.wait(2)
    safeReconnect()
end))

task.spawn(function()
    while _G.MM2FarmLoaded and _G.CurrentMM2Session == sessionID do
        local coreGui = game:GetService("CoreGui")
        local prompt = coreGui:FindFirstChild("RobloxPromptGui")
        if prompt and prompt:FindFirstChild("promptOverlay") then
            if prompt.promptOverlay:FindFirstChild("ErrorPrompt") then
                safeReconnect()
                break
            end
        end
        task.wait(5)
    end
end)

-- ==========================================
-- ЛОГИКА ФАРМА
-- ==========================================

-- Оптимизированный Ноклип (без коллизий персонажа)
AddConn(RunService.Stepped:Connect(function()
    if _G.CurrentMM2Session ~= sessionID or not Player.Character then return end
    for _, part in ipairs(Player.Character:GetChildren()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end))

-- Умный поиск цели (Случайная из 3-х ближайших)
local coinContainer = nil
local function getTarget()
    -- Кэшируем контейнер монет
    if not coinContainer or not coinContainer.Parent then
        coinContainer = workspace:FindFirstChild("CoinContainer", true)
    end
    if not coinContainer or not Player.Character then return nil end
    
    local hrp = Player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local coins = {}
    local children = coinContainer:GetChildren()
    local myPos = hrp.Position

    -- Собираем монеты в радиусе MaxDist
    for i = 1, #children do
        local c = children[i]
        if c:IsA("BasePart") and c:FindFirstChild("TouchInterest") then
            local d = (myPos - c.Position).Magnitude
            if d <= Settings.MaxDist then 
                table.insert(coins, {obj = c, dist = d}) 
            end
        end
    end
    
    local foundCount = #coins
    if foundCount == 0 then return nil end
    
    -- Сортируем по дистанции
    table.sort(coins, function(a, b) return a.dist < b.dist end)
    
    -- Выбираем рандомно из ближайших 3 (или меньше, если на карте всего 1-2 монеты)
    local maxPick = math.min(3, foundCount)
    return coins[math.random(1, maxPick)].obj
end

-- Главный цикл фарма
task.spawn(function()
    while _G.MM2FarmLoaded and _G.CurrentMM2Session == sessionID do
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if not Settings.Resetting and hrp then
            local target = getTarget()
            
            if target and target.Parent then
                local dist = (target.Position - hrp.Position).Magnitude
                local tweenInfo = TweenInfo.new(dist/Settings.Speed, Enum.EasingStyle.Linear)
                local tween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(target.Position)})
                
                local isDone = false
                local conn
                conn = tween.Completed:Connect(function()
                    isDone = true
                    if conn then conn:Disconnect() end
                end)
                
                tween:Play()
                
                -- Ждем завершения или исчезновения цели
                while not isDone and _G.CurrentMM2Session == sessionID and not Settings.Resetting and target.Parent do
                    task.wait(0.1) -- Частота 0.1 сек оптимальна для CPU при 24/7
                end
                
                -- Очистка ресурсов после каждого перемещения
                if tween then
                    tween:Cancel()
                    tween:Destroy()
                end
                if conn then conn:Disconnect() end
            else
                task.wait(0.5) -- Ждем появления монет
            end
        else
            task.wait(1) -- Ждем респавна или окончания ресета
        end
        task.wait()
    end
end)

-- Авто-ресет при полной сумке (Оптимизировано)
pcall(function()
    local rem = ReplicatedStorage:WaitForChild("Remotes")
    local gameplay = rem:WaitForChild("Gameplay")
    local coinEv = gameplay:WaitForChild("CoinCollected")
    
    AddConn(coinEv.OnClientEvent:Connect(function(_, cur, max)
        if tonumber(cur) >= tonumber(max) and not Settings.Resetting then
            Settings.Resetting = true
            task.wait(0.5)
            if Player.Character then 
                Player.Character:BreakJoints() 
            end
            task.wait(4) -- Время на респавн
            Settings.Resetting = false
        end
    end))
end)

-- Anti-AFK (Безопасный метод)
AddConn(Player.Idled:Connect(function()
    local vu = game:GetService("VirtualUser")
    vu:CaptureController()
    vu:ClickButton2(Vector2.new())
end))

-- Опционально: Отключение рендера для экономии ресурсов (раскомментируй, если нужно)
-- game:GetService("RunService"):Set3dRenderingEnabled(false)

print("[MM2 SUCCESS] Оптимизированный скрипт запущен. ID:", sessionID)
