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
local raceEvents = ReplicatedStorage:WaitForChild("RaceEvents")
local checkpointPassedRemote = raceEvents:WaitForChild("CheckpointPassed")
local lapCompletedRemote = raceEvents:WaitForChild("LapCompleted")
local wrongWayRemote = raceEvents:WaitForChild("WrongWayStateChanged")
local requestRespawnRemote = raceEvents:WaitForChild("RequestRespawn")

checkpointPassedRemote.OnClientEvent:Connect(function(cpIndex, totalCps)
	print(("[BLOXY-KART][RACE] Checkpoint %d / %d"):format(cpIndex, totalCps))
end)
lapCompletedRemote.OnClientEvent:Connect(function(lap, lapTime, isBest)
	print(("[BLOXY-KART][RACE] Vuelta %d: %.2fs (mejor: %s)"):format(lap, lapTime, tostring(isBest)))
end)
wrongWayRemote.OnClientEvent:Connect(function(isWrongWay)
	if isWrongWay then warn("[BLOXY-KART][RACE] DIRECCIÓN CONTRARIA") end
end)
local function onRespawnAction(_, inputState)
	if inputState == Enum.UserInputState.Begin then requestRespawnRemote:FireServer() end
	return Enum.ContextActionResult.Sink
end

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
local drivingBaseFieldOfView
local shownEnterPrompt
local enterPromptBillboard
local held = { forward = false, reverse = false, left = false, right = false, brake = false }
local driftHeld = false
local isDrifting = false
local driftStartTime = 0
local miniTurboEndTime = 0
local driveActionName = "BLOXYKartDriveControls"
local driveKeys = {
	Enum.KeyCode.W, Enum.KeyCode.Up,
	Enum.KeyCode.S, Enum.KeyCode.Down,
	Enum.KeyCode.A, Enum.KeyCode.Left,
	Enum.KeyCode.D, Enum.KeyCode.Right,
	Enum.KeyCode.Space, Enum.KeyCode.R, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift,
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
		if drivingBaseFieldOfView then
			activeCamera.FieldOfView = drivingBaseFieldOfView
			drivingBaseFieldOfView = nil
		end
		if wasDrivingCamera then
			print(("[BLOXY-KART][CLIENT][CAMERA-RESTORE] type=%s subject=%s"):format(
				activeCamera.CameraType.Name, activeCamera.CameraSubject and activeCamera.CameraSubject:GetFullName() or "nil"
			))
		end
	end
end

local function startDrivingCamera(kart)
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	camera = Workspace.CurrentCamera
	if not camera then
		warn("[BLOXY-KART][CLIENT][CAMERA-MISSING] Workspace.CurrentCamera no está disponible.")
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	drivingBaseFieldOfView = camera.FieldOfView
	local baseFieldOfView = drivingBaseFieldOfView
	local smoothedFieldOfView = baseFieldOfView
	local smoothedCFrame = camera.CFrame
	print(("[BLOXY-KART][CLIENT][CAMERA-DRIVE] type=%s offset=%s lookAhead=%.1f"):format(
		camera.CameraType.Name, tostring(KartConfig.CameraOffset), KartConfig.CameraLookAhead
	))
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
		local forwardSpeed = math.abs(chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector))
		local speedRatio = math.clamp(forwardSpeed / math.max(KartConfig.MaxForwardSpeed, 1), 0, 1)
		local targetFieldOfView = baseFieldOfView + (6 * speedRatio)
		local fovAlpha = 1 - math.exp(-3.5 * deltaTime)
		smoothedFieldOfView = smoothedFieldOfView + (targetFieldOfView - smoothedFieldOfView) * fovAlpha
		camera.FieldOfView = smoothedFieldOfView
		camera.CFrame = smoothedCFrame
		camera.Focus = CFrame.new(focus)
	end)
end

local function formatVector(vector)
	if not vector then
		return "nil"
	end
	return string.format("(%.2f,%.2f,%.2f)", vector.X, vector.Y, vector.Z)
end

local function describePartVisibility(part)
	if not part then
		return "missing"
	end
	return string.format("%s(t=%.2f,ltm=%.2f)", part.Name, part.Transparency, part.LocalTransparencyModifier)
end

