local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Очистка UI при перезапуске
local oldGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("AdoptMeTradeTransferUI")
if oldGui then
    oldGui:Destroy()
end

-- Создание гуи в PlayerGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AdoptMeTradeTransferUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 320, 0, 210)
MainFrame.Position = UDim2.new(0.5, -160, 0.4, -105)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 36)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.Text = "AUTO TRANSFER & TELEPORT"
Title.TextColor3 = Color3.fromRGB(240, 240, 240)
Title.TextSize = 14
Title.Parent = MainFrame

local TextBox = Instance.new("TextBox")
TextBox.Name = "TargetInput"
TextBox.Size = UDim2.new(0.88, 0, 0, 36)
TextBox.Position = UDim2.new(0.06, 0, 0.22, 0)
TextBox.BackgroundColor3 = Color3.fromRGB(42, 42, 54)
TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TextBox.PlaceholderText = "Введите ник игрока..."
TextBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 160)
TextBox.Font = Enum.Font.Gotham
TextBox.TextSize = 14
TextBox.ClearTextOnFocus = false
TextBox.Text = ""
TextBox.Parent = MainFrame

local BoxCorner = Instance.new("UICorner")
BoxCorner.CornerRadius = UDim.new(0, 8)
BoxCorner.Parent = TextBox

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Size = UDim2.new(0.88, 0, 0, 22)
StatusLabel.Position = UDim2.new(0.06, 0, 0.44, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "Ожидание ввода..."
StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
StatusLabel.TextSize = 12
StatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
StatusLabel.Parent = MainFrame

local StartBtn = Instance.new("TextButton")
StartBtn.Name = "StartButton"
StartBtn.Size = UDim2.new(0.88, 0, 0, 42)
StartBtn.Position = UDim2.new(0.06, 0, 0.62, 0)
StartBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
StartBtn.Font = Enum.Font.GothamBold
StartBtn.Text = "начать передачу"
StartBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StartBtn.TextSize = 15
StartBtn.Parent = MainFrame

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 8)
BtnCorner.Parent = StartBtn

local function setStatus(text, color)
    pcall(function()
        StatusLabel.Text = text
        StatusLabel.TextColor3 = color or Color3.fromRGB(200, 200, 210)
    end)
end

-- Логика обмена
local isRunning = false
local failedUntradableIds = {}

