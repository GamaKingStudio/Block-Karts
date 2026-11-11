local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
print(("[BLOXY-KART][HUD][START] player=%s script=%s"):format(player.Name, script:GetFullName()))
local config = require(ReplicatedStorage:WaitForChild("KartConfig"))
local Courses = require(ReplicatedStorage:WaitForChild("Courses"))
local typography = require(ReplicatedStorage:WaitForChild("BloxyTypography"))
local raceEvents = ReplicatedStorage:WaitForChild("RaceEvents")
local checkpointEvent = raceEvents:WaitForChild("CheckpointPassed")
local lapEvent = raceEvents:WaitForChild("LapCompleted")
local wrongWayEvent = raceEvents:WaitForChild("WrongWayStateChanged")
local raceFinishedEvent = raceEvents:WaitForChild("RaceFinished")
local returnToLobbyEvent = raceEvents:WaitForChild("ReturnToLobby")
local anotherRaceEvent = raceEvents:WaitForChild("AnotherRace")
local returnedToLobbyEvent = raceEvents:WaitForChild("ReturnedToLobby")
local matchmakingEntryCountdownEvent = raceEvents:WaitForChild("MatchmakingEntryCountdown")

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

-- Aviso independiente del HUD de carrera: se muestra mientras el jugador
-- permanece sobre una plataforma de matchmaking, antes de ser teletransportado.
local entryGui = Instance.new("ScreenGui")
entryGui.Name = "BLOXYMatchmakingEntry"
entryGui.ResetOnSpawn = false
entryGui.IgnoreGuiInset = true
entryGui.DisplayOrder = 60
entryGui.Enabled = false
entryGui.Parent = playerGui

local entryTitle = label(entryGui, "EntryTitle", UDim2.new(1, -40, 0, 42),
 UDim2.new(0, 20, 0.29, 0), "ENTRANDO A SALA", 25, Color3.fromRGB(255, 255, 255), "Title")
local entryNumber = label(entryGui, "EntryNumber", UDim2.new(1, -40, 0, 112),
 UDim2.new(0, 20, 0.34, 0), "5", 88, Color3.fromRGB(255, 197, 72), "Bold")
local entryDetail = label(entryGui, "EntryDetail", UDim2.new(1, -40, 0, 38),
 UDim2.new(0, 20, 0.48, 0), "MANTENTE EN LA PLATAFORMA", 18, Color3.fromRGB(255, 255, 255), "Light")
for _, textLabel in ipairs({entryTitle, entryNumber, entryDetail}) do
 textLabel.TextStrokeColor3 = Color3.fromRGB(12, 18, 25)
 textLabel.TextStrokeTransparency = 0.12
end
local entryDisplayToken = 0

matchmakingEntryCountdownEvent.OnClientEvent:Connect(function(value, capacity)
 entryDisplayToken += 1
 local token = entryDisplayToken
 if value == false then
  entryGui.Enabled = false
  return
 end

 entryGui.Enabled = true
 if value == 0 then
  entryTitle.Text = "SALA CONFIRMADA"
  entryNumber.Text = "¡YA!"
  entryNumber.TextColor3 = Color3.fromRGB(105, 255, 155)
  entryDetail.Text = "PREPARANDO TU KART..."
  task.delay(0.65, function()
   if entryDisplayToken == token then entryGui.Enabled = false end
  end)
 else
  entryTitle.Text = "ENTRANDO A SALA"
  entryNumber.Text = tostring(value)
  entryNumber.TextColor3 = Color3.fromRGB(255, 197, 72)
  local roomText = capacity == 1 and "CARRERA INDIVIDUAL" or (tostring(capacity) .. " PILOTOS")
  entryDetail.Text = roomText .. "  ·  MANTENTE EN LA PLATAFORMA"
 end
end)


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

