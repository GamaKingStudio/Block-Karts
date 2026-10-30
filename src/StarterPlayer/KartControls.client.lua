local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
print(("[BLOXY-KART][CLIENT][LOCAL-SCRIPT-ENTER] script=%s parent=%s player=%s"):format(
	script:GetFullName(), script.Parent:GetFullName(), player.Name
))
local KartConfig = require(ReplicatedStorage:WaitForChild("KartConfig"))
local controlRemote = ReplicatedStorage:WaitForChild("KartControl", 15)
if not controlRemote then
	warn("[BLOXY-KART][CLIENT][REMOTE-MISSING] KartControl no apareció en ReplicatedStorage tras 15 segundos.")
	return
end
if not controlRemote:IsA("RemoteEvent") then
	warn(("[BLOXY-KART][CLIENT][REMOTE-WRONG-CLASS] ReplicatedStorage.KartControl es %s, no RemoteEvent."):format(controlRemote.ClassName))
	return
end
print(("[BLOXY-KART][CLIENT][START] script=%s parent=%s remote=%s class=%s"):format(
	script:GetFullName(), script.Parent:GetFullName(), controlRemote:GetFullName(), controlRemote.ClassName
))
local camera = Workspace.CurrentCamera
local currentSeat
local cameraConnection
local held = { forward = false, reverse = false, left = false, right = false, brake = false }
local driveActionName = "BLOXYKartDriveControls"
local driveKeys = {
	Enum.KeyCode.W, Enum.KeyCode.Up,
	Enum.KeyCode.S, Enum.KeyCode.Down,
	Enum.KeyCode.A, Enum.KeyCode.Left,
	Enum.KeyCode.D, Enum.KeyCode.Right,
	Enum.KeyCode.Space,
}
local keyToControl = {
	[Enum.KeyCode.W] = "forward", [Enum.KeyCode.Up] = "forward",
	[Enum.KeyCode.S] = "reverse", [Enum.KeyCode.Down] = "reverse",
	[Enum.KeyCode.A] = "left", [Enum.KeyCode.Left] = "left",
	[Enum.KeyCode.D] = "right", [Enum.KeyCode.Right] = "right",
	[Enum.KeyCode.Space] = "brake",
}

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

local function sendDriveInput()
	if not currentSeat then
		return
	end
	local throttle = (held.forward and 1 or 0) - (held.reverse and 1 or 0)
	local steering = (held.right and 1 or 0) - (held.left and 1 or 0)
	print(("[BLOXY-KART][CLIENT][REMOTE-SEND] remote=%s seat=%s throttle=%.0f steering=%.0f brake=%s"):format(
		controlRemote:GetFullName(), currentSeat:GetFullName(), throttle, steering, tostring(held.brake)
	))
	controlRemote:FireServer(throttle, steering, held.brake)
end

local function onDriveAction(_, inputState, inputObject)
	local control = keyToControl[inputObject.KeyCode]
	print(("[BLOXY-KART][CLIENT][ACTION] key=%s state=%s mapped=%s seated=%s"):format(
		inputObject.KeyCode.Name, inputState.Name, tostring(control), tostring(currentSeat ~= nil)
	))
	if control then
		if inputState == Enum.UserInputState.Begin then
			held[control] = true
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			held[control] = false
		end
		sendDriveInput()
	end
	return Enum.ContextActionResult.Sink
end

local function isDriveKey(keyCode)
	return keyToControl[keyCode] ~= nil
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if currentSeat and isDriveKey(input.KeyCode) then
		print(("[BLOXY-KART][CLIENT][RAW-KEY] key=%s state=Begin gameProcessed=%s"):format(
			input.KeyCode.Name, tostring(gameProcessed)
		))
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if currentSeat and isDriveKey(input.KeyCode) then
		print(("[BLOXY-KART][CLIENT][RAW-KEY] key=%s state=End gameProcessed=%s"):format(
			input.KeyCode.Name, tostring(gameProcessed)
		))
	end
end)

local function clearDriveInput()
	for key in pairs(held) do
		held[key] = false
	end
	if currentSeat then
		controlRemote:FireServer(0, 0, false)
	end
	ContextActionService:UnbindAction(driveActionName)
end

local function bindCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	local function updateDrivingState()
		local seat = humanoid.SeatPart
		local kart = getKartFromSeat(seat)
		if seat and seat:IsA("VehicleSeat") and kart then
			if currentSeat == seat then
				return
			end
			print(("[BLOXY-KART][CLIENT][SEAT] seated=true seat=%s kart=%s ownerAttribute=%s"):format(
				seat:GetFullName(), kart:GetFullName(), tostring(kart:GetAttribute("OwnerUserId"))
			))
			clearDriveInput()
			currentSeat = seat
			ContextActionService:BindActionAtPriority(
				driveActionName,
				onDriveAction,
				false,
				Enum.ContextActionPriority.High.Value,
				table.unpack(driveKeys)
			)
			print(("[BLOXY-KART][CLIENT][BIND] action=%s keys=W,A,S,D,Up,Down,Left,Right,Space"):format(driveActionName))
			sendDriveInput()
			startDrivingCamera(kart)
		else
			print(("[BLOXY-KART][CLIENT][SEAT] seated=false seatPart=%s"):format(
				humanoid.SeatPart and humanoid.SeatPart:GetFullName() or "nil"
			))
			clearDriveInput()
			currentSeat = nil
			stopDrivingCamera()
		end
	end

	humanoid.Seated:Connect(updateDrivingState)
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(updateDrivingState)
	task.defer(updateDrivingState)
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then
	task.spawn(bindCharacter, player.Character)
end
