--[[
	LobbyClient (LocalScript)
	Ruta Rojo:  src/StarterPlayer/LobbyClient.client.lua

	Interfaz del lobby:
	  - POPUP para elegir: SOLO vs CPU / 2 / 3 / 4 jugadores (aparece al entrar a la zona)
	  - Panel de estado "Esperando jugadores 1/2" con botón CANCELAR
	  - Cuenta regresiva grande 5 -> 1 antes de entrar a la pista
	  - Botón para reabrir el popup si lo cerraste
	No cambia la cámara ni los controles del kart.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LobbyRemotes")
local JoinQueue = remotes:WaitForChild("JoinQueue")
local LeaveQueue = remotes:WaitForChild("LeaveQueue")
local QueueState = remotes:WaitForChild("QueueState")

-- ---------------------------------------------------------------------------
-- Colores y utilidades de interfaz
-- ---------------------------------------------------------------------------
local BG = Color3.fromRGB(14, 14, 22)
local PANEL = Color3.fromRGB(26, 26, 38)
local PANEL_HOVER = Color3.fromRGB(40, 40, 58)
local PINK = Color3.fromRGB(255, 60, 160)
local CYAN = Color3.fromRGB(0, 220, 255)
local YELLOW = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(90, 230, 120)
local GRAY = Color3.fromRGB(170, 170, 190)
local WHITE = Color3.fromRGB(240, 240, 245)

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
	return s
end

local function text(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = WHITE
	l.TextSize = 18
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

local MODE_LIST = {
	{ id = "cpu", title = "SOLO vs CPU", desc = "Carrera inmediata contra 1 CPU", color = CYAN },
	{ id = "p2", title = "2 JUGADORES", desc = "Espera a 2 pilotos reales", color = PINK },
	{ id = "p3", title = "3 JUGADORES", desc = "Espera a 3 pilotos reales", color = YELLOW },
	{ id = "p4", title = "4 JUGADORES", desc = "Espera a 4 pilotos reales", color = GREEN },
}
local MODE_LABEL = {}
for _, m in ipairs(MODE_LIST) do
	MODE_LABEL[m.id] = m.title
end

-- ---------------------------------------------------------------------------
-- Construcción de la interfaz
-- ---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "LobbyMatchmaking"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

-- POPUP -----------------------------------------------------------------
local popup = Instance.new("Frame")
popup.Name = "Popup"
popup.AnchorPoint = Vector2.new(0.5, 0.5)
popup.Position = UDim2.fromScale(0.5, 0.5)
popup.Size = UDim2.fromOffset(440, 420)
popup.BackgroundColor3 = BG
popup.Visible = false
popup.Parent = gui
corner(popup, 16)
stroke(popup, CYAN, 3)

local popupScale = Instance.new("UIScale")
popupScale.Parent = popup

text(popup, {
	Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -80, 0, 44),
	Text = "ELIGE TU CARRERA", TextSize = 30, Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left,
})
text(popup, {
	Position = UDim2.fromOffset(20, 58), Size = UDim2.new(1, -40, 0, 22),
	Text = "La carrera empieza cuando la sala esté completa", TextSize = 15,
	TextColor3 = GRAY, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
})

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(36, 36)
closeBtn.Position = UDim2.new(1, -52, 0, 14)
closeBtn.BackgroundColor3 = PANEL
closeBtn.Text = "X"
closeBtn.TextColor3 = WHITE
closeBtn.Font = Enum.Font.GothamBlack
closeBtn.TextSize = 18
closeBtn.Parent = popup
corner(closeBtn, 8)

local messageLabel = text(popup, {
	Position = UDim2.fromOffset(20, 380), Size = UDim2.new(1, -40, 0, 28),
	Text = "", TextSize = 15, TextColor3 = Color3.fromRGB(255, 120, 120),
})

local modeButtons = {}
for i, m in ipairs(MODE_LIST) do
	local b = Instance.new("TextButton")
	b.Name = "Mode_" .. m.id
	b.AutoButtonColor = false
	b.Text = ""
	b.Size = UDim2.new(1, -40, 0, 62)
	b.Position = UDim2.fromOffset(20, 92 + (i - 1) * 72)
	b.BackgroundColor3 = PANEL
	b.Parent = popup
	corner(b, 10)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 6, 1, -16)
	bar.Position = UDim2.fromOffset(8, 8)
	bar.BackgroundColor3 = m.color
	bar.BorderSizePixel = 0
	bar.Parent = b
	corner(bar, 3)

	text(b, {
		Position = UDim2.fromOffset(26, 7), Size = UDim2.new(1, -40, 0, 28),
		Text = m.title, TextSize = 22, Font = Enum.Font.GothamBlack,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = m.color,
	})
	text(b, {
		Position = UDim2.fromOffset(26, 34), Size = UDim2.new(1, -40, 0, 22),
		Text = m.desc, TextSize = 14, Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GRAY,
	})

	b.MouseEnter:Connect(function() b.BackgroundColor3 = PANEL_HOVER end)
	b.MouseLeave:Connect(function() b.BackgroundColor3 = PANEL end)
	modeButtons[m.id] = b
end

-- BOTÓN PARA REABRIR EL POPUP ---------------------------------------------
local reopenBtn = Instance.new("TextButton")
reopenBtn.Name = "Reopen"
reopenBtn.AnchorPoint = Vector2.new(0.5, 1)
reopenBtn.Position = UDim2.new(0.5, 0, 1, -40)
reopenBtn.Size = UDim2.fromOffset(280, 48)
reopenBtn.BackgroundColor3 = BG
reopenBtn.Text = "ELEGIR MODO DE CARRERA"
reopenBtn.TextColor3 = CYAN
reopenBtn.Font = Enum.Font.GothamBlack
reopenBtn.TextSize = 16
reopenBtn.Visible = false
reopenBtn.Parent = gui
corner(reopenBtn, 12)
stroke(reopenBtn, CYAN, 2)

-- PANEL DE ESTADO (esperando jugadores) -------------------------------------
local status = Instance.new("Frame")
status.Name = "Status"
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.new(0.5, 0, 0, 70)
status.Size = UDim2.fromOffset(420, 84)
status.BackgroundColor3 = BG
status.Visible = false
status.Parent = gui
corner(status, 14)
stroke(status, PINK, 3)

local statusTitle = text(status, {
	Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -150, 0, 30),
	Text = "", TextSize = 22, Font = Enum.Font.GothamBlack,
	TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = PINK,
})
local statusLine = text(status, {
	Position = UDim2.fromOffset(16, 42), Size = UDim2.new(1, -150, 0, 30),
	Text = "", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left,
})
local cancelBtn = Instance.new("TextButton")
cancelBtn.Size = UDim2.fromOffset(110, 44)
cancelBtn.Position = UDim2.new(1, -124, 0.5, -22)
cancelBtn.BackgroundColor3 = Color3.fromRGB(190, 40, 60)
cancelBtn.Text = "CANCELAR"
cancelBtn.TextColor3 = WHITE
cancelBtn.Font = Enum.Font.GothamBlack
cancelBtn.TextSize = 16
cancelBtn.Parent = status
corner(cancelBtn, 10)

