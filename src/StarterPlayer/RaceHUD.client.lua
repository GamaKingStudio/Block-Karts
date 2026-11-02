local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local config = require(ReplicatedStorage:WaitForChild("KartConfig"))
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

local function label(parent, name, size, position, text, textSize, color)
 local item = Instance.new("TextLabel")
 item.Name = name
 item.Size = size
 item.Position = position
 item.BackgroundTransparency = 1
 item.Text = text
 item.TextColor3 = color or Color3.fromRGB(245, 247, 250)
 item.TextSize = textSize
 item.Font = Enum.Font.GothamBold
 item.TextXAlignment = Enum.TextXAlignment.Center
 item.TextYAlignment = Enum.TextYAlignment.Center
 item.Parent = parent
 return item
end

local racePanel = panel("RacePanel", UDim2.fromOffset(300, 100), UDim2.new(0.5, -150, 0, 22))
local lapLabel = label(racePanel, "Lap", UDim2.new(1, -20, 0, 28), UDim2.fromOffset(10, 4), "VUELTA 1 / 3", 19)
local timerLabel = label(racePanel, "LapTimer", UDim2.new(0.5, -12, 0, 25), UDim2.fromOffset(8, 34), "00:00.00", 18, Color3.fromRGB(255, 220, 145))
local bestLabel = label(racePanel, "BestLap", UDim2.new(0.5, -12, 0, 25), UDim2.new(0.5, 4, 0, 34), "MEJOR --:--.--", 11, Color3.fromRGB(190, 202, 216))
local checkpointLabel = label(racePanel, "Checkpoint", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 70), "CHECKPOINT 0 / 14", 12, Color3.fromRGB(190, 202, 216))

local speedPanel = panel("SpeedPanel", UDim2.fromOffset(150, 92), UDim2.new(1, -174, 1, -116))
local speedValue = label(speedPanel, "SpeedValue", UDim2.new(1, 0, 0, 55), UDim2.fromOffset(0, 5), "0", 42)
label(speedPanel, "SpeedUnit", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 61), "KM/H", 12, Color3.fromRGB(190, 202, 216))

local wrongWayLabel = label(
 hud,
 "WrongWayWarning",
 UDim2.new(1, -40, 0, 54),
 UDim2.new(0, 20, 0.44, -27),
 "¡SENTIDO CONTRARIO!",
 27,
 Color3.fromRGB(255, 65, 65)
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
local leaderboard = panel("Leaderboard", UDim2.fromOffset(218, 250), UDim2.new(0, 18, 0, 22))
label(leaderboard, "LeaderboardTitle", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 6), "CLASIFICACIÓN", 15, Color3.fromRGB(255, 220, 145))
local leaderboardRows = {}
for i = 1, 8 do
 local row = label(leaderboard, "Driver" .. i, UDim2.new(1, -18, 0, 23), UDim2.fromOffset(9, 35 + (i - 1) * 25), "", 12)
 row.TextXAlignment = Enum.TextXAlignment.Left
 leaderboardRows[i] = row
end

local mapPanel = panel("MiniMap", UDim2.fromOffset(218, 190), UDim2.new(0, 18, 0, 284))
label(mapPanel, "MiniMapTitle", UDim2.new(1, -16, 0, 25), UDim2.fromOffset(8, 4), "MAPA DE PISTA", 13, Color3.fromRGB(255, 220, 145))
local mapArea = Instance.new("Frame")
mapArea.Name = "MapArea"
mapArea.Size = UDim2.new(1, -20, 1, -38)
mapArea.Position = UDim2.fromOffset(10, 31)
mapArea.BackgroundColor3 = Color3.fromRGB(10, 15, 21)
mapArea.BackgroundTransparency = 0.15
mapArea.BorderSizePixel = 0
mapArea.ClipsDescendants = true
mapArea.Parent = mapPanel
local mapCorner = Instance.new("UICorner")
mapCorner.CornerRadius = UDim.new(0, 7)
mapCorner.Parent = mapArea

local mapPoints = {
 Vector2.new(80, 70), Vector2.new(-65, 70), Vector2.new(-115, 40),
 Vector2.new(-115, -50), Vector2.new(-80, -95), Vector2.new(-50, -95),
 Vector2.new(-50, -15), Vector2.new(-25, 10), Vector2.new(0, -15),
 Vector2.new(0, -85), Vector2.new(45, -105), Vector2.new(85, -65),
 Vector2.new(125, -10), Vector2.new(125, 35), Vector2.new(105, 65),
 Vector2.new(80, 70)
}

