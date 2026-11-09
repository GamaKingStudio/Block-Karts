local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
print(("[BLOXY-KART][HUD][START] player=%s script=%s"):format(player.Name, script:GetFullName()))
local config = require(ReplicatedStorage:WaitForChild("KartConfig"))
local typography = require(ReplicatedStorage:WaitForChild("BloxyTypography"))
local raceEvents = ReplicatedStorage:WaitForChild("RaceEvents")
local checkpointEvent = raceEvents:WaitForChild("CheckpointPassed")
local lapEvent = raceEvents:WaitForChild("LapCompleted")
local wrongWayEvent = raceEvents:WaitForChild("WrongWayStateChanged")

local previous = playerGui:FindFirstChild("BLOXYRaceHUD")
if previous then previous:Destroy() end

local hud = Instance.new("ScreenGui")
hud.Name = "BLOXYRaceHUD"
hud.ResetOnSpawn = false
hud.IgnoreGuiInset = true
hud.DisplayOrder = 20
hud.Enabled = false
hud.Parent = playerGui

-- BLOXY usa un único velocímetro: el indicador lateral de este HUD.
-- Limpia interfaces heredadas/externas que vuelvan a crear un velocímetro
-- central dentro de PlayerGui, sin tocar este HUD ni el resto de la interfaz.
local function removeLegacySpeedometer(instance)
 if not instance or not instance.Parent then return end

 local screenGui = instance:IsA("ScreenGui") and instance
  or instance:FindFirstAncestorOfClass("ScreenGui")
 if not screenGui or screenGui == hud or not screenGui.Parent then return end

 local guiName = string.lower(screenGui.Name)
 local namedSpeedGui = string.find(guiName, "speedometer", 1, true)
  or string.find(guiName, "speedhud", 1, true)
  or string.find(guiName, "vehiclespeed", 1, true)

 local hasSpeedUnit = false
 local hasSpeedTitle = false
 for _, descendant in ipairs(screenGui:GetDescendants()) do
  if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
   local normalizedText = string.upper(descendant.Text):gsub("[%s%p]", "")
   if normalizedText == "VELOCIDAD" or normalizedText == "SPEED" then
    hasSpeedTitle = true
   end
   if string.find(normalizedText, "KMH", 1, true)
    or string.find(normalizedText, "KPH", 1, true)
    or string.find(normalizedText, "MPH", 1, true) then
    hasSpeedUnit = true
   end
  end
 end

 -- El velocímetro heredado que aparece centrado usa el título "Velocidad"
 -- y una barra segmentada, sin mostrar KMH/KPH/MPH. El título basta para
 -- identificar y retirar su ScreenGui completo.
 if namedSpeedGui or hasSpeedUnit or hasSpeedTitle then
  screenGui:Destroy()
 end
end

-- Limpieza inicial y vigilancia de interfaces que aparezcan después.
for _, descendant in ipairs(playerGui:GetDescendants()) do
 removeLegacySpeedometer(descendant)
end
playerGui.DescendantAdded:Connect(function(descendant)
 task.defer(removeLegacySpeedometer, descendant)
 if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
  descendant:GetPropertyChangedSignal("Text"):Connect(function()
   removeLegacySpeedometer(descendant)
  end)
 end
end)

local function panel(name, size, position)
 local frame = Instance.new("Frame")
 frame.Name = name
 frame.Size = size
 frame.Position = position
 frame.BackgroundColor3 = Color3.fromRGB(18, 23, 31)
 frame.BackgroundTransparency = 0.16
 frame.BorderSizePixel = 0
 frame.Parent = hud
 local corner = Instance.new("UICorner")
 corner.CornerRadius = UDim.new(0, 10)
 corner.Parent = frame
 local stroke = Instance.new("UIStroke")
 stroke.Color = Color3.fromRGB(255, 197, 72)
 stroke.Thickness = 1.5
 stroke.Transparency = 0.22
 stroke.Parent = frame
 return frame
end