-- CUENTA REGRESIVA GRANDE -----------------------------------------------------
local countdown = Instance.new("Frame")
countdown.Name = "Countdown"
countdown.AnchorPoint = Vector2.new(0.5, 0.5)
countdown.Position = UDim2.fromScale(0.5, 0.38)
countdown.Size = UDim2.fromOffset(420, 230)
countdown.BackgroundTransparency = 1
countdown.Visible = false
countdown.Parent = gui

local countdownTitle = text(countdown, {
	Size = UDim2.new(1, 0, 0, 34), Text = "LA CARRERA EMPIEZA EN",
	TextSize = 24, Font = Enum.Font.GothamBlack,
})
stroke(countdownTitle, BG, 3)

local countdownNumber = text(countdown, {
	Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 180),
	Text = "5", TextScaled = true, Font = Enum.Font.GothamBlack, TextColor3 = WHITE,
})
stroke(countdownNumber, PINK, 6)
local numberScale = Instance.new("UIScale")
numberScale.Parent = countdownNumber

-- ---------------------------------------------------------------------------
-- Estado local
-- ---------------------------------------------------------------------------
local inZone = false
local dismissed = false   -- el jugador cerró el popup manualmente
local suppress = false    -- la carrera ya empezó: no reabrir hasta salir de la zona
local queued = nil        -- id del modo en el que está
local qState = "idle"     -- "idle" | "waiting" | "countdown"
local current, target, seconds = 0, 0, 0
local starting = false
local message = ""
local wasPopup = false

