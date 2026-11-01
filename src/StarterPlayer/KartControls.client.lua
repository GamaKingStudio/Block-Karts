local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local KartConfig = require(ReplicatedStorage:WaitForChild("KartConfig"))

local remote = ReplicatedStorage:WaitForChild("KartControl")
local raceEvents = ReplicatedStorage:WaitForChild("RaceEvents")
local checkpointPassedRemote = raceEvents:WaitForChild("CheckpointPassed")
local lapCompletedRemote = raceEvents:WaitForChild("LapCompleted")
local wrongWayRemote = raceEvents:WaitForChild("WrongWayStateChanged")
local requestRespawnRemote = raceEvents:WaitForChild("RequestRespawn")

local currentKart = nil
local currentSeat = nil
local currentChassis = nil
local driveForce = nil

local throttleInput = 0
local steerInput = 0
local brakeInput = false
local driftInput = false

local lastSentThrottle = 0
local lastSentSteer = 0
local lastSentBrake = false

local isDrifting = false
local driftStartTime = 0
local miniTurboEndTime = 0
local cameraYaw = 0

-- Escucha de eventos de carrera (Base para el futuro HUD)
checkpointPassedRemote.OnClientEvent:Connect(function(cpIndex, totalCps)
	print(("[BLOXY-KART][CLIENT] Checkpoint: %d / %d"):format(cpIndex, totalCps))
end)

lapCompletedRemote.OnClientEvent:Connect(function(lap, lapTime, isBest)
	print(("[BLOXY-KART][CLIENT] Vuelta %d completada en %.2fs (Mejor Vuelta: %s)"):format(lap, lapTime, tostring(isBest)))
end)

wrongWayRemote.OnClientEvent:Connect(function(isWrongWay)
	if isWrongWay then
		warn("[BLOXY-KART][CLIENT] DIRECCION CONTRARIA! Da la vuelta.")
	else
		print("[BLOXY-KART][CLIENT] Direccion regularizada.")
	end
end)