-- Pantalla de resultados: aparece al cruzar la meta en la última vuelta.
local finishPanel = panel("RaceFinishedPanel", UDim2.fromOffset(560, 330), UDim2.new(0.5, -280, 0.5, -165))
finishPanel.Visible = false
finishPanel.ZIndex = 50
finishPanel.BackgroundTransparency = 1
finishPanel:FindFirstChildOfClass("UICorner"):Destroy()
finishPanel:FindFirstChildOfClass("UIStroke"):Destroy()
local finishTitle = label(finishPanel, "FinishTitle", UDim2.new(1, -24, 0, 48), UDim2.fromOffset(12, 8), "¡CARRERA TERMINADA!", 31, Color3.fromRGB(255, 210, 90), "Title")
local finishPosition = label(finishPanel, "FinishPosition", UDim2.new(1, -24, 0, 42), UDim2.fromOffset(12, 60), "1.er LUGAR", 28, Color3.fromRGB(245, 247, 250), "Bold")
local finishBestLap = label(finishPanel, "FinishBestLap", UDim2.new(1, -24, 0, 32), UDim2.fromOffset(12, 108), "MEJOR VUELTA: --:--.--", 20, Color3.fromRGB(255, 220, 145), "Light")
local finishTotalTime = label(finishPanel, "FinishTotalTime", UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 145), "TIEMPO TOTAL: --:--.--", 19, Color3.fromRGB(220, 226, 235), "Light")
local finishCountdown = label(finishPanel, "FinishCountdown", UDim2.new(1, -24, 0, 28), UDim2.fromOffset(12, 184), "Volviendo al lobby en 5...", 17, Color3.fromRGB(255, 220, 145), "Light")
finishCountdown.ZIndex = 51
finishCountdown.TextStrokeColor3 = Color3.fromRGB(12, 16, 24)
finishCountdown.TextStrokeTransparency = 0.04
finishCountdown.TextSize = 22
local function finishActionButton(name, text, position, width)
 local button = Instance.new("TextButton")
 button.Name = name
 button.Size = UDim2.fromOffset(width, 42)
 button.Position = position
 button.BackgroundTransparency = 1
 button.BorderSizePixel = 0
 button.Text = text
 button.TextColor3 = Color3.fromRGB(245, 247, 250)
 button.TextSize = 19
 button.FontFace = typography.getFont("Title")
 button.TextStrokeColor3 = Color3.fromRGB(12, 16, 24)
 button.TextStrokeTransparency = 0.05
 button.ZIndex = 52
 button.AutoButtonColor = true
 button.Parent = finishPanel
 return button
end
local returnLobbyButton = finishActionButton("ReturnToLobbyButton", "VOLVER AL LOBBY AHORA", UDim2.fromOffset(24, 232), 270)
local anotherRaceButton = finishActionButton("AnotherRaceButton", "OTRA CARRERA", UDim2.fromOffset(310, 232), 220)
for _, item in ipairs({ finishTitle, finishPosition, finishBestLap, finishTotalTime, finishCountdown }) do
 item.ZIndex = 51
 item.TextStrokeColor3 = Color3.fromRGB(12, 16, 24)
 item.TextStrokeTransparency = 0.06
end

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
local positionLabel = label(hud, "RacePosition", UDim2.fromOffset(142, 48), UDim2.new(1, -164, 0, 44), "1/6", 34, Color3.fromRGB(255, 220, 145), "Bold")
positionLabel.TextXAlignment = Enum.TextXAlignment.Right
local mapTitle = label(mapPanel, "MiniMapTitle", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 0), "MAPA DE PISTA", 17, Color3.fromRGB(255, 220, 145), "Title")

-- HUD minimalista: solo texto, sin tarjetas ni fondos opacos.
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
addTextOutline(speedValue)
addTextOutline(speedUnit)
for _, textObject in ipairs({
 lapLabel, timerLabel, bestLabel, checkpointLabel,
 mapTitle, positionLabel,
}) do
 addTextOutline(textObject)
end
local mapArea = Instance.new("Frame")
mapArea.Name = "MapArea"
mapArea.Size = UDim2.new(1, -20, 1, -30)
mapArea.Position = UDim2.fromOffset(10, 24)
mapArea.BackgroundColor3 = Color3.fromRGB(10, 15, 21)
mapArea.BackgroundTransparency = 1
mapArea.BorderSizePixel = 0
mapArea.ClipsDescendants = true
mapArea.Parent = mapPanel
local mapCorner = Instance.new("UICorner")
mapCorner.CornerRadius = UDim.new(0, 7)
mapCorner.Parent = mapArea

