local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DIAGNOSTICS_ENABLED = true
local DIAGNOSTIC_INTERVAL = 2
local COURSE_SURFACE_Y = 0.6
local KartConfig = require(ReplicatedStorage:WaitForChild("KartConfig"))

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
-- Remove only stale models matching the exact name/owner signature created by this service.
for _, child in ipairs(kartsFolder:GetChildren()) do
	local ownerUserId = child:GetAttribute("OwnerUserId")
	if child:IsA("Model") and typeof(ownerUserId) == "number" and child.Name == "Kart_" .. tostring(ownerUserId) then
		child:Destroy()
	end
end

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
	part.Anchored = true
	part.CanCollide = true
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
	-- Reconcile only names owned by this generator, including legacy parts; preserve unknown user content.
	local generatedCoursePartNames = {
		TrackFloor = true, TrackFloorWest = true, TrackFloorEast = true,
		TrackFloorNorth = true, TrackFloorSouth = true, DrivingPad = true,
		LaneMarker = true, NorthBarrier = true, SouthBarrier = true,
		WestBarrier = true, EastBarrier = true,
	}
	for _, child in ipairs(course:GetChildren()) do
		if child:IsA("BasePart") and (generatedCoursePartNames[child.Name] or child.Name:match("^BlockObstacle%d+$")) then
			child:Destroy()
		end
	end

	local courseSurfaceY = COURSE_SURFACE_Y
	local courseWidth, courseDepth = 260, 180
	local roadWidth, roadDepth = 210, 96
	local floorThickness = 2
	local floorCenterY = courseSurfaceY - floorThickness / 2
	local grassColor = Color3.fromRGB(73, 119, 78)
	local grassMaterial = Enum.Material.Grass
	local sideWidth = (courseWidth - roadWidth) / 2
	local endDepth = (courseDepth - roadDepth) / 2
	makePart(course, "TrackFloorWest", Vector3.new(sideWidth, floorThickness, courseDepth), CFrame.new(-roadWidth / 2 - sideWidth / 2, floorCenterY, 0), grassColor, grassMaterial)
	makePart(course, "TrackFloorEast", Vector3.new(sideWidth, floorThickness, courseDepth), CFrame.new(roadWidth / 2 + sideWidth / 2, floorCenterY, 0), grassColor, grassMaterial)
	makePart(course, "TrackFloorNorth", Vector3.new(roadWidth, floorThickness, endDepth), CFrame.new(0, floorCenterY, -roadDepth / 2 - endDepth / 2), grassColor, grassMaterial)
	makePart(course, "TrackFloorSouth", Vector3.new(roadWidth, floorThickness, endDepth), CFrame.new(0, floorCenterY, roadDepth / 2 + endDepth / 2), grassColor, grassMaterial)
	-- Road and surrounding grass meet at one height; the top also clears the default Studio baseplate plane.
	makePart(course, "DrivingPad", Vector3.new(roadWidth, 1, roadDepth), CFrame.new(0, courseSurfaceY - 0.5, 0), Color3.fromRGB(72, 75, 82), Enum.Material.Asphalt)

	local lineColor = Color3.fromRGB(236, 228, 190)
	for x = -84, 84, 24 do
		local marker = makePart(course, "LaneMarker", Vector3.new(10, 0.12, 0.45), CFrame.new(x, courseSurfaceY + 0.07, 0), lineColor, Enum.Material.Neon)
		marker.CanCollide = false
		marker.CanTouch = false
	end

	local wallColor = Color3.fromRGB(232, 107, 67)
	local barrierCenterY = courseSurfaceY + 2.5
	makePart(course, "NorthBarrier", Vector3.new(212, 5, 2), CFrame.new(0, barrierCenterY, -49), wallColor)
	makePart(course, "SouthBarrier", Vector3.new(212, 5, 2), CFrame.new(0, barrierCenterY, 49), wallColor)
	makePart(course, "WestBarrier", Vector3.new(2, 5, 100), CFrame.new(-106, barrierCenterY, 0), wallColor)
	makePart(course, "EastBarrier", Vector3.new(2, 5, 100), CFrame.new(106, barrierCenterY, 0), wallColor)

	local obstaclePositions = {
		Vector3.new(-42, courseSurfaceY + 2, -22), Vector3.new(2, courseSurfaceY + 2, 22),
		Vector3.new(44, courseSurfaceY + 2, -20), Vector3.new(68, courseSurfaceY + 2, 23),
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

local function makeVisualPart(model, chassis, name, size, cframe, color, material, shape)
	local part = makePart(model, name, size, cframe, color, material)
	if shape then
		part.Shape = shape
	end
	part.CanCollide = false
	part.CanTouch = false
	weldTo(chassis, part)
	return part
end

local function makeVisualRod(model, chassis, name, startOffset, endOffset, thickness, color, material, baseCFrame)
	local length = (endOffset - startOffset).Magnitude
	local center = (startOffset + endOffset) / 2
	local rodCFrame = baseCFrame * CFrame.lookAt(center, endOffset)
	return makeVisualPart(model, chassis, name, Vector3.new(thickness, thickness, length), rodCFrame, color, material)
end

local function createKart(player, spawnIndex)
	local model = Instance.new("Model")
	model.Name = "Kart_" .. player.UserId
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = kartsFolder

	local startX = ((spawnIndex - 1) % 6 - 2.5) * KartConfig.SpawnSpacing
	local startZ = -34 + math.floor((spawnIndex - 1) / 6) * 16
	local spawnCFrame = CFrame.new(startX, COURSE_SURFACE_Y + 2.5, startZ) * CFrame.Angles(0, math.pi, 0)

	local chassis = makePart(model, "Chassis", Vector3.new(5.2, 1, 7), spawnCFrame, Color3.fromRGB(39, 42, 49), Enum.Material.Metal)
	chassis.Anchored = false
	-- The non-colliding wheels make the chassis the actual floor-contact surface.
	-- Keep that contact low-friction; lateral grip is handled by the arcade force below.
	chassis.CustomPhysicalProperties = PhysicalProperties.new(1.2, 0.05, 0.05, 10, 1)
	model.PrimaryPart = chassis

	local red = Color3.fromRGB(205, 38, 43)
	local blue = Color3.fromRGB(34, 109, 204)
	local yellow = Color3.fromRGB(255, 204, 48)
	local dark = Color3.fromRGB(36, 39, 45)
	local metal = Color3.fromRGB(115, 121, 130)
	local black = Color3.fromRGB(24, 26, 30)
	local function visual(name, size, offset, color, material, shape)
		return makeVisualPart(model, chassis, name, size, spawnCFrame * offset, color, material, shape)
	end
	local function visualRod(name, startOffset, endOffset, thickness, color, material)
		return makeVisualRod(model, chassis, name, startOffset, endOffset, thickness, color, material, spawnCFrame)
	end

	-- Keep the body low and leave the seat opening unobstructed for the real R15 avatar.
	visual("Body", Vector3.new(4.4, 0.72, 3.8), CFrame.new(0, 0.38, 0.35), red)
	visual("SidePodLeft", Vector3.new(0.82, 0.62, 3.45), CFrame.new(-2.16, 0.24, 0.35), blue)
	visual("SidePodRight", Vector3.new(0.82, 0.62, 3.45), CFrame.new(2.16, 0.24, 0.35), blue)
	visual("SideAccentLeft", Vector3.new(0.08, 0.1, 2.45), CFrame.new(-2.58, 0.43, 0.3), yellow, Enum.Material.Metal)
	visual("SideAccentRight", Vector3.new(0.08, 0.1, 2.45), CFrame.new(2.58, 0.43, 0.3), yellow, Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		local sideName = side < 0 and "Left" or "Right"
		for axle, frontZ in ipairs({ -2.15, 2.15 }) do
			local axleName = axle == 1 and "Front" or "Rear"
			visual("WheelFender" .. axleName .. sideName, Vector3.new(0.28, 0.18, 1.5), CFrame.new(side * 2.38, 0.72, frontZ), blue)
		end
	end

	local noseTilt = CFrame.Angles(math.rad(-13), 0, 0)
	visual("Nose", Vector3.new(3.45, 0.58, 1.9), CFrame.new(0, 0.8, -2.45) * noseTilt, red)
	visual("NoseStripe", Vector3.new(0.22, 0.06, 1.3), CFrame.new(0, 1.08, -2.5) * noseTilt, yellow, Enum.Material.Metal)
	visual("FrontBumper", Vector3.new(4.35, 0.26, 0.32), CFrame.new(0, 0.42, -3.48), dark, Enum.Material.Metal)
	visual("FrontGrille", Vector3.new(1.65, 0.25, 0.1), CFrame.new(0, 0.68, -3.31), black, Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		local sideName = side < 0 and "Left" or "Right"
		visual("Headlight" .. sideName, Vector3.new(0.48, 0.34, 0.2), CFrame.new(side * 1.24, 0.95, -3.12), yellow, Enum.Material.Neon)
	end

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

	visual("SeatCushion", Vector3.new(2, 0.16, 1.8), CFrame.new(0, 0.9, 0.45), dark)
	visual("SeatBack", Vector3.new(1.9, 1, 0.24), CFrame.new(0, 1.75, 1.45), dark, Enum.Material.SmoothPlastic)
	visual("SeatBackAccent", Vector3.new(1.5, 0.12, 0.08), CFrame.new(0, 2.18, 1.59), red)
	visual("Dashboard", Vector3.new(2.45, 0.24, 0.62), CFrame.new(0, 2.38, -0.78), dark, Enum.Material.Metal)
	visual("DashboardDisplay", Vector3.new(0.72, 0.12, 0.18), CFrame.new(0, 2.55, -0.94), yellow, Enum.Material.Neon)

	local steeringCenter = Vector3.new(0, 3.08, -1.28)
	visualRod("SteeringColumn", Vector3.new(0, 1.86, -0.8), steeringCenter, 0.14, metal, Enum.Material.Metal)
	local steeringRadius = 0.43
	for segment = 1, 8 do
		local angle = (segment - 1) * math.pi / 4
		local ringPosition = steeringCenter + Vector3.new(math.cos(angle) * steeringRadius, math.sin(angle) * steeringRadius, 0)
		visual("SteeringRim" .. segment, Vector3.new(0.12, 0.34, 0.14), CFrame.new(ringPosition) * CFrame.Angles(0, 0, angle), black, Enum.Material.Metal)
	end
	visualRod("SteeringSpokeLower", steeringCenter, steeringCenter + Vector3.new(0, -0.34, 0), 0.08, yellow, Enum.Material.Metal)
	visualRod("SteeringSpokeLeft", steeringCenter, steeringCenter + Vector3.new(-0.3, 0.08, 0), 0.08, yellow, Enum.Material.Metal)
	visualRod("SteeringSpokeRight", steeringCenter, steeringCenter + Vector3.new(0.3, 0.08, 0), 0.08, yellow, Enum.Material.Metal)
	visual("SteeringHub", Vector3.new(0.2, 0.2, 0.16), CFrame.new(steeringCenter), yellow, Enum.Material.Metal)

	visual("EngineBlock", Vector3.new(2.35, 0.62, 1.55), CFrame.new(0, 0.74, 2.62), dark, Enum.Material.Metal)
	visual("EngineCover", Vector3.new(1.55, 0.2, 1.05), CFrame.new(0, 1.15, 2.62), red)
	for _, side in ipairs({ -1, 1 }) do
		local sideName = side < 0 and "Left" or "Right"
		visual("Exhaust" .. sideName, Vector3.new(0.18, 0.18, 0.65), CFrame.new(side * 1.02, 0.76, 3.05), metal, Enum.Material.Metal)
		visual("RearWingSupport" .. sideName, Vector3.new(0.16, 0.52, 0.16), CFrame.new(side * 1.25, 1.35, 3.03), dark, Enum.Material.Metal)
	end
	visual("RearWing", Vector3.new(4.35, 0.2, 0.62), CFrame.new(0, 1.68, 3.12), red, Enum.Material.SmoothPlastic)
	visual("RearWingAccent", Vector3.new(3.5, 0.06, 0.1), CFrame.new(0, 1.81, 3.12), yellow, Enum.Material.Metal)

	local wheelPositions = {
		Vector3.new(-2.5, 0.18, -2.2), Vector3.new(2.5, 0.18, -2.2),
		Vector3.new(-2.5, 0.18, 2.2), Vector3.new(2.5, 0.18, 2.2),
	}
	for index, offset in ipairs(wheelPositions) do
		visual("BlockWheel" .. index, Vector3.new(0.74, 1.42, 1.42), CFrame.new(offset), black, Enum.Material.Rubber, Enum.PartType.Cylinder)
		local outerSide = offset.X < 0 and -1 or 1
		local rimOffset = offset + Vector3.new(outerSide * 0.38, 0, 0)
		visual("WheelRim" .. index, Vector3.new(0.12, 0.9, 0.9), CFrame.new(rimOffset), yellow, Enum.Material.Metal, Enum.PartType.Cylinder)
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
	prompt.Style = Enum.ProximityPromptStyle.Custom
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
			prompt.Enabled = occupant == nil
			local driver = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
		if not model:IsDescendantOf(Workspace) or not chassis:IsDescendantOf(Workspace) then
			kart.networkOwner = "auto"
			if model.Parent then
				model:SetAttribute("NetworkOwnerUserId", 0)
			end
			print(("[BLOXY-KART][SERVER][NETWORK-OWNER-SKIP] kart=%s reason=outside-workspace"):format(model.Name))
			return
		end
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