local function describePartGeometry(part)
	if not part then
		return "missing"
	end
	if part:IsA("MeshPart") then
		return string.format("MeshPart(mesh=%s,texture=%s)", part.MeshId, part.TextureID)
	end
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		return string.format("%s/SpecialMesh(mesh=%s,texture=%s)", part.ClassName, mesh.MeshId, mesh.TextureId)
	end
	return part.ClassName
end

local function describeViewportPoint(camera, part)
	if not camera or not part then
		return "unavailable"
	end
	local point, insideViewport = camera:WorldToViewportPoint(part.Position)
	return string.format("inside=%s(x=%.0f,y=%.0f,z=%.2f)", tostring(insideViewport), point.X, point.Y, point.Z)
end

local function logSeatedAvatar(humanoid, seat)
	local character = humanoid.Parent
	if not character then
		return
	end
	local kart = getKartFromSeat(seat)
	local chassis = kart and kart.PrimaryPart
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local visibleParts = 0
	local totalParts = 0
	local accessoryCount = 0
	local hiddenParts = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Accessory") then
			accessoryCount = accessoryCount + 1
		elseif descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			totalParts = totalParts + 1
			if descendant.Transparency < 1 and descendant.LocalTransparencyModifier < 1 then
				visibleParts = visibleParts + 1
			elseif #hiddenParts < 8 then
				table.insert(hiddenParts, string.format("%s(t=%.2f,ltm=%.2f)", descendant.Name, descendant.Transparency, descendant.LocalTransparencyModifier))
			end
		end
	end
	local seatWeld = seat:FindFirstChild("SeatWeld")
	local rootSeatOffset = root and seat.CFrame:PointToObjectSpace(root.Position)
	local rootChassisOffset = root and chassis and chassis.CFrame:PointToObjectSpace(root.Position)
	local seatChassisOffset = chassis and chassis.CFrame:PointToObjectSpace(seat.Position)
	local facingDot = chassis and seat.CFrame.LookVector:Dot(chassis.CFrame.LookVector) or 0
	local occupant = seat.Occupant
	local camera = Workspace.CurrentCamera
	local function getCameraBlocker(targetPart)
		if not camera or not targetPart then
			return "unavailable", false
		end
		local direction = targetPart.Position - camera.CFrame.Position
		if direction.Magnitude < 0.001 then
			return "camera-at-target", false
		end
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { character }
		local result = Workspace:Raycast(camera.CFrame.Position, direction, raycastParams)
		if result then
			return result.Instance:GetFullName(), kart ~= nil and result.Instance:IsDescendantOf(kart)
		end
		return "none", false
	end
	local headBlocker, headBlockedByKart = getCameraBlocker(head)
	local torsoBlocker, torsoBlockedByKart = getCameraBlocker(torso)
	local headVisible = head ~= nil and head.Transparency < 1 and head.LocalTransparencyModifier < 1
	local torsoVisible = torso ~= nil and torso.Transparency < 1 and torso.LocalTransparencyModifier < 1
	print(("[BLOXY-KART][CLIENT][AVATAR-SEATED] humanoidSit=%s occupant=%s seatWeld=%s seatKartOffset=%s facingDot=%.2f rootSeatOffset=%s rootChassisOffset=%s root=%s head=%s headVisible=%s torso=%s torsoVisible=%s visibleParts=%d/%d accessories=%d hiddenParts=%s headBlocker=%s headBlockedByKart=%s torsoBlocker=%s torsoBlockedByKart=%s"):format(
		tostring(humanoid.Sit), occupant and occupant.Parent and occupant.Parent.Name or "nil", tostring(seatWeld ~= nil),
		formatVector(seatChassisOffset), facingDot, formatVector(rootSeatOffset), formatVector(rootChassisOffset),
		describePartVisibility(root), describePartVisibility(head), tostring(headVisible), describePartVisibility(torso), tostring(torsoVisible),
		visibleParts, totalParts, accessoryCount, #hiddenParts == 0 and "none" or table.concat(hiddenParts, ";"),
		headBlocker, tostring(headBlockedByKart), torsoBlocker, tostring(torsoBlockedByKart)
	))
	local characterParent = character.Parent
	local cameraSubject = camera and camera.CameraSubject
	print(("[BLOXY-KART][CLIENT][AVATAR-RENDER] character=%s parent=%s characterInWorkspace=%s isLocalCharacter=%s rootInWorkspace=%s headInWorkspace=%s torsoInWorkspace=%s rig=%s state=%s health=%.1f platformStand=%s cameraType=%s cameraSubject=%s cameraPos=%s cameraLook=%s cameraFocus=%s viewport=(%.0f,%.0f) fov=%.1f headWorld=%s headScreen=%s headGeometry=%s torsoWorld=%s torsoScreen=%s torsoGeometry=%s"):format(
		character:GetFullName(), characterParent and characterParent:GetFullName() or "nil", tostring(character:IsDescendantOf(Workspace)),
		tostring(player.Character == character), tostring(root ~= nil and root:IsDescendantOf(Workspace)),
		tostring(head ~= nil and head:IsDescendantOf(Workspace)), tostring(torso ~= nil and torso:IsDescendantOf(Workspace)),
		humanoid.RigType.Name, humanoid:GetState().Name, humanoid.Health, tostring(humanoid.PlatformStand),
		camera and camera.CameraType.Name or "missing", cameraSubject and cameraSubject:GetFullName() or "nil",
		formatVector(camera and camera.CFrame.Position), formatVector(camera and camera.CFrame.LookVector),
		formatVector(camera and camera.Focus.Position), camera and camera.ViewportSize.X or 0, camera and camera.ViewportSize.Y or 0,
		camera and camera.FieldOfView or 0, formatVector(head and head.Position), describeViewportPoint(camera, head), describePartGeometry(head),
		formatVector(torso and torso.Position), describeViewportPoint(camera, torso), describePartGeometry(torso)
	))
