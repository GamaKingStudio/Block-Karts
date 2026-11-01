local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
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
local shownEnterPrompt
local enterPromptBillboard

-- Controles con soporte para Shift (Derrape)
local held = { forward = false, reverse = false, left = false, right = false, brake = false, drift = false }
local driveActionName = "BLOXYKartDriveControls"
local driveKeys = {
	Enum.KeyCode.W, Enum.KeyCode.Up,
	Enum.KeyCode.S, Enum.KeyCode.Down,
	Enum.KeyCode.A, Enum.KeyCode.Left,
	Enum.KeyCode.D, Enum.KeyCode.Right,
	Enum.KeyCode.Space,
	Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift,
}
local keyToControl = {
	[Enum.KeyCode.W] = "forward", [Enum.KeyCode.Up] = "forward",
	[Enum.KeyCode.S] = "reverse", [Enum.KeyCode.Down] = "reverse",
	[Enum.KeyCode.A] = "left", [Enum.KeyCode.Left] = "left",
	[Enum.KeyCode.D] = "right", [Enum.KeyCode.Right] = "right",
	[Enum.KeyCode.Space] = "brake",
	[Enum.KeyCode.LeftShift] = "drift",
	[Enum.KeyCode.RightShift] = "drift",
}

-- Variables de estado de derrape y turbo
local isDrifting = false
local driftDirection = 0
local driftStartTime = 0
local boostEndTime = 0

local function getKartFromSeat(seat)
	local model = seat and seat:FindFirstAncestorOfClass("Model")
	if model and model:GetAttribute("OwnerUserId") == player.UserId then
		return model
	end
	return nil
end

local function hideEnterPrompt(prompt)
	if prompt and shownEnterPrompt ~= prompt then
		return
	end
	if enterPromptBillboard then
		enterPromptBillboard:Destroy()
		enterPromptBillboard = nil
	end
	shownEnterPrompt = nil
end

local function showEnterPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") or prompt.Name ~= "EnterKartPrompt" or currentSeat then
		return
	end
	local seat = prompt.Parent
	if not seat or not seat:IsA("VehicleSeat") or seat.Occupant or not getKartFromSeat(seat) then
		return
	end
	hideEnterPrompt()
	shownEnterPrompt = prompt

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BLOXYKartEnterHint"
	billboard.Adornee = seat
	billboard.Size = UDim2.fromOffset(132, 36)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = prompt.MaxActivationDistance
	local frame = Instance.new("Frame")
	frame.Name = "Pill"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(25, 29, 36)
	frame.BackgroundTransparency = 0.12
	frame.Parent = billboard
	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 8)
	frameCorner.Parent = frame
	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.fromRGB(255, 197, 72)
	frameStroke.Thickness = 1
	frameStroke.Transparency = 0.2
	frameStroke.Parent = frame

	local keyBadge = Instance.new("TextLabel")
	keyBadge.Name = "Key"
	keyBadge.Position = UDim2.fromOffset(5, 5)
	keyBadge.Size = UDim2.fromOffset(27, 26)
	keyBadge.BackgroundColor3 = Color3.fromRGB(255, 197, 72)
	keyBadge.Text = "E"
	keyBadge.TextColor3 = Color3.fromRGB(28, 30, 34)
	keyBadge.TextSize = 16
	keyBadge.Font = Enum.Font.GothamBold
	keyBadge.Parent = frame
	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(0, 5)
	keyCorner.Parent = keyBadge

	local actionLabel = Instance.new("TextLabel")
	actionLabel.Name = "Action"
	actionLabel.Position = UDim2.fromOffset(40, 0)
	actionLabel.Size = UDim2.new(1, -44, 1, 0)
	actionLabel.BackgroundTransparency = 1
	actionLabel.Text = "Conducir"
	actionLabel.TextColor3 = Color3.fromRGB(245, 246, 248)
	actionLabel.TextSize = 14
	actionLabel.TextXAlignment = Enum.TextXAlignment.Left
	actionLabel.Font = Enum.Font.GothamMedium
	actionLabel.Parent = frame

	billboard.Parent = player:WaitForChild("PlayerGui")
	enterPromptBillboard = billboard
end

ProximityPromptService.PromptShown:Connect(showEnterPrompt)
ProximityPromptService.PromptHidden:Connect(hideEnterPrompt)

local function stopDrivingCamera()
	local wasDrivingCamera = cameraConnection ~= nil or (camera and camera.CameraType == Enum.CameraType.Scriptable)
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	local activeCamera = Workspace.CurrentCamera
	if activeCamera then
		camera = activeCamera
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			activeCamera.CameraSubject = humanoid
		end
		activeCamera.CameraType = Enum.CameraType.Custom
	end
end

local function startDrivingCamera(kart)
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	camera = Workspace.CurrentCamera
	if not camera then return end
	camera.CameraType = Enum.CameraType.Scriptable
	local smoothedCFrame = camera.CFrame
	cameraConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if not kart.Parent or not kart.PrimaryPart then
			stopDrivingCamera()
			return
		end
		local chassis = kart.PrimaryPart
		local focus = chassis.Position + chassis.CFrame.LookVector * KartConfig.CameraLookAhead + Vector3.new(0, 1.5, 0)
		local desiredPosition = (chassis.CFrame * CFrame.new(KartConfig.CameraOffset)).Position
		local desiredCFrame = CFrame.lookAt(desiredPosition, focus)
		local alpha = 1 - math.exp(-6 * deltaTime)
		smoothedCFrame = smoothedCFrame:Lerp(desiredCFrame, alpha)
		camera.CFrame = smoothedCFrame
		camera.Focus = CFrame.new(focus)
	end)
