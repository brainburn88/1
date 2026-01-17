local script_url = "https://raw.githubusercontent.com/brainburn88/1/refs/heads/main/5.lua"

-- Безопасный телепорт
local teleportFunc = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport)
if teleportFunc then
    teleportFunc([[
        if not game:IsLoaded() then game.Loaded:Wait() end
        repeat task.wait() until game.Players.LocalPlayer
        task.wait(2)
        loadstring(game:HttpGet("]]..script_url..[["))()
    ]])
end

-- Очистка старых сессий
if _G.MM2FarmLoaded then 
    _G.MM2FarmLoaded = false 
    task.wait(0.5) 
end
_G.MM2FarmLoaded = true

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

local Settings = {
    Speed = 25,
    MaxDist = 160,
    Resetting = false
}

Player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam

-- Ноклип
local noclipConn
noclipConn = RunService.Stepped:Connect(function()
    if not _G.MM2FarmLoaded then 
        if noclipConn then noclipConn:Disconnect() end
        return 
    end
    if Player.Character then
        for _, part in ipairs(Player.Character:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

-- Улучшенный поиск контейнера с защитой от "зависания"
local function getCoinContainer()
    local container = workspace:FindFirstChild("CoinContainer", true)
    if container and container.Parent and #container:GetChildren() > 0 then
        return container
    end
    return nil
end

local function getBestRandomTarget()
    local container = getCoinContainer()
    if not container then return nil end
    
    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local coinsInRange = {}
    for _, coin in ipairs(container:GetChildren()) do
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

-- ОСНОВНОЙ ЦИКЛ ФАРМА
task.spawn(function()
    local currentRotation = nil
    while _G.MM2FarmLoaded do
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")

        if Settings.Resetting or not hrp or not hum or hum.Health <= 0 then
            currentRotation = nil
            task.wait(1)
        else
            if not currentRotation then currentRotation = hrp.CFrame.Rotation end
            local target = getBestRandomTarget()
            
            if target then
                local dist = (target.Position - hrp.Position).Magnitude
                local tweenTime = dist / Settings.Speed
                
                local tween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {
                    CFrame = CFrame.new(target.Position) * currentRotation
                })
                
                local isDone = false
                local tConn
                tConn = tween.Completed:Connect(function()
                    isDone = true
                    if tConn then tConn:Disconnect() end
                end)
                
                tween:Play()
                
                -- Защита от застревания в бесконечном ожидании
                local timeout = 0
                while not isDone and _G.MM2FarmLoaded and not Settings.Resetting do
                    if not target or not target.Parent or not target:FindFirstChild("TouchInterest") or timeout > (tweenTime + 0.5) then
                        tween:Cancel()
                        break
                    end
                    timeout = timeout + task.wait()
                end
                
                if tConn then tConn:Disconnect() end
                tween:Destroy()
            else
                -- Если монет нет, ждем и сбрасываем ротацию для нового поиска
                currentRotation = nil
                task.wait(1) 
            end
        end
        task.wait()
    end
end)

-- Авто-ресет
task.spawn(function()
    local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 30)
    local gameplay = remotes and remotes:WaitForChild("Gameplay", 10)
    local coinEvent = gameplay and gameplay:WaitForChild("CoinCollected", 10)
    
    if coinEvent then
        if _G.CoinConn then _G.CoinConn:Disconnect() end
        _G.CoinConn = coinEvent.OnClientEvent:Connect(function(_, cur, max)
            if tonumber(cur) >= tonumber(max) and Player.Character and not Settings.Resetting then
                Settings.Resetting = true
                Player.Character:BreakJoints()
                task.wait(3)
                Settings.Resetting = false
            end
        end)
    end
end)

-- Анти-АФК и Реконнект
task.spawn(function()
    local TeleportService = game:GetService("TeleportService")
    local GuiService = game:GetService("GuiService")
    
    GuiService.ErrorMessageChanged:Connect(function()
        task.wait(1) 
        TeleportService:Teleport(game.PlaceId, Player)
    end)
    
    local vu = game:GetService("VirtualUser")
    Player.Idled:Connect(function()
        vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
end)
