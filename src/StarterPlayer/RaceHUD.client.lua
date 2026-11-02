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

local racePanel = panel("RacePanel", UDim2.fromOffset(270, 68), UDim2.new(0.5, -135, 0, 22))
local lapLabel = label(racePanel, "Lap", UDim2.new(1, -20, 0, 31), UDim2.fromOffset(10, 5), "VUELTA 1 / 3", 20)
local checkpointLabel = label(racePanel, "Checkpoint", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 37), "CHECKPOINT 0 / 14", 12, Color3.fromRGB(190, 202, 216))

local speedPanel = panel("SpeedPanel", UDim2.fromOffset(150, 92), UDim2.new(1, -174, 1, -116))
local speedValue = label(speedPanel, "SpeedValue", UDim2.new(1, 0, 0, 55), UDim2.fromOffset(0, 5), "0", 42)
label(speedPanel, "SpeedUnit", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 61), "KM/H", 12, Color3.fromRGB(190, 202, 216))

local wrongPanel = panel("WrongWayPanel", UDim2.fromOffset(300, 44), UDim2.new(0.5, -150, 0, 102))
wrongPanel.Visible = false
label(wrongPanel, "WrongWayLabel", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), "¡SENTIDO CONTRARIO!", 17, Color3.fromRGB(255, 105, 95))

local totalLaps = config.TOTAL_LAPS or 3
local function setLap(lap)
 if lap > totalLaps then
  lapLabel.Text = "¡CARRERA COMPLETADA!"
 else
  lapLabel.Text = ("VUELTA %d / %d"):format(math.max(1, lap), totalLaps)
 end
end

checkpointEvent.OnClientEvent:Connect(function(index, total)
 checkpointLabel.Text = ("CHECKPOINT %d / %d"):format(index, total)
end)

lapEvent.OnClientEvent:Connect(function(lap)
 setLap(lap + 1)
end)

wrongWayEvent.OnClientEvent:Connect(function(isWrongWay)
 wrongPanel.Visible = isWrongWay
end)

local currentSeat
local currentChassis
local renderConnection

local function updateSpeed()
 if not currentChassis or not currentChassis.Parent then
  speedValue.Text = "0"
  return
 end
 local speed = math.abs(currentChassis.AssemblyLinearVelocity:Dot(currentChassis.CFrame.LookVector))
 speedValue.Text = tostring(math.floor(speed * 1.008 + 0.5))
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
  wrongPanel.Visible = false
  updateSpeed()
  if renderConnection then renderConnection:Disconnect() end
  renderConnection = RunService.RenderStepped:Connect(updateSpeed)
 else
  currentSeat = nil
  currentChassis = nil
  hud.Enabled = false
  wrongPanel.Visible = false
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