local function label(parent, name, size, position, text, textSize, color, fontRole)
 local item = Instance.new("TextLabel")
 item.Name = name
 item.Size = size
 item.Position = position
 item.BackgroundTransparency = 1
 item.Text = text
 item.TextColor3 = color or Color3.fromRGB(245, 247, 250)
 item.TextSize = textSize
 item.FontFace = typography.getFont(fontRole or "Light")
 item.TextXAlignment = Enum.TextXAlignment.Center
 item.TextYAlignment = Enum.TextYAlignment.Center
 item.Parent = parent
 return item
end


-- Estado del cronómetro declarado antes de conectar los eventos.
local lapStartedAt = nil
local bestLapTime = nil

local countdownEvent = raceEvents:WaitForChild("RaceCountdown")
local countdownLabel = label(hud, "RaceCountdown", UDim2.fromOffset(360, 150), UDim2.new(0.5, -180, 0.34, 0), "", 76, Color3.fromRGB(255, 205, 75), "Bold")
countdownLabel.TextStrokeTransparency = 0.06
countdownLabel.Visible = false
countdownEvent.OnClientEvent:Connect(function(value)
 if value > 3 then
  -- La cuenta corre desde 5 en el servidor, pero el HUD aparece recién en 3.
  countdownLabel.Visible = false
 elseif value > 0 then
  countdownLabel.Text = tostring(value)
  countdownLabel.TextColor3 = Color3.fromRGB(255, 205, 75)
  countdownLabel.Visible = true
 else
  -- El cronómetro de la vuelta comienza exactamente al dar la salida.
  lapStartedAt = os.clock()
  countdownLabel.Text = "¡YA!"
  countdownLabel.TextColor3 = Color3.fromRGB(100, 255, 145)
  countdownLabel.Visible = true
  task.delay(0.85, function() countdownLabel.Visible = false end)
 end
end)

local racePanel = panel("RacePanel", UDim2.fromOffset(300, 100), UDim2.new(0.5, -150, 0, 22))
local lapLabel = label(racePanel, "Lap", UDim2.new(1, -20, 0, 28), UDim2.fromOffset(10, 4), "VUELTA 1 / 3", 19, nil, "Title")
local timerLabel = label(racePanel, "LapTimer", UDim2.new(0.5, -12, 0, 25), UDim2.fromOffset(8, 34), "00:00.00", 22, Color3.fromRGB(255, 220, 145), "Light")
local bestLabel = label(racePanel, "BestLap", UDim2.new(0.5, -12, 0, 25), UDim2.new(0.5, 4, 0, 34), "MEJOR --:--.--", 15, Color3.fromRGB(220, 226, 235), "Light")
local checkpointLabel = label(racePanel, "Checkpoint", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 70), "CHECKPOINT 0 / 26", 15, Color3.fromRGB(220, 226, 235), "Light")

local speedPanel = panel("SpeedPanel", UDim2.fromOffset(180, 66), UDim2.new(1, -202, 1, -88))
local speedValue = label(speedPanel, "SpeedValue", UDim2.fromOffset(108, 62), UDim2.fromOffset(0, 0), "0", 46, nil, "Bold")
speedValue.TextXAlignment = Enum.TextXAlignment.Right
local speedUnit = label(speedPanel, "SpeedUnit", UDim2.fromOffset(72, 28), UDim2.fromOffset(108, 24), "/KMH", 16, Color3.fromRGB(220, 226, 235), "Light")
speedUnit.TextXAlignment = Enum.TextXAlignment.Left


local wrongWayLabel = label(
 hud,
 "WrongWayWarning",
 UDim2.new(1, -40, 0, 54),
 UDim2.new(0, 20, 0.44, -27),
 "¡SENTIDO CONTRARIO!",
 27,
 Color3.fromRGB(255, 65, 65),
 "Title"
)
wrongWayLabel.TextStrokeColor3 = Color3.fromRGB(35, 12, 12)
wrongWayLabel.TextStrokeTransparency = 0.25
wrongWayLabel.Visible = false


local currentSeat
local currentChassis
local renderConnection