-- El minimapa comparte los waypoints reales del circuito activo con el servidor.
local mapPoints = {}
local minX, maxX, minZ, maxZ = 0, 1, 0, 1
local currentTrackWidth = 30
local currentMapCourse = Courses.Beach

local function loadMapCourse(courseId)
 currentMapCourse = Courses[courseId] or Courses.Beach
 table.clear(mapPoints)
 minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
 currentTrackWidth = currentMapCourse.trackWidth or 30
 for _, waypoint in ipairs(currentMapCourse.waypoints) do
  local point = Vector2.new(waypoint.X, waypoint.Z)
  table.insert(mapPoints, point)
  minX, maxX = math.min(minX, point.X), math.max(maxX, point.X)
  minZ, maxZ = math.min(minZ, point.Y), math.max(maxZ, point.Y)
 end
 local margin = math.max(15, currentTrackWidth / 2 + 8)
 minX, maxX = minX - margin, maxX + margin
 minZ, maxZ = minZ - margin, maxZ + margin
end

loadMapCourse(player:GetAttribute("SelectedCourse") or "Beach")
local function getCourseCheckpointCount()
 return currentMapCourse.checkpointCount or 26
end
checkpointLabel.Text = ("CHECKPOINT 0 / %d"):format(getCourseCheckpointCount())

local mapPadding = 15
local function mapPosition(point)
 local size = mapArea.AbsoluteSize
 local usableW = math.max(1, size.X - mapPadding * 2)
 local usableH = math.max(1, size.Y - mapPadding * 2)
 local scale = math.min(usableW / (maxX - minX), usableH / (maxZ - minZ))
 local drawnW = (maxX - minX) * scale
 local drawnH = (maxZ - minZ) * scale
 local offsetX = (size.X - drawnW) * 0.5
 local offsetY = (size.Y - drawnH) * 0.5
 return Vector2.new(
  offsetX + (point.X - minX) * scale,
  offsetY + (maxZ - point.Y) * scale
 )
end

local function makeTrackStroke(name, p1, p2, thickness, color, zIndex)
 local delta = p2 - p1
 local midpoint = (p1 + p2) * 0.5
 local line = Instance.new("Frame")
 line.Name = name
 line.AnchorPoint = Vector2.new(0.5, 0.5)
 line.Position = UDim2.fromOffset(midpoint.X, midpoint.Y)
 -- Extremos rectos: las uniones cuadradas evitan los "círculos" visibles.
 line.Size = UDim2.fromOffset(delta.Magnitude + thickness * 0.35, thickness)
 line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
 line.BackgroundColor3 = color
 line.BackgroundTransparency = 0
 line.BorderSizePixel = 0
 line.ZIndex = zIndex
 local lineCorner = Instance.new("UICorner")
 lineCorner.CornerRadius = UDim.new(1, 0)
 lineCorner.Parent = line
 line.Parent = mapArea
 return line
end

