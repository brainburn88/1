local script_url = "https://raw.githubusercontent.com/brainburn88/1/refs/heads/main/5.lua"

local teleportFunc = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport)
if teleportFunc then
    teleportFunc([[
        if not game:IsLoaded() then game.Loaded:Wait() end
        repeat task.wait() until game.Players.LocalPlayer
        task.wait(2)
        loadstring(game:HttpGet("]]..script_url..[["))()
    ]])
end

local function cleanup()
    _G.MM2FarmLoaded = false
    
    if _G.MM2Connections then
        for _, conn in pairs(_G.MM2Connections) do
            if typeof(conn) == "RBXScriptConnection" then
                pcall(conn.Disconnect, conn)
            end
        end
        table.clear(_G.MM2Connections)
        _G.MM2Connections = nil  -- ДОБАВЛЕНО
    end
    
    if _G.MM2Settings then
        table.clear(_G.MM2Settings)
        _G.MM2Settings = nil  -- ДОБАВЛЕНО
    end
    
    if _G.MM2CoinBuffer then
        table.clear(_G.MM2CoinBuffer)
        _G.MM2CoinBuffer = nil  -- ДОБАВЛЕНО
    end
end

if _G.MM2FarmLoaded then 
    cleanup()
    task.wait(0.5) 
end

_G.MM2FarmLoaded = true

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local VirtualUser = game:GetService("VirtualUser")

-- ДОБАВЛЕНО: защита от nil Player
local Player = Players.LocalPlayer
if not Player then
    Player = Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    Player = Players.LocalPlayer
end

_G.MM2Settings = {
    Speed = 25,
    MaxDist = 160,
    MaxDistSq = 25600,
    Resetting = false,
    CoinContainer = nil,
    LastContainerCheck = 0,
    TeleportDebounce = false
}
local Settings = _G.MM2Settings

_G.MM2Connections = {}
local Connections = _G.MM2Connections

_G.MM2CoinBuffer = {}
local coinBuffer = _G.MM2CoinBuffer

pcall(function()
    Player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
end)

local function safeDisconnect(name)
    local conn = Connections[name]
    if typeof(conn) == "RBXScriptConnection" then
        pcall(conn.Disconnect, conn)
        Connections[name] = nil
    end
end

local function isAlive()
    if not _G.MM2FarmLoaded then return false end
    local char = Player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    return hum and hum.Health > 0
end

Connections.Noclip = RunService.Stepped:Connect(function()
    if not _G.MM2FarmLoaded then 
        cleanup()
        return 
    end
    
    local char = Player.Character
    if not char then return end
    
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") and part.CanCollide then 
            part.CanCollide = false 
        end
    end
end)

local function getCoinContainer()
    local now = tick()
    local cached = Settings.CoinContainer
    
    if cached and cached.Parent and (now - Settings.LastContainerCheck) < 2 then
        return cached
    end
    
    Settings.LastContainerCheck = now
    
    if cached and not cached.Parent then
        Settings.CoinContainer = nil
    end
    
    Settings.CoinContainer = workspace:FindFirstChild("CoinContainer", true)
    return Settings.CoinContainer
end

local function getBestRandomTarget()
    local container = getCoinContainer()
    if not container then return nil end
    
    local char = Player.Character
    if not char then return nil end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local hrpPos = hrp.Position
    local maxDistSq = Settings.MaxDistSq
    local count = 0

    for _, coin in ipairs(container:GetChildren()) do
        if coin:IsA("BasePart") and coin:FindFirstChild("TouchInterest") then
            local delta = hrpPos - coin.Position
            local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
            
            if distSq <= maxDistSq then
                count += 1
                local entry = coinBuffer[count]
                
                if entry then
                    entry.obj = coin
                    entry.dist = distSq
                else
                    coinBuffer[count] = {obj = coin, dist = distSq}
                end
            end
        end
    end

    if count == 0 then return nil end
    
    for i = count + 1, #coinBuffer do
        coinBuffer[i] = nil
    end
    
    if count > 1 then
        table.sort(coinBuffer, function(a, b) 
            return a.dist < b.dist 
        end)
    end
    
    return coinBuffer[math.random(1, math.min(3, count))].obj
end

task.spawn(function()
    local currentRotation = nil
    local activeTween = nil
    
    local function cleanupTween()
        if activeTween then
            pcall(function() 
                activeTween:Cancel()
                activeTween:Destroy() 
            end)
            activeTween = nil
        end
    end
    
    while _G.MM2FarmLoaded do
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if Settings.Resetting or not hrp or not isAlive() then
            currentRotation = nil
            cleanupTween()
            task.wait(1)
            continue
        end
        
        currentRotation = currentRotation or hrp.CFrame.Rotation
        local target = getBestRandomTarget()
        
        if not target then
            currentRotation = nil
            task.wait(0.5)
            continue
        end
        
        local targetPos = target.Position
        local dist = (targetPos - hrp.Position).Magnitude
        local tweenTime = dist / Settings.Speed
        
        cleanupTween()
        
        activeTween = TweenService:Create(hrp, TweenInfo.new(tweenTime, Enum.EasingStyle.Linear), {
            CFrame = CFrame.new(targetPos) * currentRotation
        })
        
        activeTween:Play()
        
        local startTime = tick()
        local maxWait = tweenTime + 0.3
        
        while _G.MM2FarmLoaded and not Settings.Resetting do
            if not target.Parent or not target:FindFirstChild("TouchInterest") then
                break
            end
            if (tick() - startTime) > maxWait then
                break
            end
            task.wait(0.05)
        end
        
        cleanupTween()
        task.wait(0.03)
    end
    
    cleanupTween()
end)

task.spawn(function()
    local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
    if not remotes then return end
    
    local gameplay = remotes:WaitForChild("Gameplay", 10)
    if not gameplay then return end
    
    local coinEvent = gameplay:WaitForChild("CoinCollected", 10)
    if not coinEvent then return end
    
    safeDisconnect("Coin")
    
    Connections.Coin = coinEvent.OnClientEvent:Connect(function(_, cur, max)
        if not _G.MM2FarmLoaded or Settings.Resetting then return end
        
        local current, maximum = tonumber(cur), tonumber(max)
        if current and maximum and current >= maximum and Player.Character then
            Settings.Resetting = true
            pcall(function() Player.Character:BreakJoints() end)
            task.wait(3)
            Settings.Resetting = false
        end
    end)
end)

task.spawn(function()
    safeDisconnect("Error")
    safeDisconnect("Idle")
    
    Connections.Error = GuiService.ErrorMessageChanged:Connect(function()
        if not _G.MM2FarmLoaded or Settings.TeleportDebounce then return end
        
        Settings.TeleportDebounce = true
        task.wait(1)
        pcall(TeleportService.Teleport, TeleportService, game.PlaceId, Player)
    end)
    
    Connections.Idle = Player.Idled:Connect(function()
        if not _G.MM2FarmLoaded then return end
        -- ИСПРАВЛЕНО: безопасная проверка камеры
        local cam = workspace:FindFirstChild("Camera") or workspace.CurrentCamera
        if cam then
            VirtualUser:Button2Down(Vector2.zero, cam.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.zero, cam.CFrame)
        end
    end)
end)

Connections.CharRemoving = Player.CharacterRemoving:Connect(function()
    if not _G.MM2FarmLoaded then return end
    Settings.Resetting = true
end)

Connections.CharAdded = Player.CharacterAdded:Connect(function()
    if not _G.MM2FarmLoaded then return end
    task.wait(0.5)
    Settings.Resetting = false
end)