end

local function sendDriveInput()
	if not currentSeat then
		return
	end
	local canDrive = player:GetAttribute("RaceStarted") == true
	local throttle = canDrive and ((held.forward and 1 or 0) - (held.reverse and 1 or 0)) or 0
	local steering = canDrive and ((held.right and 1 or 0) - (held.left and 1 or 0)) or 0
	controlRemote:FireServer(throttle, steering, held.brake)
end

local driftSmokeKart
local driftSmokeEmitters = {}

local function clearDriftSmoke()
	for _, emitter in ipairs(driftSmokeEmitters) do
		emitter.Enabled = false
		emitter:Destroy()
	end
	table.clear(driftSmokeEmitters)
	driftSmokeKart = nil
end

local function setupDriftSmoke(kart)
	if driftSmokeKart == kart then return end
	clearDriftSmoke()
	driftSmokeKart = kart
	for _, wheelName in ipairs({ "Wheel_RearL", "Wheel_RearR" }) do
		local wheel = kart:FindFirstChild(wheelName, true)
		if wheel and wheel:IsA("BasePart") then
			local attachment = Instance.new("Attachment")
			attachment.Name = "LocalDriftSmokeAttachment"
			attachment.Position = Vector3.new(0, -wheel.Size.Y * 0.38, 0)
			attachment.Parent = wheel
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "LocalDriftSmoke"
			emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
			emitter.Enabled = false
			emitter.Rate = 90
			emitter.Lifetime = NumberRange.new(0.75, 1.2)
			emitter.Speed = NumberRange.new(0.6, 1.8)
			emitter.SpreadAngle = Vector2.new(38, 38)
			emitter.EmissionDirection = Enum.NormalId.Top
			emitter.Acceleration = Vector3.new(0, 2.2, 0)
			emitter.Drag = 3
			emitter.RotSpeed = NumberRange.new(-30, 30)
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.75),
				NumberSequenceKeypoint.new(0.45, 1.35),
				NumberSequenceKeypoint.new(1, 1.9),
			})
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.12),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(225, 228, 232))
			emitter.LightInfluence = 0
			emitter.LightEmission = 0.12
			emitter.Parent = attachment
			table.insert(driftSmokeEmitters, emitter)
		end
	end
	if #driftSmokeEmitters == 0 then
		warn(("[BLOXY-KART][CLIENT][DRIFT-SMOKE-WHEELS-MISSING] kart=%s"):format(kart:GetFullName()))
	end
end