local trackSegments = {}
local function drawTrack()
 for _, segment in ipairs(trackSegments) do
  if segment.Parent then segment:Destroy() end
 end
 table.clear(trackSegments)

 local borderColor = Color3.fromRGB(5, 9, 14)
 local asphaltColor = Color3.fromRGB(82, 91, 103)

 -- El grosor del mapa sale del ancho REAL de la pista (30 studs) y de la escala
 -- del mapa. Antes era fijo (26/16 px) y resultaba mas ancho que la pista real,
 -- por eso los tramos que pasan cerca (el cruce a la derecha) se fundian en una
 -- masa gris sin borde. El asfalto se dibuja un poco mas fino que la pista para
 -- que siempre quede una linea negra visible entre tramos cercanos.
 local mapSize = mapArea.AbsoluteSize
 local mapScale = math.min(
  math.max(1, mapSize.X - mapPadding * 2) / (maxX - minX),
  math.max(1, mapSize.Y - mapPadding * 2) / (maxZ - minZ)
 )
 local roadPixels = currentTrackWidth * mapScale
 local asphaltWidth = math.max(5, roadPixels - 1)
 local borderWidth = asphaltWidth + 4
 local mappedPoints = {}
 for i, worldPoint in ipairs(mapPoints) do
  mappedPoints[i] = mapPosition(worldPoint)
 end

 -- Dibujar todos los bordes antes del asfalto evita uniones grises sin contorno.
 for i = 1, #mappedPoints - 1 do
  table.insert(trackSegments, makeTrackStroke("TrackBorder", mappedPoints[i], mappedPoints[i + 1], borderWidth, borderColor, 1))
 end
 for i = 1, #mappedPoints - 1 do
  table.insert(trackSegments, makeTrackStroke("TrackAsphalt", mappedPoints[i], mappedPoints[i + 1], asphaltWidth, asphaltColor, 2))
 end

 -- Primero las uniones negras; luego las uniones del asfalto.
 for i = 1, #mappedPoints - 1 do
  local point = mappedPoints[i]
  local join = Instance.new("Frame")
  join.Name = "TrackBorderJoin"
  join.AnchorPoint = Vector2.new(0.5, 0.5)
  join.Position = UDim2.fromOffset(point.X, point.Y)
  join.Size = UDim2.fromOffset(borderWidth, borderWidth)
  local corner = Instance.new("UICorner")
  corner.CornerRadius = UDim.new(1, 0)
  corner.Parent = join
  join.BackgroundColor3 = borderColor
  join.BorderSizePixel = 0
  join.ZIndex = 1
  join.Parent = mapArea
  table.insert(trackSegments, join)
 end
 for i = 1, #mappedPoints - 1 do
  local point = mappedPoints[i]
  local join = Instance.new("Frame")
  join.Name = "TrackAsphaltJoin"
  join.AnchorPoint = Vector2.new(0.5, 0.5)
  join.Position = UDim2.fromOffset(point.X, point.Y)
  join.Size = UDim2.fromOffset(asphaltWidth, asphaltWidth)
  local corner = Instance.new("UICorner")
  corner.CornerRadius = UDim.new(1, 0)
  corner.Parent = join
  join.BackgroundColor3 = asphaltColor
  join.BorderSizePixel = 0
  join.ZIndex = 2
  join.Parent = mapArea
  table.insert(trackSegments, join)
 end

 -- Meta: la pista cruza la recta principal en X=0, Z=70.
 local finishPoint = currentMapCourse.finish or currentMapCourse.waypoints[1]
 local finishCenter = mapPosition(Vector2.new(finishPoint.X, finishPoint.Z))
 local finishLine = Instance.new("Frame")
 finishLine.Name = "MiniMapFinishLine"
 finishLine.AnchorPoint = Vector2.new(0.5, 0.5)
 finishLine.Position = UDim2.fromOffset(finishCenter.X, finishCenter.Y)
 finishLine.Size = UDim2.fromOffset(3, 20)
 finishLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
 finishLine.BackgroundTransparency = 0
 finishLine.BorderSizePixel = 0
 finishLine.ZIndex = 5
 finishLine.Parent = mapArea
 table.insert(trackSegments, finishLine)
end

drawTrack()
mapArea:GetPropertyChangedSignal("AbsoluteSize"):Connect(drawTrack)
player:GetAttributeChangedSignal("SelectedCourse"):Connect(function()
 loadMapCourse(player:GetAttribute("SelectedCourse") or "Beach")
 checkpointLabel.Text = ("CHECKPOINT 0 / %d"):format(getCourseCheckpointCount())
 drawTrack()
end)

local playerMarker = Instance.new("ImageLabel")
playerMarker.Name = "PlayerMarker"
playerMarker.Size = UDim2.fromOffset(27, 27)
playerMarker.AnchorPoint = Vector2.new(0.5, 0.5)
playerMarker.BackgroundColor3 = Color3.fromRGB(255, 197, 72)
playerMarker.BorderSizePixel = 0
playerMarker.Image = ""
playerMarker.ImageTransparency = 0
playerMarker.BackgroundTransparency = 0
playerMarker.ZIndex = 10
playerMarker.Parent = mapArea
local markerCorner = Instance.new("UICorner")
markerCorner.CornerRadius = UDim.new(1, 0)
markerCorner.Parent = playerMarker
local markerStroke = Instance.new("UIStroke")
markerStroke.Color = Color3.fromRGB(255, 255, 255)
markerStroke.Thickness = 2
markerStroke.Parent = playerMarker
local markerArrow = label(mapArea, "PlayerDirection", UDim2.fromOffset(22, 22), UDim2.fromOffset(0, 0), "▲", 15, Color3.fromRGB(255, 220, 90), "Bold")
markerArrow.AnchorPoint = Vector2.new(0.5, 0.5)
markerArrow.ZIndex = 11
playerMarker.ZIndex = 10

