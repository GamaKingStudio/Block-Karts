local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DIAGNOSTICS_ENABLED = true
local DIAGNOSTIC_INTERVAL = 2

local remote = ReplicatedStorage:FindFirstChild("KartControl")
if remote and not remote:IsA("RemoteEvent") then
	error(("[BLOXY-KART][SERVER][REMOTE-WRONG-CLASS] ReplicatedStorage.KartControl is %s, expected RemoteEvent."):format(remote.ClassName))
end
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "KartControl"
	remote.Parent = ReplicatedStorage
end
print(("[BLOXY-KART][SERVER][START] module=%s remote=%s class=%s"):format(
	script:GetFullName(), remote:GetFullName(), remote.ClassName
))

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
	local spawnCFrame = CFrame.new(startX, 3, startZ) * CFrame.Angles(0, math.pi, 0)

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

	local kart = {
		model = model,
		chassis = chassis,
		seat = seat,
		driveForce = driveForce,
		spawnCFrame = spawnCFrame,
		networkOwner = "auto",
		nextDiagnosticAt = 0,
		lastDiagnosticPosition = spawnCFrame.Position,
	}

	local function updateNetworkOwner()
		local occupant = seat.Occupant
		local driver = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
		local networkRoot = chassis.AssemblyRootPart or chassis
		local success, ownershipError = pcall(function()
			if driver then
				networkRoot:SetNetworkOwner(driver)
			else
				networkRoot:SetNetworkOwnershipAuto()
			end
		end)
		if success then
			kart.networkOwner = driver or "auto"
			model:SetAttribute("NetworkOwnerUserId", driver and driver.UserId or 0)
			local ownerOk, actualOwner = pcall(function()
				return networkRoot:GetNetworkOwner()
			end)
			print(("[BLOXY-KART][SERVER][NETWORK-OWNER] kart=%s driver=%s requested=%s actual=%s root=%s rootAnchored=%s"):format(
				model.Name, driver and driver.Name or "nil", driver and driver.Name or "automatic",
				ownerOk and actualOwner and actualOwner.Name or (ownerOk and "server/nil" or "unavailable"),
				networkRoot:GetFullName(), tostring(networkRoot.Anchored)
			))
		else
			warn(("[BLOXY-KART][SERVER][NETWORK-OWNER-FAILED] kart=%s driver=%s error=%s"):format(
				model.Name, driver and driver.Name or "nil", tostring(ownershipError)
			))
		end
	end
	seat:GetPropertyChangedSignal("Occupant"):Connect(updateNetworkOwner)
	task.defer(updateNetworkOwner)
	return kart
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
	print(("[BLOXY-KART][SERVER][KART-CREATED] player=%s model=%s chassis=%s chassisAnchored=%s seat=%s"):format(
		player.Name, kart.model:GetFullName(), kart.chassis:GetFullName(), tostring(kart.chassis.Anchored), kart.seat:GetFullName()
	))

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
		warn(("[BLOXY-KART][SERVER][REMOTE-INVALID] player=%s throttleType=%s steeringType=%s brakeType=%s"):format(
			player.Name, typeof(throttle), typeof(steering), typeof(braking)
		))
		return
	end
	local kart = activeKarts[player]
	local occupant = kart and kart.seat.Occupant
	local isAuthorizedDriver = occupant ~= nil and occupant.Parent == player.Character
	print(("[BLOXY-KART][SERVER][REMOTE-RECV] player=%s remote=%s throttle=%s steering=%s brake=%s kartFound=%s occupant=%s authorized=%s"):format(
		player.Name, remote:GetFullName(), tostring(throttle), tostring(steering), tostring(braking),
		tostring(kart ~= nil), occupant and occupant.Parent.Name or "nil", tostring(isAuthorizedDriver)
	))
	if throttle ~= throttle or steering ~= steering then
		warn(("[BLOXY-KART][SERVER][REMOTE-NAN] player=%s input discarded"):format(player.Name))
		return
	end
	if not isAuthorizedDriver then
		warn(("[BLOXY-KART][SERVER][DRIVER-REJECTED] player=%s seatOccupant=%s character=%s"):format(
			player.Name, occupant and occupant.Parent:GetFullName() or "nil", player.Character and player.Character:GetFullName() or "nil"
		))
		return
	end
	driverInputs[player] = {
		throttle = math.clamp(throttle, -1, 1),
		steering = math.clamp(steering, -1, 1),
		braking = braking,
	}
end)

RunService.Heartbeat:Connect(function()
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
		if not isAuthorizedDriver and input and (input.throttle ~= 0 or input.steering ~= 0 or input.braking) then
			driverInputs[player] = { throttle = 0, steering = 0, braking = false }
		end

		if DIAGNOSTICS_ENABLED and os.clock() >= kart.nextDiagnosticAt then
			kart.nextDiagnosticAt = os.clock() + DIAGNOSTIC_INTERVAL
			local assemblyRoot = chassis.AssemblyRootPart or chassis
			local anchoredParts = {}
			for _, part in ipairs(kart.model:GetDescendants()) do
				if part:IsA("BasePart") and part.AssemblyRootPart == assemblyRoot and part.Anchored then
					table.insert(anchoredParts, part.Name)
				end
			end
			local ownerName = "unknown"
			local ownerOk, owner = pcall(function()
				return chassis:GetNetworkOwner()
			end)
			if ownerOk then
				ownerName = owner and owner.Name or "server/nil"
			end
			local positionDelta = chassis.Position - kart.lastDiagnosticPosition
			kart.lastDiagnosticPosition = chassis.Position
			local characterRoot = driver and driver.Parent:FindFirstChild("HumanoidRootPart")
			local seatWeld = seat:FindFirstChild("SeatWeld")
			local sharesAssembly = characterRoot ~= nil and characterRoot.AssemblyRootPart == assemblyRoot
			print(("[BLOXY-KART][SERVER][PHYSICS] player=%s occupant=%s authorized=%s input=(%.0f,%.0f,%s) chassisAnchored=%s root=%s rootAnchored=%s characterRoot=%s sharesAssembly=%s seatWeld=%s anchoredAssemblyParts=%s mass=%.2f speed=%.2f distance2s=%.2f angular=(%.2f,%.2f,%.2f) forceTarget=%s forceEnabled=%s forceAttachment=%s applyAtCenter=%s owner=%s"):format(
				player.Name, driver and driver.Parent.Name or "nil", tostring(isAuthorizedDriver), throttle, steering, tostring(braking),
				tostring(chassis.Anchored), assemblyRoot:GetFullName(), tostring(assemblyRoot.Anchored),
				characterRoot and characterRoot:GetFullName() or "nil", tostring(sharesAssembly), tostring(seatWeld ~= nil),
				#anchoredParts > 0 and table.concat(anchoredParts, ",") or "none", chassis.AssemblyMass,
				velocity.Magnitude, positionDelta.Magnitude, chassis.AssemblyAngularVelocity.X,
				chassis.AssemblyAngularVelocity.Y, chassis.AssemblyAngularVelocity.Z,
				kart.driveForce.Parent and kart.driveForce.Parent:GetFullName() or "nil",
				tostring(kart.driveForce.Enabled), kart.driveForce.Attachment0 and kart.driveForce.Attachment0:GetFullName() or "nil",
				tostring(kart.driveForce.ApplyAtCenterOfMass), ownerName
			))
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
