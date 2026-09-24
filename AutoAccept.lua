local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Очистка UI 
local oldGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("AdoptMeAutoReceiverUI")
if oldGui then
    oldGui:Destroy()
end

-- Создание GUI в PlayerGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AdoptMeAutoReceiverUI"
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
Title.Text = "AUTO TRADE RECEIVER"
Title.TextColor3 = Color3.fromRGB(240, 240, 240)
Title.TextSize = 14
Title.Parent = MainFrame

local TextBox = Instance.new("TextBox")
TextBox.Name = "SenderInput"
TextBox.Size = UDim2.new(0.88, 0, 0, 36)
TextBox.Position = UDim2.new(0.06, 0, 0.22, 0)
TextBox.BackgroundColor3 = Color3.fromRGB(42, 42, 54)
TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TextBox.PlaceholderText = "Ник отправителя (пусто = любой)..."
TextBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 160)
TextBox.Font = Enum.Font.Gotham
TextBox.TextSize = 13
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
StatusLabel.Text = "Ожидание запуска..."
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
StartBtn.Text = "START LISTENER"
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

-- конект ремутов
local API = ReplicatedStorage:WaitForChild("API", 5)
local TradeRequestReceived = API and API:WaitForChild("TradeAPI/TradeRequestReceived", 5)
local AcceptOrDecline = API and API:WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest", 5)
local AcceptNegotiation = API and API:WaitForChild("TradeAPI/AcceptNegotiation", 5)
local ConfirmTrade = API and API:WaitForChild("TradeAPI/ConfirmTrade", 5)

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

local isListening = false
local filterSender = nil
local activeConnection = nil

-- Цикл спама Accept и Confirm раз в секунду
local function handleActiveTrade()
    setStatus("Трейд открыт. Спам Accept/Confirm...", Color3.fromRGB(120, 240, 150))
    
    while isListening and isTradeWindowOpen() do
        -- Отправка Accept
        pcall(function()
            AcceptNegotiation:FireServer()
        end)
        
        -- Отправка Confirm
        pcall(function()
            ConfirmTrade:FireServer()
        end)
        
        task.wait(1)
    end
    
    setStatus("Окно закрыто. Ждем следующий...", Color3.fromRGB(100, 220, 255))
end

-- Запуск прослушивания 
local function startListener(targetName)
    filterSender = targetName
    isListening = true

    setStatus("Ожидание запроса на трейд...", Color3.fromRGB(240, 220, 100))

    if activeConnection then
        activeConnection:Disconnect()
        activeConnection = nil
    end

    activeConnection = TradeRequestReceived.OnClientEvent:Connect(function(senderPlayer)
        if not isListening then return end
        if not senderPlayer or typeof(senderPlayer) ~= "Instance" or not senderPlayer:IsA("Player") then return end

        if filterSender and string.lower(senderPlayer.Name) ~= string.lower(filterSender) then
            return
        end

        setStatus("Принятие от: " .. senderPlayer.Name, Color3.fromRGB(100, 200, 255))
        pcall(function()
            AcceptOrDecline:InvokeServer(senderPlayer, true)
        end)

        -- Ожидание открытия трейда и старт спама
        task.spawn(function()
            local waitOpen = tick()
            while tick() - waitOpen < 15 do
                if not isListening then break end
                if isTradeWindowOpen() then
                    handleActiveTrade()
                    break
                end
                task.wait(0.3)
            end
        end)
    end)
end

local function stopListener()
    isListening = false
    if activeConnection then
        activeConnection:Disconnect()
        activeConnection = nil
    end
    setStatus("Остановлено", Color3.fromRGB(240, 200, 80))
end

-- Обработка кнопки 
StartBtn.MouseButton1Click:Connect(function()
    if isListening then
        stopListener()
        StartBtn.Text = "START LISTENER"
        StartBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
        return
    end

    local rawInput = TextBox.Text
    local cleanName = string.match(rawInput, "^%s*(.-)%s*$")
    local filterTarget = nil

    if cleanName and cleanName ~= "" then
        for _, plr in ipairs(Players:GetPlayers()) do
            if string.lower(plr.Name) == string.lower(cleanName) or string.lower(plr.DisplayName) == string.lower(cleanName) then
                filterTarget = plr.Name
                break
            end
        end
        if not filterTarget then
            setStatus("Игрок не найден на сервере!", Color3.fromRGB(255, 80, 80))
            return
        end
    end

    StartBtn.Text = "STOP LISTENER"
    StartBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)

    startListener(filterTarget)
end)
