local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local KartConfig = require(ReplicatedStorage:WaitForChild("KartConfig"))

local remote = ReplicatedStorage:FindFirstChild("KartControl")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "KartControl"
	remote.Parent = ReplicatedStorage
end

local kartsFolder = Workspace:FindFirstChild("PlayerKarts") or Instance.new("Folder")
kartsFolder.Name = "PlayerKarts"
kartsFolder.Parent = Workspace

local activeKarts = {}
local driverInputs = {}
local mapBuilt = false

local function makePart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function buildTestCourse()
	if mapBuilt then
		return
	end
	mapBuilt = true

	local course = Workspace:FindFirstChild("KartTestCourse") or Instance.new("Folder")
	course.Name = "KartTestCourse"
	course.Parent = Workspace

	makePart(course, "TrackFloor", Vector3.new(260, 2, 180), CFrame.new(0, -1, 0), Color3.fromRGB(73, 119, 78), Enum.Material.Grass)
	makePart(course, "DrivingPad", Vector3.new(210, 1, 96), CFrame.new(0, 0, 0), Color3.fromRGB(72, 75, 82), Enum.Material.Asphalt)

	local lineColor = Color3.fromRGB(236, 228, 190)
	for x = -84, 84, 24 do
		makePart(course, "LaneMarker", Vector3.new(10, 0.12, 0.45), CFrame.new(x, 0.57, 0), lineColor, Enum.Material.Neon)
	end

	local wallColor = Color3.fromRGB(232, 107, 67)
	makePart(course, "NorthBarrier", Vector3.new(212, 5, 2), CFrame.new(0, 2.5, -49), wallColor)
	makePart(course, "SouthBarrier", Vector3.new(212, 5, 2), CFrame.new(0, 2.5, 49), wallColor)
	makePart(course, "WestBarrier", Vector3.new(2, 5, 100), CFrame.new(-105, 2.5, 0), wallColor)
	makePart(course, "EastBarrier", Vector3.new(2, 5, 100), CFrame.new(105, 2.5, 0), wallColor)

	local obstaclePositions = {
		Vector3.new(-42, 2, -22), Vector3.new(2, 2, 22),
		Vector3.new(44, 2, -20), Vector3.new(68, 2, 23),
	}
	for index, position in ipairs(obstaclePositions) do
		local obstacle = makePart(course, "BlockObstacle" .. index, Vector3.new(7, 4, 7), CFrame.new(position), Color3.fromRGB(242, 190, 68), Enum.Material.Concrete)
		obstacle.Anchored = true
	end
end

local function weldTo(root, part)
	part.Anchored = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = root
end

local function createKart(player, spawnIndex)
	local model = Instance.new("Model")
	model.Name = "Kart_" .. player.UserId
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = kartsFolder

	local startX = ((spawnIndex - 1) % 6 - 2.5) * KartConfig.SpawnSpacing
	local startZ = -34 + math.floor((spawnIndex - 1) / 6) * 16
	local spawnCFrame = CFrame.new(startX, 3, startZ)

	local chassis = makePart(model, "Chassis", Vector3.new(5.2, 1, 7), spawnCFrame, Color3.fromRGB(37, 142, 224), Enum.Material.Metal)
	chassis.Anchored = false
	chassis.CustomPhysicalProperties = PhysicalProperties.new(1.2, 0.65, 0.05, 1, 1)
	model.PrimaryPart = chassis

	local body = makePart(model, "Body", Vector3.new(4.6, 1.25, 3.1), spawnCFrame * CFrame.new(0, 1, 0.4), Color3.fromRGB(30, 112, 193))
	body.CanCollide = false
	weldTo(chassis, body)
	local nose = makePart(model, "Nose", Vector3.new(3.6, 0.65, 1.6), spawnCFrame * CFrame.new(0, 1.15, -2.15), Color3.fromRGB(255, 204, 64))
	nose.CanCollide = false
	weldTo(chassis, nose)
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2.2, 0.7, 2)
	seat.CFrame = spawnCFrame * CFrame.new(0, 1.35, 0.45)
	seat.Color = Color3.fromRGB(42, 45, 52)
	seat.Material = Enum.Material.SmoothPlastic
	seat.Anchored = false
	seat.CanCollide = false
	seat.Massless = true
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.Parent = model
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = chassis
	seatWeld.Part1 = seat
	seatWeld.Parent = chassis

	local wheelPositions = {
		Vector3.new(-2.5, -0.3, -2.2), Vector3.new(2.5, -0.3, -2.2),
		Vector3.new(-2.5, -0.3, 2.2), Vector3.new(2.5, -0.3, 2.2),
	}
	for index, offset in ipairs(wheelPositions) do
		local wheel = makePart(model, "BlockWheel" .. index, Vector3.new(1, 1.35, 1.35), spawnCFrame * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(35, 37, 42), Enum.Material.Rubber)
		wheel.CanCollide = false
		weldTo(chassis, wheel)
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "DriveForceAttachment"
	attachment.Parent = chassis

	local driveForce = Instance.new("VectorForce")
	driveForce.Name = "ArcadeDriveForce"
	driveForce.Attachment0 = attachment
	driveForce.RelativeTo = Enum.ActuatorRelativeTo.World
	driveForce.ApplyAtCenterOfMass = true
	driveForce.Parent = chassis

	local upright = Instance.new("AlignOrientation")
	upright.Name = "UprightStabilizer"
	upright.Mode = Enum.OrientationAlignmentMode.OneAttachment
	upright.Attachment0 = attachment
	upright.RigidityEnabled = false
	upright.Responsiveness = 18
	upright.MaxTorque = 80000
	upright.MaxAngularVelocity = 8
	upright.CFrame = CFrame.Angles(0, math.rad(180), 0)
	upright.Parent = chassis

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterKartPrompt"
	prompt.ActionText = "Conducir"
	prompt.ObjectText = "Kart"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.Parent = seat
	prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer ~= player then
			return
		end
		local character = triggeringPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and not seat.Occupant then
			seat:Sit(humanoid)
		end
	end)

	return {
		model = model,
		chassis = chassis,
		seat = seat,
		driveForce = driveForce,
		upright = upright,
		spawnCFrame = spawnCFrame,
		yaw = math.pi,
		networkOwner = false,
	}