-- ==========================================================
-- LEADERBOARD + MINIMAPA
-- ==========================================================
-- MINIMAPA + POSICIÓN DE CARRERA
local mapPanel = panel("MiniMap", UDim2.fromOffset(218, 190), UDim2.new(0, 18, 0, 58))
local mapTitle = label(mapPanel, "MiniMapTitle", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 0), "MAPA DE PISTA", 17, Color3.fromRGB(255, 220, 145), "Title")
local positionLabel = label(hud, "RacePosition", UDim2.fromOffset(142, 48), UDim2.new(1, -164, 0, 44), "1/6", 34, Color3.fromRGB(255, 220, 145), "Bold")
positionLabel.TextXAlignment = Enum.TextXAlignment.Right

local function makeTextOnly(frame)
 frame.BackgroundTransparency = 1
 local corner = frame:FindFirstChildOfClass("UICorner")
 if corner then corner:Destroy() end
 local stroke = frame:FindFirstChildOfClass("UIStroke")
 if stroke then stroke:Destroy() end
end
local function addTextOutline(textObject, color)
 textObject.TextStrokeColor3 = color or Color3.fromRGB(12, 16, 24)
 textObject.TextStrokeTransparency = 0.06
end
makeTextOnly(racePanel)
makeTextOnly(mapPanel)
makeTextOnly(speedPanel)
addTextOutline(speedValue); addTextOutline(speedUnit)
for _, textObject in ipairs({lapLabel, timerLabel, bestLabel, checkpointLabel, mapTitle, positionLabel}) do addTextOutline(textObject) end

local mapArea = Instance.new("Frame")
mapArea.Name = "MapArea"
mapArea.Size = UDim2.new(1, -20, 1, -30)
mapArea.Position = UDim2.fromOffset(10, 24)
mapArea.BackgroundColor3 = Color3.fromRGB(10, 15, 21)
mapArea.BackgroundTransparency = 1
mapArea.BorderSizePixel = 0
mapArea.ClipsDescendants = true
mapArea.Parent = mapPanel
local mapCorner = Instance.new("UICorner"); mapCorner.CornerRadius = UDim.new(0, 7); mapCorner.Parent = mapArea