local function runTransfer(targetPlayer)
    local API = ReplicatedStorage:WaitForChild("API", 3)
    if not API then
        setStatus("Ошибка: папка API не найдена", Color3.fromRGB(255, 80, 80))
        return
    end

    local SendTrade = API:WaitForChild("TradeAPI/SendTradeRequest", 3)
    local AddItem = API:WaitForChild("TradeAPI/AddItemToOffer", 3)
    local AcceptNegotiation = API:WaitForChild("TradeAPI/AcceptNegotiation", 3)
    local ConfirmTrade = API:WaitForChild("TradeAPI/ConfirmTrade", 3)

    local ClientData
    pcall(function()
        local clientModules = ReplicatedStorage:WaitForChild("ClientModules", 3)
        if clientModules then
            local core = clientModules:WaitForChild("Core", 3)
            if core then
                ClientData = require(core:WaitForChild("ClientData", 3))
            end
        end
    end)

    local InventoryDB
    pcall(function()
        local clientModules = ReplicatedStorage:WaitForChild("ClientModules", 3)
        if clientModules then
            local core = clientModules:WaitForChild("Core", 3)
            if core then
                InventoryDB = require(core:WaitForChild("InventoryDB", 3))
            end
        end
    end)

    local function getInventory()
        local inv
        pcall(function()
            if ClientData and ClientData.get then
                inv = ClientData.get("inventory")
            end
            if not inv and ClientData and ClientData.get_data then
                local all = ClientData.get_data()
                local myData = all[LocalPlayer.Name] or all[tostring(LocalPlayer.UserId)]
                inv = myData and myData.inventory
            end
        end)
        return inv
    end

    local function getTradeData()
        local tradeData
        pcall(function()
            if ClientData and ClientData.get then
                tradeData = ClientData.get("trade")
            end
            if not tradeData and ClientData and ClientData.get_data then
                local all = ClientData.get_data()
                local myData = all[LocalPlayer.Name] or all[tostring(LocalPlayer.UserId)]
                tradeData = myData and myData.trade
            end
        end)
        return tradeData
    end

    local function getTradeApp()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        return pg and pg:FindFirstChild("TradeApp")
    end

    local function isTrulyVisible(guiObj)
        if not guiObj then return false end
        local current = guiObj
        while current and current:IsA("GuiObject") do
            if not current.Visible then
                return false
            end
            current = current.Parent
        end
        return true
    end

    local function isTradeWindowOpen()
        local tradeApp = getTradeApp()
        if tradeApp then
            local frame = tradeApp:FindFirstChild("Frame") or tradeApp:FindFirstChild("Container")
            if frame and isTrulyVisible(frame) then
                return true
            end
        end
        return false
    end

    local function isStillWaitingOnStage1()
        local tradeApp = getTradeApp()
        if not tradeApp then return false end
        for _, obj in ipairs(tradeApp:GetDescendants()) do
            if obj:IsA("TextButton") or obj:IsA("TextLabel") then
                if string.find(string.lower(obj.Text), "unaccept") and isTrulyVisible(obj) then
                    return true
                end
            end
        end
        return false
    end

    local function isStage2Active()
        local t = getTradeData()
        if t and t.current_trade then
            local stage = tostring(t.current_trade.stage or "")
            if stage == "confirmation" or stage == "2" then
                return true
            end
        end
        local tradeApp = getTradeApp()
        if tradeApp then
            for _, obj in ipairs(tradeApp:GetDescendants()) do
                if obj:IsA("TextLabel") and isTrulyVisible(obj) then
                    if string.find(string.lower(obj.Text), "fair") then
                        return true
                    end
                end
            end
        end
        return false
    end

    local function isTradable(uniqueId, petData)
        if failedUntradableIds[uniqueId] then
            return false
        end
        if petData.untradable == true or petData.is_untradable == true or petData.tradeable == false then
            return false
        end
        if petData.properties then
            if petData.properties.untradable or petData.properties.is_untradable or petData.properties.tradeable == false then
                return false
            end
        end

        local petKind = tostring(petData.id or petData.kind or ""):lower()
        if string.find(petKind, "starter") or string.find(petKind, "tutorial") then
            return false
        end

        if InventoryDB and InventoryDB.pets then
            local staticData = InventoryDB.pets[petKind] or (InventoryDB.get and InventoryDB.get(petKind))
            if staticData then
                if staticData.untradable == true or staticData.is_untradable == true or staticData.tradeable == false then
                    return false
                end
            end
        end

        return true
    end

    local function getConfirmDelay(itemCount)
        if itemCount <= 2 then return 5
        elseif itemCount == 3 then return 1
        elseif itemCount == 4 then return 1
        elseif itemCount == 5 then return 1
        elseif itemCount == 6 then return 1
        elseif itemCount == 7 then return 11
        else return 1 end
    end

    local function getTradablePets(limit)
        local petIds = {}
        local inv = getInventory()
        if not inv or not inv.pets then return petIds end

        for uniqueId, petData in pairs(inv.pets) do
            if isTradable(uniqueId, petData) then
                table.insert(petIds, uniqueId)
                if limit and #petIds >= limit then
                    break
                end
            end
        end
        return petIds
    end

    local function teleportToPlayer(target)
        if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                task.wait(0.4)
            end
        end
    end

    local sessionCount = 0

    while isRunning do
        local remaining = getTradablePets(nil)
        if #remaining == 0 then
            setStatus("Все питомцы переданы!", Color3.fromRGB(80, 255, 120))
            break
        end

        sessionCount = sessionCount + 1
        setStatus("Трейд #" .. sessionCount .. " (Осталось: " .. #remaining .. ")", Color3.fromRGB(240, 240, 240))

        if not targetPlayer or not targetPlayer.Parent then
            setStatus("Игрок вышел с сервера", Color3.fromRGB(255, 80, 80))
            break
        end

        teleportToPlayer(targetPlayer)

        -- 1. Отправка запроса
        setStatus("Отправка трейда...", Color3.fromRGB(240, 220, 100))
        SendTrade:FireServer(targetPlayer)

        -- 2. Ожидание открытия окна
        local opened = false
        local startWait = tick()
        while tick() - startWait < 45 do
            if not isRunning then return end
            if isTradeWindowOpen() then
                opened = true
                break
            end
            task.wait(0.5)
        end

        if not opened then
            setStatus("Трейд не принят, повтор...", Color3.fromRGB(255, 160, 60))
            task.wait(2)
            continue
        end

        setStatus("Выкладывание предметов...", Color3.fromRGB(100, 200, 255))
        task.wait(1.2)

        local currentBatch = getTradablePets(18)
        local totalAdded = #currentBatch
        if totalAdded == 0 then break end

        -- 3. Выкладывание предметов
        local aborted = false
        for i, uniqueId in ipairs(currentBatch) do
            if not isTradeWindowOpen() or not isRunning then
                aborted = true
                break
            end

            AddItem:FireServer(uniqueId)
            task.wait(0.01)

            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if pg then
                for _, label in ipairs(pg:GetDescendants()) do
                    if label:IsA("TextLabel") and label.Visible then
                        if string.find(string.lower(label.Text), "not tradeable") then
                            failedUntradableIds[uniqueId] = true
                            break
                        end
                    end
                end
            end
        end

        if aborted then
            task.wait(2)
            continue
        end

        -- 4. Ожидание 5 секунд и Accept
        setStatus("Ожидание 5 сек перед Accept...", Color3.fromRGB(240, 240, 100))
        task.wait(5)

        if not isTradeWindowOpen() or not isRunning then
            task.wait(2)
            continue
        end

        setStatus("Нажатие Accept...", Color3.fromRGB(100, 220, 100))
        AcceptNegotiation:FireServer()

        -- 5. Ожидание оппа
        setStatus("Ожидание оппонента...", Color3.fromRGB(240, 220, 100))
        local stage2Reached = false
        local waitOpponent = tick()

        while tick() - waitOpponent < 60 do
            if not isTradeWindowOpen() or not isRunning then
                aborted = true
                break
            end
            if not isStillWaitingOnStage1() and isStage2Active() then
                stage2Reached = true
                break
            end
            task.wait(0.25)
        end

        if aborted or not stage2Reached then
            setStatus("Трейд сброшен оппонентом", Color3.fromRGB(255, 100, 100))
            task.wait(2)
            continue
        end

        -- 6. Таймер Confirm
        local waitDuration = getConfirmDelay(totalAdded)
        local timerStart = tick()

        while tick() - timerStart < waitDuration do
            if not isTradeWindowOpen() or not isRunning then
                aborted = true
                break
            end
            local left = math.ceil(waitDuration - (tick() - timerStart))
            setStatus("Confirm через: " .. left .. " сек.", Color3.fromRGB(120, 240, 150))
            task.wait(0.2)
        end

        if aborted then
            task.wait(2)
            continue
        end

        -- 7. Нажатие Confirm
        setStatus("Подтверждение трейда...", Color3.fromRGB(80, 255, 120))
        ConfirmTrade:FireServer()

        -- 8. ждем закрытия окна
        local waitClose = tick()
        while tick() - waitClose < 25 do
            if not isTradeWindowOpen() then break end
            task.wait(0.4)
        end

        task.wait(2.5)
    end

    isRunning = false
    pcall(function()
        StartBtn.Text = "начать передачу"
        StartBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
    end)
end

-- Обработчик клика
StartBtn.MouseButton1Click:Connect(function()
    if isRunning then
        isRunning = false
        StartBtn.Text = "начать передачу"
        StartBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
        setStatus("Процесс остановлен", Color3.fromRGB(240, 200, 80))
        return
    end

    local rawInput = TextBox.Text
    local cleanName = string.match(rawInput, "^%s*(.-)%s*$")

    if not cleanName or cleanName == "" then
        setStatus("Введите ник игрока!", Color3.fromRGB(255, 80, 80))
        return
    end

    local foundPlayer = nil
    for _, plr in ipairs(Players:GetPlayers()) do
        if string.lower(plr.Name) == string.lower(cleanName) or string.lower(plr.DisplayName) == string.lower(cleanName) then
            foundPlayer = plr
            break
        end
    end

    if not foundPlayer then
        setStatus("Игрок не найден!", Color3.fromRGB(255, 80, 80))
        return
    end

    isRunning = true
    StartBtn.Text = "остановить передачу"
    StartBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    setStatus("Цель: " .. foundPlayer.Name, Color3.fromRGB(100, 220, 255))

    task.spawn(function()
        runTransfer(foundPlayer)
    end)
end)