end

local function spawnPlayerKart(player)
	local current = activeKarts[player]
	if current then
		current.model:Destroy()
	end
	local kart = createKart(player, player:GetAttribute("KartSpawnIndex") or 1)
	activeKarts[player] = kart
	driverInputs[player] = { throttle = 0, steering = 0, braking = false }
	player:SetAttribute("KartOwnerUserId", player.UserId)

	local function seatCharacter(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not humanoid or not root or not kart.model.Parent then
			return
		end
		root.CFrame = kart.spawnCFrame * CFrame.new(0, 4, 1)
		task.wait(0.15)
		if kart.seat.Parent and not kart.seat.Occupant then
			kart.seat:Sit(humanoid)
		end
	end

	player.CharacterAdded:Connect(seatCharacter)
	if player.Character then
		task.spawn(seatCharacter, player.Character)
	end
end

remote.OnServerEvent:Connect(function(player, throttle, steering, braking)
	if typeof(throttle) ~= "number" or typeof(steering) ~= "number" or typeof(braking) ~= "boolean" then
		return
	end
	local kart = activeKarts[player]
	if kart and kart.seat.Occupant and kart.seat.Occupant.Parent == player.Character then
		if throttle ~= throttle or steering ~= steering then
			return
		end
		driverInputs[player] = {
			throttle = math.clamp(throttle, -1, 1),
			steering = math.clamp(steering, -1, 1),
			braking = braking,
		}
	end
end)

RunService.Heartbeat:Connect(function(deltaTime)
	for player, kart in pairs(activeKarts) do
		if not kart.chassis.Parent then
			continue
		end
		local seat = kart.seat
		local driver = seat.Occupant
		local input = driverInputs[player]
		local isAuthorizedDriver = driver and driver.Parent == player.Character
		local throttle = isAuthorizedDriver and input and input.throttle or 0
		local steering = isAuthorizedDriver and input and input.steering or 0
		local chassis = kart.chassis
		local velocity = chassis.AssemblyLinearVelocity
		local forward = chassis.CFrame.LookVector
		local right = chassis.CFrame.RightVector
		local forwardSpeed = velocity:Dot(forward)
		local lateralSpeed = velocity:Dot(right)
		local braking = isAuthorizedDriver and input and input.braking == true

		if math.abs(forwardSpeed) > KartConfig.MinimumSteeringSpeed then
			local directionFactor = forwardSpeed >= 0 and 1 or -1
			kart.yaw += -steering * KartConfig.SteeringRate * directionFactor * deltaTime
		end
		kart.upright.CFrame = CFrame.Angles(0, kart.yaw, 0)

		local acceleration = 0
		if braking then
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
		kart.driveForce.Force = forward * ((acceleration + drag) * chassis.AssemblyMass) + right * (lateralForce * chassis.AssemblyMass)

		local maxSpeed = (throttle < 0 and forwardSpeed <= 2) and KartConfig.MaxReverseSpeed or KartConfig.MaxForwardSpeed
		if math.abs(forwardSpeed) > maxSpeed then
			local clamped = math.sign(forwardSpeed) * maxSpeed
			chassis.AssemblyLinearVelocity = forward * clamped + right * lateralSpeed + Vector3.new(0, velocity.Y, 0)
		end

		local desiredOwner = driver and driver.Parent == player.Character and player or nil
		if kart.networkOwner ~= desiredOwner then
			local success = pcall(function()
				chassis:SetNetworkOwner(desiredOwner)
			end)
			if success then
				kart.networkOwner = desiredOwner
			end
		end
		if not isAuthorizedDriver and input and (input.throttle ~= 0 or input.steering ~= 0 or input.braking) then
			driverInputs[player] = { throttle = 0, steering = 0, braking = false }
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	local existing = #Players:GetPlayers()
	player:SetAttribute("KartSpawnIndex", existing)
	spawnPlayerKart(player)
end)

for index, player in ipairs(Players:GetPlayers()) do
	player:SetAttribute("KartSpawnIndex", index)
	spawnPlayerKart(player)
end

Players.PlayerRemoving:Connect(function(player)
	local kart = activeKarts[player]
	if kart then
		kart.model:Destroy()
	end
	activeKarts[player] = nil
	driverInputs[player] = nil
end)

buildTestCourse()

return true
