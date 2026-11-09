-- BLOCK KARTS | GARAGE LOBBY UI
-- The player starts on foot in the garage. This button requests a kart;
-- camera selection and the existing race countdown continue through KartService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local raceEvents = ReplicatedStorage:WaitForChild("RaceEvents")
local startRaceRemote = raceEvents:WaitForChild("StartRaceFromLobby")
local playerGui = player:WaitForChild("PlayerGui")

local previous = playerGui:FindFirstChild("BLOXYGarageLobby")
if previous then previous:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "BLOXYGarageLobby"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "LobbyPanel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -34)
panel.Size = UDim2.new(0.88, 0, 0, 154)
panel.BackgroundColor3 = Color3.fromRGB(20, 27, 38)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Parent = gui

local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(540, 154)
sizeLimit.MinSize = Vector2.new(280, 140)
sizeLimit.Parent = panel

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(34, 205, 225)
stroke.Thickness = 2
stroke.Transparency = 0.12
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromOffset(18, 12)
title.Size = UDim2.new(1, -36, 0, 36)
title.BackgroundTransparency = 1
title.Text = "BLOCK KARTS  |  GARAGE"
title.TextColor3 = Color3.fromRGB(245, 247, 250)
title.Font = Enum.Font.LondrinaSolid
title.TextSize = 28
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Name = "TrackInfo"
subtitle.Position = UDim2.fromOffset(18, 48)
subtitle.Size = UDim2.new(1, -36, 0, 24)
subtitle.BackgroundTransparency = 1
subtitle.Text = "PISTA DISPONIBLE  •  PLAYA"
subtitle.TextColor3 = Color3.fromRGB(255, 198, 55)
subtitle.Font = Enum.Font.Rajdhani
subtitle.TextSize = 19
subtitle.Parent = panel

local playButton = Instance.new("TextButton")
playButton.Name = "PlayButton"
playButton.AnchorPoint = Vector2.new(0.5, 1)
playButton.Position = UDim2.new(0.5, 0, 1, -12)
playButton.Size = UDim2.new(0.72, 0, 0, 48)
playButton.BackgroundColor3 = Color3.fromRGB(34, 190, 210)
playButton.BorderSizePixel = 0
playButton.Text = "JUGAR"
playButton.TextColor3 = Color3.fromRGB(12, 24, 32)
playButton.Font = Enum.Font.LondrinaSolid
playButton.TextSize = 28
playButton.AutoButtonColor = true
playButton.Parent = panel

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 10)
buttonCorner.Parent = playButton

local requestPending = false
local function refresh()
	local inGarage = player:GetAttribute("InGarage") == true
	panel.Visible = inGarage
	if not inGarage then
		requestPending = false
		playButton.Active = true
		playButton.AutoButtonColor = true
		playButton.Text = "JUGAR"
	end
end

playButton.Activated:Connect(function()
	if requestPending or player:GetAttribute("InGarage") ~= true then return end
	requestPending = true
	playButton.Active = false
	playButton.AutoButtonColor = false
	playButton.Text = "PREPARANDO KART..."
	startRaceRemote:FireServer()
	task.delay(8, function()
		if requestPending and player:GetAttribute("InGarage") == true then
			requestPending = false
			playButton.Active = true
			playButton.AutoButtonColor = true
			playButton.Text = "REINTENTAR"
		end
	end)
end)

player:GetAttributeChangedSignal("InGarage"):Connect(refresh)
refresh()
