local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local KartConfig = require(ReplicatedStorage:WaitForChild("KartConfig"))
local controlRemote = ReplicatedStorage:WaitForChild("KartControl")
local camera = Workspace.CurrentCamera
local currentSeat
local braking = false
local cameraConnection

local function getKartFromSeat(seat)
	local model = seat and seat:FindFirstAncestorOfClass("Model")
	if model and model:GetAttribute("OwnerUserId") == player.UserId then
		return model
	end
	return nil
end

local function stopDrivingCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

local function startDrivingCamera(kart)
	stopDrivingCamera()
	camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local smoothedCFrame
	cameraConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if not kart.Parent or not kart.PrimaryPart then
			stopDrivingCamera()
			return
		end
		local chassis = kart.PrimaryPart
		local focus = chassis.Position + chassis.CFrame.LookVector * KartConfig.CameraLookAhead + Vector3.new(0, 1.5, 0)
		local desiredPosition = (chassis.CFrame * CFrame.new(KartConfig.CameraOffset)).Position
		local desiredCFrame = CFrame.lookAt(desiredPosition, focus)
		local alpha = 1 - math.exp(-5 * deltaTime)
		smoothedCFrame = smoothedCFrame and smoothedCFrame:Lerp(desiredCFrame, alpha) or desiredCFrame
		camera.CFrame = smoothedCFrame
	end)
end

local function setBraking(value)
	if braking == value then
		return
	end
	braking = value
	controlRemote:FireServer(value)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Space and currentSeat then
		setBraking(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space then
		setBraking(false)
	end
end)

local function bindCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Seated:Connect(function(active, seat)
		if active and seat and seat:IsA("VehicleSeat") and getKartFromSeat(seat) then
			currentSeat = seat
			startDrivingCamera(getKartFromSeat(seat))
		else
			currentSeat = nil
			setBraking(false)
			stopDrivingCamera()
		end
	end)
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then
	task.spawn(bindCharacter, player.Character)
end