-- Debe seguir el mismo trazado y orden de waypoints de KartService.
local mapPoints = {
local function refreshRacePosition()
	local entries = Players:GetPlayers()
	table.sort(entries, function(a, b)
		local al, bl = a:GetAttribute("RaceLap") or 1, b:GetAttribute("RaceLap") or 1
		if al ~= bl then return al > bl end
		local ac, bc = a:GetAttribute("RaceCheckpoint") or 0, b:GetAttribute("RaceCheckpoint") or 0
		if ac ~= bc then return ac > bc end
		return a.UserId < b.UserId
	end)
	local place = 1
	for index, racer in ipairs(entries) do
		if racer == player then place = index; break end
	end
	positionLabel.Text = string.format("%d/%d", place, math.max(6, #entries))
end
local function bindRacePositionPlayer(racer)
	racer:GetAttributeChangedSignal("RaceLap"):Connect(refreshRacePosition)
	racer:GetAttributeChangedSignal("RaceCheckpoint"):Connect(refreshRacePosition)
	refreshRacePosition()
end
Players.PlayerAdded:Connect(bindRacePositionPlayer)
Players.PlayerRemoving:Connect(refreshRacePosition)
for _, racer in ipairs(Players:GetPlayers()) do bindRacePositionPlayer(racer) end
refreshRacePosition()

local function updateMiniMap()
 if not currentChassis or not currentChassis.Parent then return end
 local p = currentChassis.Position
 local point = mapPosition(Vector2.new(p.X, p.Z))
 playerMarker.Position = UDim2.fromOffset(point.X, point.Y)
 markerArrow.Position = UDim2.fromOffset(point.X, point.Y - 17)
 local look = currentChassis.CFrame.LookVector
 markerArrow.Rotation = math.deg(math.atan2(-look.X, -look.Z))
end

local totalLaps = config.TOTAL_LAPS or 3
local function setLap(lap)
 if lap > totalLaps then
  lapLabel.Text = "¡CARRERA COMPLETADA!"
 else
  lapLabel.Text = ("VUELTA %d / %d"):format(math.max(1, lap), totalLaps)
 end
end

local function formatTime(seconds)
 local minutes = math.floor(seconds / 60)
 local remainder = seconds - minutes * 60
 return ("%02d:%05.2f"):format(minutes, remainder)
end

checkpointEvent.OnClientEvent:Connect(function(index, total)
 checkpointLabel.Text = ("CHECKPOINT %d / %d"):format(index, total)
 if index == 0 and not lapStartedAt then
  -- Respaldo por si el evento de salida no llegó al cliente.
  lapStartedAt = os.clock()
  timerLabel.Text = "00:00.00"
 end
end)

lapEvent.OnClientEvent:Connect(function(lap, lapTime, isBest)
 setLap(lap + 1)
 timerLabel.Text = formatTime(lapTime)
 -- Si queda otra vuelta, iniciar su contador inmediatamente.
 if lap + 1 <= totalLaps then
  -- Reinicio inmediato al comenzar la siguiente vuelta.
  -- No dejamos visible el tiempo de la vuelta anterior entre frames.
  lapStartedAt = os.clock()
  timerLabel.Text = "00:00.00"
 else
  lapStartedAt = nil
 end
 if isBest then
  bestLapTime = lapTime
  bestLabel.Text = "MEJOR " .. formatTime(bestLapTime)
  bestLabel.TextColor3 = Color3.fromRGB(255, 220, 145)
 elseif bestLapTime then
  bestLabel.Text = "MEJOR " .. formatTime(bestLapTime)
 end
end)

wrongWayEvent.OnClientEvent:Connect(function(isWrongWay)
 wrongWayLabel.Visible = isWrongWay
end)

local function updateRaceDisplay()
 if not currentChassis or not currentChassis.Parent then return end
 local forwardSpeed = math.abs(currentChassis.AssemblyLinearVelocity:Dot(currentChassis.CFrame.LookVector))
 speedValue.Text = tostring(math.floor(forwardSpeed * 1.008 + 0.5))
 updateMiniMap()
 if lapStartedAt then
  timerLabel.Text = formatTime(os.clock() - lapStartedAt)
 end
end

local function setDriving(seat)
 local model = seat and seat:FindFirstAncestorOfClass("Model")
 local ownerUserId = model and model:GetAttribute("OwnerUserId")
 print(("[BLOXY-KART][HUD][SEAT] seat=%s model=%s owner=%s expected=%s"):format(
  seat and seat:GetFullName() or "nil",
  model and model:GetFullName() or "nil",
  tostring(ownerUserId),
  tostring(player.UserId)
 ))
 if seat and seat:IsA("VehicleSeat") and model and ownerUserId == player.UserId then
  if currentSeat == seat then return end
  currentSeat = seat
  currentChassis = model.PrimaryPart
  hud.Enabled = true
  setLap(1)
  checkpointLabel.Text = "CHECKPOINT 0 / 26"
  timerLabel.Text = "00:00.00"
  lapStartedAt = nil
  bestLapTime = nil
  bestLabel.Text = "MEJOR --:--.--"
  bestLabel.TextColor3 = Color3.fromRGB(190, 202, 216)
  wrongWayLabel.Visible = false
  updateRaceDisplay()
  if renderConnection then renderConnection:Disconnect() end
  renderConnection = RunService.RenderStepped:Connect(updateRaceDisplay)
 else
  currentSeat = nil
  currentChassis = nil
  hud.Enabled = false
  wrongWayLabel.Visible = false
  if renderConnection then
   renderConnection:Disconnect()
   renderConnection = nil
  end
 end
end

local function bindCharacter(character)
 local humanoid = character:WaitForChild("Humanoid")
 -- SeatPart no siempre notifica a tiempo al cliente; Seated cubre ese caso.
 humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
  setDriving(humanoid.SeatPart)
 end)
 humanoid.Seated:Connect(function(isSeated, seatPart)
  setDriving(isSeated and seatPart or humanoid.SeatPart)
 end)
 setDriving(humanoid.SeatPart)
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then task.spawn(bindCharacter, player.Character) end