local function handleRespawnAction(actionName, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin then
		requestRespawnRemote:FireServer()
	end
	return Enum.ContextActionResult.Sink
end

local function handleThrottle(actionName, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin then
		throttleInput = actionName == "ThrottleForward" and 1 or -1
	elseif inputState == Enum.UserInputState.End then
		throttleInput = 0
	end
	return Enum.ContextActionResult.Sink
end

local function handleSteer(actionName, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin then
		steerInput = actionName == "SteerRight" and 1 or -1
	elseif inputState == Enum.UserInputState.End then
		steerInput = 0
	end
	return Enum.ContextActionResult.Sink
end

local function handleBrake(actionName, inputState, inputObject)
	brakeInput = inputState == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink
end

local function handleDrift(actionName, inputState, inputObject)
	driftInput = inputState == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Sink
end

local function bindInputs()
	ContextActionService:BindAction("ThrottleForward", handleThrottle, false, Enum.KeyCode.W, Enum.KeyCode.Up)
	ContextActionService:BindAction("ThrottleBackward", handleThrottle, false, Enum.KeyCode.S, Enum.KeyCode.Down)
	ContextActionService:BindAction("SteerLeft", handleSteer, false, Enum.KeyCode.A, Enum.KeyCode.Left)
	ContextActionService:BindAction("SteerRight", handleSteer, false, Enum.KeyCode.D, Enum.KeyCode.Right)
	ContextActionService:BindAction("Handbrake", handleBrake, false, Enum.KeyCode.Space)
	ContextActionService:BindAction("Drift", handleDrift, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
	ContextActionService:BindAction("RespawnKart", handleRespawnAction, false, Enum.KeyCode.R)
end

local function unbindInputs()
	ContextActionService:UnbindAction("ThrottleForward")
	ContextActionService:UnbindAction("ThrottleBackward")
	ContextActionService:UnbindAction("SteerLeft")
	ContextActionService:UnbindAction("SteerRight")
	ContextActionService:UnbindAction("Handbrake")
	ContextActionService:UnbindAction("Drift")
	ContextActionService:UnbindAction("RespawnKart")
end

local function onSeated(occupant)
	if occupant and occupant.Parent == player.Character then
		bindInputs()
		camera.CameraType = Enum.CameraType.Scriptable
	else
		unbindInputs()
		camera.CameraType = Enum.CameraType.Custom
		throttleInput = 0
		steerInput = 0
		brakeInput = false
		driftInput = false
		isDrifting = false
		lastSentThrottle = 0
		lastSentSteer = 0
		lastSentBrake = false
	end
end

local function setupKartTracking()
	local karts = Workspace:WaitForChild("PlayerKarts", 10)
	if not karts then return end

	local function checkKart(child)
		if child:IsA("Model") and child.Name == "Kart_" .. player.UserId then
			currentKart = child
			currentChassis = child:WaitForChild("Chassis", 5)
			currentSeat = child:WaitForChild("DriverSeat", 5)
			if currentSeat then
				driveForce = currentChassis:WaitForChild("ArcadeDriveForce", 5)
				currentSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
					onSeated(currentSeat.Occupant)
				end)
				if currentSeat.Occupant then
					onSeated(currentSeat.Occupant)
				end
			end
		end
	end

	karts.ChildAdded:Connect(checkKart)
	for _, c in ipairs(karts:GetChildren()) do checkKart(c) end
end

setupKartTracking()

RunService.RenderStepped:Connect(function(dt)
	if not currentChassis or not currentSeat or currentSeat.Occupant ~= (player.Character and player.Character:FindFirstChildOfClass("Humanoid")) then
		return
	end

	-- Aplanamiento de vectores al plano X-Z para evitar impulsos verticales y tunneling
	local rawLook = currentChassis.CFrame.LookVector
	local rawRight = currentChassis.CFrame.RightVector
	local forwardVector = Vector3.new(rawLook.X, 0, rawLook.Z)
	forwardVector = forwardVector.Magnitude > 0 and forwardVector.Unit or Vector3.new(0, 0, -1)
	
	local rightVector = Vector3.new(rawRight.X, 0, rawRight.Z)
	rightVector = rightVector.Magnitude > 0 and rightVector.Unit or Vector3.new(1, 0, 0)

	local velocity = currentChassis.AssemblyLinearVelocity
	local currentSpeed = forwardVector:Dot(velocity)

	local now = os.clock()
	if driftInput and math.abs(currentSpeed) > (KartConfig.DriftMinSpeed or 8) then
		if not isDrifting then
			isDrifting = true
			driftStartTime = now
		end
	else
		if isDrifting then
			local driftDuration = now - driftStartTime
			if driftDuration >= (KartConfig.DriftMinDuration or 0.8) then
				miniTurboEndTime = now + (KartConfig.MiniTurboDuration or 0.75)
			end
			isDrifting = false
		end
	end

	local isTurboActive = now < miniTurboEndTime
	local accelMult = isTurboActive and (KartConfig.MiniTurboAccelMultiplier or 1.45) or 1.0
	local maxSpdMult = isTurboActive and (KartConfig.MiniTurboSpeedMultiplier or 1.25) or 1.0

	local targetForce = Vector3.zero
	local absoluteMaxSpeed = (KartConfig.MaxSpeed or 75) * maxSpdMult * 1.4

	-- Límite absoluto de velocidad físico (Top-Speed Clamping)
	if velocity.Magnitude < absoluteMaxSpeed then
		if throttleInput > 0 then
			if currentSpeed < ((KartConfig.MaxSpeed or 75) * maxSpdMult) then
				targetForce = targetForce + forwardVector * ((KartConfig.ForwardAcceleration or 48) * accelMult * currentChassis.AssemblyMass)
			end
		elseif throttleInput < 0 then
			if currentSpeed > -(KartConfig.ReverseMaxSpeed or 22) then
				targetForce = targetForce - forwardVector * ((KartConfig.ReverseAcceleration or 25) * currentChassis.AssemblyMass)
			end
		end
	end

	-- Límite de fuerza lateral y control de resonancia
	local lateralSpeed = rightVector:Dot(velocity)
	local gripMult = isDrifting and (KartConfig.DriftGripMultiplier or 0.25) or 1.0
	local maxLateralForce = currentChassis.AssemblyMass * 120 -- Tolerancia máxima
	local rawGripForce = -lateralSpeed * (KartConfig.Grip or 18) * gripMult * currentChassis.AssemblyMass
	local safeGripForce = math.clamp(rawGripForce, -maxLateralForce, maxLateralForce)
	targetForce = targetForce + (rightVector * safeGripForce)

	if driveForce and driveForce.Parent then
		driveForce.Force = targetForce
	end

	local steerMult = isDrifting and (KartConfig.DriftSteerMultiplier or 1.6) or 1.0
	currentChassis.AssemblyAngularVelocity = Vector3.new(0, -steerInput * (KartConfig.SteerSpeed or 2.4) * steerMult, 0)
	
	-- Blindaje de cámara y look-ahead acotado
	local clampedSpeedVector = velocity.Magnitude > 90 and (velocity.Unit * 90) or velocity
	local targetLookAt = currentChassis.Position + (clampedSpeedVector * (KartConfig.CameraLookAhead or 0.25))

	local camHeight = Vector3.new(0, KartConfig.CameraHeight or 5.5, 0)
	local camOffset = -forwardVector * (KartConfig.CameraDistance or 14) + camHeight
	local targetCamPos = currentChassis.Position + camOffset

	camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(targetCamPos, targetLookAt), math.clamp(dt * (KartConfig.CameraLerpSpeed or 12), 0, 1))

	if throttleInput ~= lastSentThrottle or steerInput ~= lastSentSteer or brakeInput ~= lastSentBrake then
		lastSentThrottle = throttleInput
		lastSentSteer = steerInput
		lastSentBrake = brakeInput
		remote:FireServer(throttleInput, steerInput, brakeInput)
	end
end)
