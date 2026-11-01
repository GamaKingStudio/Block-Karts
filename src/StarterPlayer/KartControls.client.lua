local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
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
		warn("[BLOXY-KART][CLIENT] ¡DIRECCIÓN CONTRARIA! Da la vuelta.")
	else
		print("[BLOXY-KART][CLIENT] Dirección regularizada.")
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
	else
		unbindInputs()
		throttleInput = 0
		steerInput = 0
		brakeInput = false
		driftInput = false
		isDrifting = false
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

	-- Lógica de conducción local delegada
	local forwardVector = currentChassis.CFrame.LookVector
	local rightVector = currentChassis.CFrame.RightVector
	local velocity = currentChassis.AssemblyLinearVelocity
	local currentSpeed = forwardVector:Dot(velocity)

	-- Mecánica de derrape
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

	-- Cálculo de fuerzas en chassis
	local targetForce = Vector3.zero
	if throttleInput > 0 then
		if currentSpeed < (KartConfig.MaxSpeed * maxSpdMult) then
			targetForce = targetForce + forwardVector * (KartConfig.ForwardAcceleration * accelMult * currentChassis.AssemblyMass)
		end
	elseif throttleInput < 0 then
		if currentSpeed > -KartConfig.ReverseMaxSpeed then
			targetForce = targetForce - forwardVector * (KartConfig.ReverseAcceleration * currentChassis.AssemblyMass)
		end
	end

	-- Cancelación de deslizamiento lateral (Grip)
	local lateralSpeed = rightVector:Dot(velocity)
	local gripMult = isDrifting and (KartConfig.DriftGripMultiplier or 0.25) or 1.0
	local gripForce = -rightVector * (lateralSpeed * KartConfig.Grip * gripMult * currentChassis.AssemblyMass)
	targetForce = targetForce + gripForce

	if driveForce and driveForce.Parent then
		driveForce.Force = targetForce
	end

	-- Dirección angular
	local steerMult = isDrifting and (KartConfig.DriftSteerMultiplier or 1.6) or 1.0
	currentChassis.AssemblyAngularVelocity = Vector3.new(0, -steerInput * KartConfig.SteerSpeed * steerMult, 0)

	remote:FireServer(throttleInput, steerInput, brakeInput)
end)