end

local function sendDriveInput()
	if not currentSeat then return end
	local throttle = (held.forward and 1 or 0) - (held.reverse and 1 or 0)
	local steering = (held.right and 1 or 0) - (held.left and 1 or 0)
	controlRemote:FireServer(throttle, steering, held.brake)
end

local physicsDiagnosticNext = 0
local function simulateOwnedKart()
	if not currentSeat then return end
	local kart = getKartFromSeat(currentSeat)
	if not kart or kart:GetAttribute("NetworkOwnerUserId") ~= player.UserId then return end
	local chassis = kart and kart.PrimaryPart
	local driveForce = chassis and chassis:FindFirstChild("ArcadeDriveForce")
	if not chassis or not driveForce or not driveForce:IsA("VectorForce") or not driveForce.Attachment0 then return end

	local velocity = chassis.AssemblyLinearVelocity
	local lookVector = chassis.CFrame.LookVector
	local forward = Vector3.new(lookVector.X, 0, lookVector.Z)
	forward = (forward.Magnitude > 0.001) and forward.Unit or Vector3.new(0, 0, -1)

	local rightVector = chassis.CFrame.RightVector
	local right = Vector3.new(rightVector.X, 0, rightVector.Z)
	right = (right.Magnitude > 0.001) and right.Unit or Vector3.new(1, 0, 0)

	local forwardSpeed = velocity:Dot(forward)
	local lateralSpeed = velocity:Dot(right)
	local throttle = (held.forward and 1 or 0) - (held.reverse and 1 or 0)
	local steering = (held.right and 1 or 0) - (held.left and 1 or 0)

	-- ==========================================================
	-- GESTIÓN DEL DERRAPE (DRIFT CON SHIFT)
	-- ==========================================================
	local canDrift = (forwardSpeed > 8) and (not held.brake)
	if held.drift and canDrift then
		if not isDrifting then
			isDrifting = true
			driftStartTime = os.clock()
			driftDirection = (steering ~= 0) and math.sign(steering) or 1
		end
	else
		if isDrifting then
			-- Mini-turbo si derrapaste más de 0.8 segundos
			local driftDuration = os.clock() - driftStartTime
			if driftDuration >= 0.8 then
				boostEndTime = os.clock() + 0.75 -- 0.75s de impulso
			end
			isDrifting = false
			driftDirection = 0
		end
	end

	-- Rotación angular (Yaw Rate)
	local speedForSteering = math.max(math.abs(forwardSpeed) - KartConfig.MinimumSteeringSpeed, 0)
	local steeringFactor = math.clamp(speedForSteering / 12, 0, 1)
	local travelDirection = (forwardSpeed >= 0) and 1 or -1

	local yawRate = 0
	if isDrifting then
		-- Derrape: mayor rotación y apoyo de dirección asistida
		local driftSteerRate = KartConfig.SteeringRate * 1.6
		local effectiveSteer = (steering ~= 0) and steering or (driftDirection * 0.5)
		yawRate = -effectiveSteer * driftSteerRate * steeringFactor * travelDirection
	else
		yawRate = -steering * KartConfig.SteeringRate * steeringFactor * travelDirection
	end
	chassis.AssemblyAngularVelocity = Vector3.new(0, yawRate, 0)

	-- Aceleración y Frenado
	local isBoosting = (os.clock() < boostEndTime)
	local acceleration = 0
	if held.brake then
		acceleration = -math.sign(forwardSpeed) * KartConfig.BrakeDeceleration
	elseif throttle > 0 then
		acceleration = KartConfig.ForwardAcceleration
		if isBoosting then
			acceleration = acceleration * 1.45 -- Impulso de mini-turbo
		end
	elseif throttle < 0 then
		if forwardSpeed > 2 then
			acceleration = -KartConfig.BrakeDeceleration * 0.65
		else
			acceleration = -KartConfig.ReverseAcceleration
		end
	end

	-- Agarre lateral: durante el derrape baja al 25% para resbalar
	local gripMultiplier = isDrifting and 0.25 or 1.0
	local drag = -forwardSpeed * KartConfig.CoastDrag
	local lateralForce = -lateralSpeed * (KartConfig.LateralGrip * gripMultiplier)

	driveForce.Force = forward * ((acceleration + drag) * chassis.AssemblyMass)
		+ right * (lateralForce * chassis.AssemblyMass)

	-- Límite de velocidad
	local maxSpeed = (throttle < 0 and forwardSpeed <= 2) and KartConfig.MaxReverseSpeed or KartConfig.MaxForwardSpeed
	if isBoosting then
		maxSpeed = maxSpeed * 1.25
	end

	if math.abs(forwardSpeed) > maxSpeed then
		local clamped = math.sign(forwardSpeed) * maxSpeed
		chassis.AssemblyLinearVelocity = forward * clamped + right * lateralSpeed + Vector3.new(0, velocity.Y, 0)
	end
end

RunService.Heartbeat:Connect(simulateOwnedKart)

local function onDriveAction(_, inputState, inputObject)
	local control = keyToControl[inputObject.KeyCode]
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

local function clearDriveInput()
	for key in pairs(held) do
		held[key] = false
	end
	isDrifting = false
	driftDirection = 0
	boostEndTime = 0
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
			if currentSeat == seat then return end
			hideEnterPrompt()
			clearDriveInput()
			currentSeat = seat
			ContextActionService:BindActionAtPriority(
				driveActionName,
				onDriveAction,
				false,
				Enum.ContextActionPriority.High.Value,
				table.unpack(driveKeys)
			)
			sendDriveInput()
			startDrivingCamera(kart)
		else
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