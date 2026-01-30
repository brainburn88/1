-- проверка на гниду (чтобы работало только в шлепках)
if game.PlaceId ~= 6403373529 then return end

-- перезапускаем скрипт, чтобы фармился бесконечна)))
if queue_on_teleport then
    queue_on_teleport([[loadstring(game:HttpGet("https://raw.githubusercontent.com/brainburn88/1/refs/heads/main/farmikslaps.lua"))()]])
end

-- нужная фигня
local FileName = "100серваковсохранялочка.json"
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

-- ждем когда все прогрузится
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local LocalPlayer = Players.LocalPlayer
repeat task.wait() until LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

-- вход в портал
if LocalPlayer.Character:FindFirstChild("entered") == nil then
    repeat task.wait()
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp and workspace:FindFirstChild("Lobby") and workspace.Lobby:FindFirstChild("Teleport1") then
            firetouchinterest(hrp, workspace.Lobby.Teleport1, 0)
            firetouchinterest(hrp, workspace.Lobby.Teleport1, 1)
        end
    until LocalPlayer.Character:FindFirstChild("entered")
end

task.wait(1) -- небольшая задержка чтобы персонаж успел прогрузиться)

-- сбор яблочек)) фармик)))
local slapples = workspace:FindFirstChild("Arena") and workspace.Arena:FindFirstChild("island5") and workspace.Arena.island5:FindFirstChild("Slapples")
if slapples then
    for i, v in ipairs(slapples:GetDescendants()) do
        if v.Name == "Glove" and v:FindFirstChildWhichIsA("TouchTransmitter") then
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                firetouchinterest(hrp, v, 0)
                firetouchinterest(hrp, v, 1)
            end
        end
    end
end

-- получаем сервачки)))
local function RefreshServerCache()
    local url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)

    if success then
        local data = HttpService:JSONDecode(response)
        if data and data.data then
            local serverIds = {}
            for _, server in pairs(data.data) do
                -- добавляем только те которые не заполнены
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    table.insert(serverIds, server.id)
                end
            end
            
            if #serverIds > 0 then
                writefile(FileName, HttpService:JSONEncode(serverIds))
                return serverIds
            end
        end
    end
    return nil
end

-- телепортик
local function FastHop()
    local serverList = {}

    -- читаем файл, если он есть
    if isfile(FileName) then
        local content = readfile(FileName)
        local success, decoded = pcall(HttpService.JSONDecode, HttpService, content)
        if success then serverList = decoded end
    end

    -- если список пуст то запрашиваем кэшик)
    if #serverList == 0 then
        serverList = RefreshServerCache()
    end

    -- если сервера не найдены то делаем запрос еще раз через 5 сек
    if not serverList or #serverList == 0 then
        task.wait(5)
        return FastHop()
    end

    -- берем случайный сервачок)
    local randomIndex = math.random(1, #serverList)
    local targetId = table.remove(serverList, randomIndex)
    
    -- сохранялка 100 сервачков в файлик)
    writefile(FileName, HttpService:JSONEncode(serverList))

    print("тэпаимся)))")
    
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, targetId, LocalPlayer)
    end)
    
    if not success then
        FastHop()
    end
end

-- обработка ошибок
TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage)
    print("не дал тепнуться!!! вот гнида,НАДО пытаться нах искать другой")
    FastHop()
end)

-- работай гнида
task.wait(1)
FastHop()
