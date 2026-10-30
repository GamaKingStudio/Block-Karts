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

local physicsDiagnosticNext = 0
local lastPhysicsPosition = {}
local function simulateOwnedKart()
	if not currentSeat then
		return
	end
	local kart = getKartFromSeat(currentSeat)
	if not kart or kart:GetAttribute("NetworkOwnerUserId") ~= player.UserId then
		return
	end
	local chassis = kart and kart.PrimaryPart
	local driveForce = chassis and chassis:FindFirstChild("ArcadeDriveForce")
	if not chassis or not driveForce or not driveForce:IsA("VectorForce") then
		warn(("[BLOXY-KART][CLIENT][PHYSICS-MISSING] seat=%s kart=%s chassis=%s force=%s"):format(
			currentSeat:GetFullName(), kart and kart:GetFullName() or "nil",
			chassis and chassis:GetFullName() or "nil", driveForce and driveForce:GetFullName() or "nil"
		))
		return
	end
	if not driveForce.Attachment0 then
		warn(("[BLOXY-KART][CLIENT][FORCE-ATTACHMENT-MISSING] force=%s"):format(driveForce:GetFullName()))
		return
	end

	local velocity = chassis.AssemblyLinearVelocity
	local lookVector = chassis.CFrame.LookVector
	local forward = Vector3.new(lookVector.X, 0, lookVector.Z)
	if forward.Magnitude > 0.001 then
		forward = forward.Unit
	else
		forward = Vector3.new(0, 0, -1)
	end
	local rightVector = chassis.CFrame.RightVector
	local right = Vector3.new(rightVector.X, 0, rightVector.Z)
	if right.Magnitude > 0.001 then
		right = right.Unit
	else
		right = Vector3.new(1, 0, 0)
	end
	local forwardSpeed = velocity:Dot(forward)
	local lateralSpeed = velocity:Dot(right)
	local throttle = (held.forward and 1 or 0) - (held.reverse and 1 or 0)
	local steering = (held.right and 1 or 0) - (held.left and 1 or 0)
	local speedForSteering = math.max(math.abs(forwardSpeed) - KartConfig.MinimumSteeringSpeed, 0)
	local steeringFactor = math.clamp(speedForSteering / 12, 0, 1)
	local travelDirection = forwardSpeed >= 0 and 1 or -1
	local yawRate = steering * KartConfig.SteeringRate * steeringFactor * travelDirection
	chassis.AssemblyAngularVelocity = Vector3.new(0, yawRate, 0)

	local acceleration = 0
	if held.brake then
		acceleration = -math.sign(forwardSpeed) * KartConfig.BrakeDeceleration
	elseif throttle > 0 then
		acceleration = KartConfig.ForwardAcceleration
	elseif throttle < 0 then
		if forwardSpeed > 2 then
			acceleration = -KartConfig.BrakeDeceleration * 0.65
		else
			acceleration = -KartConfig.ReverseAcceleration
		end
	end

	local drag = -forwardSpeed * KartConfig.CoastDrag
	local lateralForce = -lateralSpeed * KartConfig.LateralGrip
	driveForce.Force = forward * ((acceleration + drag) * chassis.AssemblyMass)
		+ right * (lateralForce * chassis.AssemblyMass)

	local maxSpeed = (throttle < 0 and forwardSpeed <= 2) and KartConfig.MaxReverseSpeed or KartConfig.MaxForwardSpeed
	if math.abs(forwardSpeed) > maxSpeed then
		local clamped = math.sign(forwardSpeed) * maxSpeed
		chassis.AssemblyLinearVelocity = forward * clamped + right * lateralSpeed + Vector3.new(0, velocity.Y, 0)
	end

	if os.clock() >= physicsDiagnosticNext then
		physicsDiagnosticNext = os.clock() + 2
		local root = chassis.AssemblyRootPart or chassis
		local characterRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local sharesAssembly = characterRoot ~= nil and characterRoot.AssemblyRootPart == root
		local seatWeld = currentSeat:FindFirstChild("SeatWeld")
		local chassisProperties = chassis.CurrentPhysicalProperties
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { kart, player.Character }
		local groundHit = Workspace:Raycast(chassis.Position, Vector3.new(0, -(chassis.Size.Y * 0.5 + 2), 0), raycastParams)
		local ground = groundHit and groundHit.Instance
		local groundProperties = ground and ground:IsA("BasePart") and ground.CurrentPhysicalProperties or nil
		local combinedFriction = -1
		if groundProperties then
			local totalFrictionWeight = chassisProperties.FrictionWeight + groundProperties.FrictionWeight
			if totalFrictionWeight > 0 then
				combinedFriction = (chassisProperties.Friction * chassisProperties.FrictionWeight
					+ groundProperties.Friction * groundProperties.FrictionWeight) / totalFrictionWeight
			end
		end
		local estimatedFrictionAccelerationLimit = combinedFriction >= 0 and combinedFriction * Workspace.Gravity or -1
		local forwardAcceleration = driveForce.Force:Dot(forward) / math.max(chassis.AssemblyMass, 0.001)
		local previousPosition = lastPhysicsPosition[kart] or chassis.Position
		local distance = (chassis.Position - previousPosition).Magnitude
		lastPhysicsPosition[kart] = chassis.Position
		local anchoredParts = {}
		for _, part in ipairs(kart:GetDescendants()) do
			if part:IsA("BasePart") and part.AssemblyRootPart == root and part.Anchored then
				table.insert(anchoredParts, part.Name)
			end
		end
		print(("[BLOXY-KART][CLIENT][PHYSICS] input=(%.0f,%.0f,%s) chassis=%s chassisAnchored=%s root=%s rootAnchored=%s characterRoot=%s sharesAssembly=%s seatWeld=%s anchoredAssemblyParts=%s mass=%.2f forward=(%.2f,%.2f,%.2f) forwardSpeed=%.2f force=(%.1f,%.1f,%.1f) forceMagnitude=%.1f forwardAcceleration=%.2f forceEnabled=%s attachment=%s applyAtCenter=%s chassisFriction=%.3f chassisFrictionWeight=%.2f ground=%s groundMaterial=%s groundFriction=%.3f groundFrictionWeight=%.2f estimatedFrictionAccelerationLimit=%.2f gravity=%.1f speed=%.2f distance2s=%.2f angular=(%.2f,%.2f,%.2f)"):format(
			throttle, steering, tostring(held.brake), chassis:GetFullName(), tostring(chassis.Anchored),
			root:GetFullName(), tostring(root.Anchored), characterRoot and characterRoot:GetFullName() or "nil",
			tostring(sharesAssembly), tostring(seatWeld ~= nil), #anchoredParts > 0 and table.concat(anchoredParts, ",") or "none",
			chassis.AssemblyMass, forward.X, forward.Y, forward.Z, forwardSpeed,
			driveForce.Force.X, driveForce.Force.Y, driveForce.Force.Z, driveForce.Force.Magnitude,
			forwardAcceleration, tostring(driveForce.Enabled),
			driveForce.Attachment0:GetFullName(), tostring(driveForce.ApplyAtCenterOfMass),
			chassisProperties.Friction, chassisProperties.FrictionWeight,
			ground and ground:GetFullName() or "none", groundHit and groundHit.Material.Name or "none",
			groundProperties and groundProperties.Friction or -1,
			groundProperties and groundProperties.FrictionWeight or -1,
			estimatedFrictionAccelerationLimit, Workspace.Gravity, chassis.AssemblyLinearVelocity.Magnitude, distance,
			chassis.AssemblyAngularVelocity.X,
			chassis.AssemblyAngularVelocity.Y, chassis.AssemblyAngularVelocity.Z
		))
	end
end

RunService.Heartbeat:Connect(simulateOwnedKart)

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