local physicsDiagnosticNext = 0
local lastPhysicsPosition = {}
local function simulateOwnedKart()
	if not currentSeat then
		return
	end
	local kart = getKartFromSeat(currentSeat)
	if kart then setupDriftSmoke(kart) end
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
	local canDrive = player:GetAttribute("RaceStarted") == true
	local throttle = canDrive and ((held.forward and 1 or 0) - (held.reverse and 1 or 0)) or 0
	local steering = canDrive and ((held.right and 1 or 0) - (held.left and 1 or 0)) or 0
	local speedForSteering = math.max(math.abs(forwardSpeed) - KartConfig.MinimumSteeringSpeed, 0)
	local steeringFactor = math.clamp(speedForSteering / 12, 0, 1)
	local travelDirection = forwardSpeed >= 0 and 1 or -1
	local driftYawMultiplier = isDrifting and (KartConfig.DriftYawMultiplier or 1.6) or 1
	local yawRate = -steering * KartConfig.SteeringRate * steeringFactor * travelDirection * driftYawMultiplier
	chassis.AssemblyAngularVelocity = Vector3.new(0, yawRate, 0)

	local now = os.clock()
	local driftMinSpeed = KartConfig.DriftMinSpeed or 8
	if driftHeld and math.abs(forwardSpeed) > driftMinSpeed and not isDrifting then
		isDrifting = true
		driftStartTime = now
	elseif not driftHeld and isDrifting then
		local driftDuration = now - driftStartTime
		isDrifting = false
		if driftDuration >= (KartConfig.DriftMinDuration or 0.8) then
			miniTurboEndTime = now + (KartConfig.MiniTurboDuration or 0.75)
		end
	end
	local miniTurboActive = now < miniTurboEndTime
	for _, emitter in ipairs(driftSmokeEmitters) do
		emitter.Enabled = isDrifting
	end

	local acceleration = 0
	if held.brake then
		acceleration = -math.sign(forwardSpeed) * KartConfig.BrakeDeceleration
	elseif throttle > 0 then
		local turboMultiplier = miniTurboActive and (KartConfig.MiniTurboAccelerationMultiplier or 1.45) or 1
		acceleration = KartConfig.ForwardAcceleration * turboMultiplier
	elseif throttle < 0 then
		if forwardSpeed > 2 then
			acceleration = -KartConfig.BrakeDeceleration * 0.65
		else
			acceleration = -KartConfig.ReverseAcceleration
		end
	end

	local drag = -forwardSpeed * KartConfig.CoastDrag
	local lateralForce
	if isDrifting then
		local gripMultiplier = KartConfig.DriftGripMultiplier or 0.25
		local lateralSpeedRatio = KartConfig.DriftLateralSpeedRatio or 0.22
		local targetLateralSpeed = steering * math.abs(forwardSpeed) * lateralSpeedRatio
		lateralForce = (targetLateralSpeed - lateralSpeed) * KartConfig.LateralGrip * gripMultiplier
	else
		lateralForce = -lateralSpeed * KartConfig.LateralGrip
	end
	driveForce.Force = forward * ((acceleration + drag) * chassis.AssemblyMass)
		+ right * (lateralForce * chassis.AssemblyMass)

	local normalMaxSpeed = (throttle < 0 and forwardSpeed <= 2) and KartConfig.MaxReverseSpeed or KartConfig.MaxForwardSpeed
	local maxSpeed = miniTurboActive and throttle > 0 and normalMaxSpeed * (KartConfig.MiniTurboMaxSpeedMultiplier or 1.25) or normalMaxSpeed
	if math.abs(forwardSpeed) > maxSpeed then
		local clamped = math.sign(forwardSpeed) * maxSpeed
		chassis.AssemblyLinearVelocity = forward * clamped + right * lateralSpeed + Vector3.new(0, velocity.Y, 0)
	end

	if false and os.clock() >= physicsDiagnosticNext then
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
	if inputObject.KeyCode == Enum.KeyCode.R and inputState == Enum.UserInputState.Begin then
		requestRespawnRemote:FireServer()
		return Enum.ContextActionResult.Sink
	end
	if inputObject.KeyCode == Enum.KeyCode.LeftShift or inputObject.KeyCode == Enum.KeyCode.RightShift then
		if inputState == Enum.UserInputState.Begin then
			driftHeld = true
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			driftHeld = false
		end
		return Enum.ContextActionResult.Sink
	end
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
	clearDriftSmoke()
	for key in pairs(held) do
		held[key] = false
	end
	driftHeld = false
	isDrifting = false
	driftStartTime = 0
	miniTurboEndTime = 0
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
			print(("[BLOXY-KART][CLIENT][BIND] action=%s keys=W,A,S,D,Up,Down,Left,Right,Space"):format(driveActionName))
			sendDriveInput()
			startDrivingCamera(kart)
			task.delay(0.4, function()
				if currentSeat == seat and humanoid.Parent == character then
					logSeatedAvatar(humanoid, seat)
				end
			end)
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
