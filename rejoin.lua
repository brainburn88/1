-- КОНФИГУРАЦИЯ
local MINUTES = 30 

-- Функция для выполнения телепортации
local function Rejoin()
    local ts = game:GetService("TeleportService")
    local p = game:GetService("Players").LocalPlayer
    
    -- Сохраняем этот же скрипт в очередь, чтобы он запустился после перезахода
    if queue_on_teleport then
        queue_on_teleport([[loadstring(game:HttpGet("https://raw.githubusercontent.com/brainburn88/1/refs/heads/main/rejoin.lua"))()]]) 
        -- Если ты запускаешь это кодом, чит запомнит, что его надо запустить снова
    end

    print("Перезахожу для очистки памяти...")
    
    -- Пытаемся зайти на тот же сервер или новый
    if #game:GetService("Players"):GetPlayers() <= 1 then
        ts:Teleport(game.PlaceId, p)
    else
        ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, p)
    end
end

-- Таймер
task.spawn(function()
    while true do
        for i = MINUTES, 1, -1 do
            print("До автоматического перезахода осталось: " .. i .. " мин.")
            task.wait(60) -- Ждем 1 минуту
        end
        Rejoin()
    end
end)

print("Скрипт на авто-режойн активен (30 минут)")