local function refresh()
	local showPopup = inZone and queued == nil and not dismissed and not suppress
	popup.Visible = showPopup
	if showPopup and not wasPopup then
		popupScale.Scale = 0.8
		TweenService:Create(popupScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	wasPopup = showPopup

	messageLabel.Text = message
	reopenBtn.Visible = inZone and queued == nil and dismissed and not suppress

	local showStatus = queued ~= nil and not starting
	status.Visible = showStatus
	if showStatus then
		statusTitle.Text = MODE_LABEL[queued] or "SALA"
		if qState == "countdown" then
			statusLine.Text = "Sala completa. ¡Prepárate!"
		else
			statusLine.Text = string.format("Esperando jugadores...  %d / %d", current, target)
		end
	end

	countdown.Visible = (queued ~= nil and qState == "countdown") or starting
end

local function pulse()
	numberScale.Scale = 1.4
	TweenService:Create(numberScale, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- ---------------------------------------------------------------------------
-- Botones
-- ---------------------------------------------------------------------------
for _, m in ipairs(MODE_LIST) do
	modeButtons[m.id].MouseButton1Click:Connect(function()
		message = ""
		JoinQueue:FireServer(m.id)
	end)
end

closeBtn.MouseButton1Click:Connect(function()
	dismissed = true
	refresh()
end)

reopenBtn.MouseButton1Click:Connect(function()
	dismissed = false
	refresh()
end)

cancelBtn.MouseButton1Click:Connect(function()
	LeaveQueue:FireServer()
end)

-- ---------------------------------------------------------------------------
-- Mensajes del servidor
-- ---------------------------------------------------------------------------
QueueState.OnClientEvent:Connect(function(data)
	local st = data.state
	if st == "waiting" then
		queued, qState = data.mode, "waiting"
		current, target, seconds = data.current or 0, data.target or 0, 0
		starting = false
		message = ""
	elseif st == "countdown" then
		queued, qState = data.mode, "countdown"
		current, target, seconds = data.current or 0, data.target or 0, data.seconds or 0
		starting = false
		countdownTitle.Text = "LA CARRERA EMPIEZA EN"
		countdownNumber.Text = tostring(seconds)
		pulse()
	elseif st == "starting" then
		queued, qState = nil, "idle"
		starting = true
		suppress = true
		countdownTitle.Text = ""
		countdownNumber.Text = "¡YA!"
		pulse()
		task.delay(3, function()
			starting = false
			refresh()
		end)
	elseif st == "rejected" then
		message = data.message or "No se pudo entrar a la sala."
		local mine = message
		task.delay(4, function()
			if message == mine then
				message = ""
				refresh()
			end
		end)
	else -- "idle"
		queued, qState = nil, "idle"
		current, target, seconds = 0, 0, 0
	end
	refresh()
end)

-- ---------------------------------------------------------------------------
-- Detección de la zona (revisa la posición del personaje)
-- ---------------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(0.2)
		local zone = CollectionService:GetTagged("MatchmakingZone")[1]
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local now = false
		if zone and hrp then
			local rel = zone.CFrame:PointToObjectSpace(hrp.Position)
			local half = zone.Size / 2
			now = math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
		end

		if now and not inZone then
			inZone = true
			dismissed = false
			message = ""
			refresh()
		elseif (not now) and inZone then
			inZone = false
			suppress = false
			dismissed = false
			if queued then
				LeaveQueue:FireServer()
				queued, qState = nil, "idle"
			end
			refresh()
		end
	end
end)

refresh()