-- Proyección uniforme: mantiene la geometría real del circuito sin deformarla.
local minX, maxX, minZ, maxZ = -145, 155, -130, 95
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
 -- Un pequeño solapamiento evita huecos entre tramos consecutivos.
 line.Size = UDim2.fromOffset(delta.Magnitude + thickness * 0.6, thickness)
 line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
 line.BackgroundColor3 = color
 line.BorderSizePixel = 0
 line.ZIndex = zIndex
 line.Parent = mapArea
 local corner = Instance.new("UICorner")
 corner.CornerRadius = UDim.new(1, 0)
 corner.Parent = line
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
 local mappedPoints = {}
 for i, worldPoint in ipairs(mapPoints) do
  mappedPoints[i] = mapPosition(worldPoint)
 end

 for i = 1, #mappedPoints - 1 do
  local p1, p2 = mappedPoints[i], mappedPoints[i + 1]
  table.insert(trackSegments, makeTrackStroke("TrackBorder", p1, p2, 20, borderColor, 1))
  table.insert(trackSegments, makeTrackStroke("TrackAsphalt", p1, p2, 14, asphaltColor, 2))
 end

 -- Meta: la pista cruza la recta principal en X=0, Z=70.
 local finishCenter = mapPosition(Vector2.new(0, 70))
 local finishLine = Instance.new("Frame")
 finishLine.Name = "MiniMapFinishLine"
 finishLine.AnchorPoint = Vector2.new(0.5, 0.5)
 finishLine.Position = UDim2.fromOffset(finishCenter.X, finishCenter.Y)
 finishLine.Size = UDim2.fromOffset(3, 20)
 finishLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
 finishLine.BorderSizePixel = 0
 finishLine.ZIndex = 5
 finishLine.Parent = mapArea
 table.insert(trackSegments, finishLine)
end

drawTrack()
mapArea:GetPropertyChangedSignal("AbsoluteSize"):Connect(drawTrack)

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
local markerArrow = label(mapArea, "PlayerDirection", UDim2.fromOffset(22, 22), UDim2.fromOffset(0, 0), "▲", 15, Color3.fromRGB(255, 220, 90))
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

local function refreshLeaderboard()
 local entries = Players:GetPlayers()
 table.sort(entries, function(a, b)
  local al, bl = a:GetAttribute("RaceLap") or 1, b:GetAttribute("RaceLap") or 1
  if al ~= bl then return al > bl end
  return (a:GetAttribute("RaceCheckpoint") or 0) > (b:GetAttribute("RaceCheckpoint") or 0)
 end)
 for i, row in ipairs(leaderboardRows) do
  local racer = entries[i]
  if racer then
   local lap = racer:GetAttribute("RaceLap") or 1
   local cp = racer:GetAttribute("RaceCheckpoint") or 0
   row.Text = string.format("%d. %s   V%d · CP%d", i, racer.DisplayName, lap, cp)
   row.TextColor3 = racer == player and Color3.fromRGB(255, 220, 145) or Color3.fromRGB(235, 240, 245)
  else
   row.Text = ""
  end
 end
end
local function bindLeaderboardPlayer(racer)
 racer:GetAttributeChangedSignal("RaceLap"):Connect(refreshLeaderboard)
 racer:GetAttributeChangedSignal("RaceCheckpoint"):Connect(refreshLeaderboard)
 refreshLeaderboard()
end
Players.PlayerAdded:Connect(bindLeaderboardPlayer)
Players.PlayerRemoving:Connect(refreshLeaderboard)
for _, racer in ipairs(Players:GetPlayers()) do bindLeaderboardPlayer(racer) end
refreshLeaderboard()

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

local lapStartedAt = nil
local bestLapTime = nil

local function formatTime(seconds)
 local minutes = math.floor(seconds / 60)
 local remainder = seconds - minutes * 60
 return ("%02d:%05.2f"):format(minutes, remainder)
end

checkpointEvent.OnClientEvent:Connect(function(index, total)
 checkpointLabel.Text = ("CHECKPOINT %d / %d"):format(index, total)
 if index == 0 then
  lapStartedAt = os.clock()
  timerLabel.Text = "00:00.00"
 end
end)

lapEvent.OnClientEvent:Connect(function(lap, lapTime, isBest)
 setLap(lap + 1)
 lapStartedAt = nil
 timerLabel.Text = formatTime(lapTime)
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

local function updateSpeed()
 if not currentChassis or not currentChassis.Parent then
  speedValue.Text = "0"
  return
 end
 local speed = math.abs(currentChassis.AssemblyLinearVelocity:Dot(currentChassis.CFrame.LookVector))
 speedValue.Text = tostring(math.floor(speed * 1.008 + 0.5))
 updateMiniMap()
 if lapStartedAt then
  timerLabel.Text = formatTime(os.clock() - lapStartedAt)
 end
end

local function setDriving(seat)
 local model = seat and seat:FindFirstAncestorOfClass("Model")
 if seat and seat:IsA("VehicleSeat") and model and model:GetAttribute("OwnerUserId") == player.UserId then
  if currentSeat == seat then return end
  currentSeat = seat
  currentChassis = model.PrimaryPart
  hud.Enabled = true
  setLap(1)
  checkpointLabel.Text = "CHECKPOINT 0 / 14"
  timerLabel.Text = "00:00.00"
  lapStartedAt = nil
  bestLapTime = nil
  bestLabel.Text = "MEJOR --:--.--"
  bestLabel.TextColor3 = Color3.fromRGB(190, 202, 216)
  wrongWayLabel.Visible = false
  updateSpeed()
  if renderConnection then renderConnection:Disconnect() end
  renderConnection = RunService.RenderStepped:Connect(updateSpeed)
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
 humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
  setDriving(humanoid.SeatPart)
 end)
 setDriving(humanoid.SeatPart)
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then task.spawn(bindCharacter, player.Character) end