local thumbnailReady = false
task.spawn(function()
 local ok, imageUrl = pcall(function()
  return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
 end)
 if ok then playerMarker.Image = imageUrl; playerMarker.ImageTransparency = 0; thumbnailReady = true end
end)

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

local finishCountdownToken = 0
local function showRaceFinished(position, bestTime, totalTime)
 -- El resultado permanece visible aunque el asiento se desocupe al cruzar meta.
 hud.Enabled = true
 lapStartedAt = nil
 wrongWayLabel.Visible = false
 finishPosition.Text = position == 1 and "1.er LUGAR" or (position == 2 and "2.º LUGAR" or (tostring(position) .. "° LUGAR"))
 finishPosition.TextColor3 = position == 1 and Color3.fromRGB(255, 220, 90) or Color3.fromRGB(225, 235, 245)
 finishBestLap.Text = "MEJOR VUELTA: " .. (bestTime and bestTime > 0 and formatTime(bestTime) or "--:--.--")
 finishTotalTime.Text = "TIEMPO TOTAL: " .. formatTime(totalTime or 0)
 finishTitle.Text = "¡CARRERA TERMINADA!"
 finishPanel.Visible = true

 finishCountdownToken += 1
 local token = finishCountdownToken
 task.spawn(function()
  for seconds = 5, 1, -1 do
   if token ~= finishCountdownToken or not finishPanel.Visible then return end
   finishCountdown.Text = ("Volviendo al lobby en %d..."):format(seconds)
   task.wait(1)
  end
  if token == finishCountdownToken and finishPanel.Visible then
   finishCountdown.Text = "Volviendo al lobby..."
   returnToLobbyEvent:FireServer()
  end
 end)
end

raceFinishedEvent.OnClientEvent:Connect(function(position, bestTime, totalTime)
 showRaceFinished(position, bestTime, totalTime)
end)

returnLobbyButton.Activated:Connect(function()
 finishCountdownToken += 1
 finishCountdown.Text = "Volviendo al lobby..."
 returnToLobbyEvent:FireServer()
end)

anotherRaceButton.Activated:Connect(function()
 finishCountdownToken += 1
 finishPanel.Visible = false
 anotherRaceEvent:FireServer()
end)

returnedToLobbyEvent.OnClientEvent:Connect(function()
 finishCountdownToken += 1
 finishPanel.Visible = false
 hud.Enabled = false
 currentSeat = nil
 currentChassis = nil
 if renderConnection then
  renderConnection:Disconnect()
  renderConnection = nil
 end
end)

player:GetAttributeChangedSignal("RaceResult"):Connect(function()
 if player:GetAttribute("RaceResult") == nil then
  finishCountdownToken += 1
  finishPanel.Visible = false
 end
end)

-- Respaldo: atributos replicados muestran el resultado aunque el RemoteEvent
-- llegue mientras el HUD cambia de estado o el jugador sale del asiento.
player:GetAttributeChangedSignal("RaceResult"):Connect(function()
 if player:GetAttribute("RaceResult") then
  showRaceFinished(
   player:GetAttribute("RaceFinalPosition") or 1,
   player:GetAttribute("RaceBestLapTime") or 0,
   player:GetAttribute("RaceTotalTime") or 0
  )
 end
end)

if player:GetAttribute("RaceResult") then
 showRaceFinished(
  player:GetAttribute("RaceFinalPosition") or 1,
  player:GetAttribute("RaceBestLapTime") or 0,
  player:GetAttribute("RaceTotalTime") or 0
 )
end

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
  finishPanel.Visible = false
  finishCountdownToken += 1
  setLap(1)
  checkpointLabel.Text = ("CHECKPOINT 0 / %d"):format(getCourseCheckpointCount())
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
  hud.Enabled = player:GetAttribute("RaceResult") ~= nil
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
