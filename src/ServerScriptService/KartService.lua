local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local InsertService = game:GetService("InsertService")

local DIAGNOSTICS_ENABLED = false
local DIAGNOSTIC_INTERVAL = 2
local COURSE_SURFACE_Y = 1.0
local KartConfig = require(ReplicatedStorage:WaitForChild("KartConfig"))

-- ==========================================================
-- GESTIÓN DE EVENTOS REMOTOS
-- ==========================================================
local remote = ReplicatedStorage:FindFirstChild("KartControl")
if remote and not remote:IsA("RemoteEvent") then
	error(("[BLOXY-KART][SERVER][REMOTE-WRONG-CLASS] ReplicatedStorage.KartControl is %s, expected RemoteEvent."):format(remote.ClassName))
end
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "KartControl"
	remote.Parent = ReplicatedStorage
end

local raceEventsFolder = ReplicatedStorage:FindFirstChild("RaceEvents") or Instance.new("Folder")
raceEventsFolder.Name = "RaceEvents"
raceEventsFolder.Parent = ReplicatedStorage

local function getOrCreateRemote(name)
	local r = raceEventsFolder:FindFirstChild(name)
	if not r or not r:IsA("RemoteEvent") then
		if r then r:Destroy() end
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = raceEventsFolder
	end
	return r
end

local checkpointPassedRemote = getOrCreateRemote("CheckpointPassed")
local lapCompletedRemote = getOrCreateRemote("LapCompleted")
local wrongWayRemote = getOrCreateRemote("WrongWayStateChanged")
local requestRespawnRemote = getOrCreateRemote("RequestRespawn")
local raceCountdownRemote = getOrCreateRemote("RaceCountdown")
local cameraSelectionRemote = getOrCreateRemote("SelectRaceCamera")
local selectionStateRemote = getOrCreateRemote("RaceSelectionState")

-- ==========================================================
-- CONTENEDORES Y ESTADO
-- ==========================================================
local kartsFolder = Workspace:FindFirstChild("PlayerKarts") or Instance.new("Folder")
kartsFolder.Name = "PlayerKarts"
kartsFolder.Parent = Workspace
for _, child in ipairs(kartsFolder:GetChildren()) do
	local ownerUserId = child:GetAttribute("OwnerUserId")
	if child:IsA("Model") and typeof(ownerUserId) == "number" and child.Name == "Kart_" .. tostring(ownerUserId) then
		child:Destroy()
	end
end

local activeKarts = {}
local driverInputs = {}
local mapBuilt = false
local raceData = {}
local selectedCameras = {}
local raceInProgress = false
local countdownToken = 0
local function publishSelectionState()
 local list=Players:GetPlayers(); local ready=0
 for _,p in ipairs(list) do local k=activeKarts[p]; if selectedCameras[p] and k and k.seat.Parent and k.seat.Occupant and k.seat.Occupant.Parent==p.Character then ready+=1 end end
 for _,p in ipairs(list) do selectionStateRemote:FireClient(p,ready,#list,selectedCameras[p]~=nil) end
end
local function tryStartRace()
 if raceInProgress then return end
 local list=Players:GetPlayers(); if #list==0 then return end
 for _,p in ipairs(list) do local k=activeKarts[p]; if not k or not k.seat.Parent or not k.seat.Occupant or k.seat.Occupant.Parent~=p.Character or not selectedCameras[p] then publishSelectionState(); return end end
 raceInProgress=true; countdownToken+=1; local token=countdownToken
 for _,p in ipairs(list) do p:SetAttribute("RaceCountdownActive",true); p:SetAttribute("RaceStarted",false); driverInputs[p]={throttle=0,steering=0,braking=false} end
 task.spawn(function()
  for n=5,1,-1 do if token~=countdownToken then return end; raceCountdownRemote:FireAllClients(n); task.wait(1) end
  if token~=countdownToken then return end
  for _,p in ipairs(Players:GetPlayers()) do local k=activeKarts[p]; if k and k.seat.Parent and k.seat.Occupant and k.seat.Occupant.Parent==p.Character then local d=raceData[p]; if d then d.LapStartTime=os.clock(); d.CanFinishLap=false end; p:SetAttribute("RaceStarted",true); raceCountdownRemote:FireClient(p,0) end end
 end)
end
cameraSelectionRemote.OnServerEvent:Connect(function(p,mode)
 if raceInProgress or (mode~="Classic" and mode~="Isometric") then return end
 local k=activeKarts[p]; if not k or not k.seat.Parent or not k.seat.Occupant or k.seat.Occupant.Parent~=p.Character then return end
 selectedCameras[p]=mode; p:SetAttribute("RaceCamera",mode); publishSelectionState(); tryStartRace()
end)

local function makePart(parent, name, size, cframe, color, material, shapeOrClass)
	local className = "Part"
	local targetShape = nil

	if shapeOrClass == "WedgePart" or shapeOrClass == "CornerWedgePart" then
		className = shapeOrClass
	elseif shapeOrClass == "Cylinder" or shapeOrClass == Enum.PartType.Cylinder then
		targetShape = Enum.PartType.Cylinder
	elseif shapeOrClass == "Ball" or shapeOrClass == Enum.PartType.Ball then
		targetShape = Enum.PartType.Ball
	elseif typeof(shapeOrClass) == "EnumItem" then
		targetShape = shapeOrClass
	end

	local part = Instance.new(className)
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	if targetShape then
		part.Shape = targetShape
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = true
	part:SetAttribute("GeneratedByKartService", true)
	part.Parent = parent
	return part

end


-- ==========================================================
-- AMBIENTACIÓN BEACH RESORT: iluminación, océano y horizonte
-- ==========================================================
local function configureBeachLighting()
	Lighting.ClockTime = 13.6
	Lighting.Brightness = 2.8
	Lighting.ExposureCompensation = 0.05
	Lighting.Ambient = Color3.fromRGB(105, 125, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 170, 190)
	Lighting.GeographicLatitude = 18
	Lighting.ShadowSoftness = 0.7
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.55
	Lighting.ColorShift_Top = Color3.fromRGB(255, 247, 232)
	Lighting.ColorShift_Bottom = Color3.fromRGB(225, 239, 250)

	local function getEffect(className, name)
		local effect = Lighting:FindFirstChild(name)
		if effect and not effect:IsA(className) then
			effect:Destroy()
			effect = nil
		end
		if not effect then
			effect = Instance.new(className)
			effect.Name = name
			effect.Parent = Lighting
		end
		return effect
	end

	local atmosphere = getEffect("Atmosphere", "BloxyBeachAtmosphere")
	atmosphere.Color = Color3.fromRGB(199, 225, 255)
	atmosphere.Decay = Color3.fromRGB(112, 151, 185)
	atmosphere.Density = 0.22
	atmosphere.Glare = 0.08
	atmosphere.Haze = 1.15
	atmosphere.Offset = 0.12

	local colorCorrection = getEffect("ColorCorrectionEffect", "BloxyBeachColor")
	colorCorrection.Brightness = 0.015
	colorCorrection.Contrast = 0.055
	colorCorrection.Saturation = 0.12
	colorCorrection.TintColor = Color3.fromRGB(255, 248, 235)

	local bloom = getEffect("BloomEffect", "BloxyBeachBloom")
	bloom.Intensity = 0.1
	bloom.Size = 22
	bloom.Threshold = 1.25

	local sunRays = getEffect("SunRaysEffect", "BloxyBeachSunRays")
	sunRays.Intensity = 0.025
	sunRays.Spread = 0.72

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local clouds = terrain:FindFirstChildOfClass("Clouds")
		if not clouds then
			clouds = Instance.new("Clouds")
			clouds.Name = "BloxyBeachClouds"
			clouds.Parent = terrain
		end
		-- Nubes más visibles y voluminosas, estilo circuito de competición.
		clouds.Cover = 0.58
		clouds.Density = 0.52
		clouds.Color = Color3.fromRGB(250, 252, 255)
	end
end

local function buildOceanAndHorizon(course)
	local waterColor = Color3.fromRGB(32, 142, 205)
	-- Cuadrícula de piezas para evitar superar el tamaño máximo de una Part.
	-- El agua queda bajo la isla y se extiende varios kilómetros alrededor.
	for xIndex = -2, 2 do
		for zIndex = -2, 2 do
			local ocean = makePart(
				course,
				("OceanHorizon_%d_%d"):format(xIndex, zIndex),
				Vector3.new(1800, 2, 1800),
				CFrame.new(50 + xIndex * 1800, -0.85, zIndex * 1800),
				waterColor,
				Enum.Material.SmoothPlastic
			)
			ocean.CanCollide = false
			ocean.CanTouch = false
			ocean.CanQuery = false
			ocean.CastShadow = false
			ocean.Reflectance = 0.12
		end
	end

	local distantIslands = {
		{ x = -950, z = -800, width = 270, depth = 220, height = 72 },
		{ x = -100, z = -1280, width = 330, depth = 235, height = 92 },
		{ x = 850, z = -980, width = 300, depth = 235, height = 78 },
		{ x = 1320, z = -100, width = 270, depth = 320, height = 100 },
		{ x = 1020, z = 900, width = 350, depth = 270, height = 84 },
		{ x = 100, z = 1320, width = 330, depth = 250, height = 94 },
		{ x = -850, z = 1020, width = 310, depth = 250, height = 88 },
		{ x = -1280, z = 100, width = 270, depth = 315, height = 78 },
	}

	local rockColor = Color3.fromRGB(105, 128, 119)
	local rockShadow = Color3.fromRGB(83, 111, 105)
	local islandGreen = Color3.fromRGB(75, 158, 91)
	local islandGreenLight = Color3.fromRGB(104, 181, 105)
	local waterY = 0.18

	local function makeDistantPart(name, size, cframe, color, material, shape)
		local part = makePart(course, name, size, cframe, color, material, shape)
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		return part
	end

	for index, island in ipairs(distantIslands) do
		local x, z = island.x, island.z
		local w, d, h = island.width, island.depth, island.height
		local yaw = math.rad((index * 37) % 360)
		local baseCF = CFrame.new(x, waterY + h * 0.27, z) * CFrame.Angles(0, yaw, 0)

		makeDistantPart(
			"DistantIslandRock_" .. index,
			Vector3.new(w, h * 0.54, d),
			baseCF,
			rockColor,
			Enum.Material.Slate
		)
		makeDistantPart(
			"DistantIslandSlopeA_" .. index,
			Vector3.new(w * 0.52, h * 0.7, d * 0.72),
			baseCF * CFrame.new(-w * 0.22, h * 0.12, 0) * CFrame.Angles(0, math.rad(90), 0),
			rockShadow,
			Enum.Material.Slate,
			"WedgePart"
		)
		makeDistantPart(
			"DistantIslandSlopeB_" .. index,
			Vector3.new(w * 0.48, h * 0.62, d * 0.7),
			baseCF * CFrame.new(w * 0.23, h * 0.08, 0) * CFrame.Angles(0, math.rad(-90), 0),
			rockColor,
			Enum.Material.Slate,
			"WedgePart"
		)
		makeDistantPart(
			"DistantIslandGreenTop_" .. index,
			Vector3.new(w * 0.78, 5, d * 0.76),
			CFrame.new(x, waterY + h * 0.56, z) * CFrame.Angles(0, yaw, 0),
			index % 2 == 0 and islandGreenLight or islandGreen,
			Enum.Material.Grass
		)

		-- Palmeras pequeñas de silueta para dar escala sin competir con la pista.
		if index == 2 or index == 5 or index == 7 then
			local trunkHeight = h * 0.58
			local trunkX = x + w * 0.08
			local trunkZ = z - d * 0.06
			local trunkTop = waterY + h * 0.56 + trunkHeight
			makeDistantPart(
				"DistantPalmTrunk_" .. index,
				Vector3.new(2.8, trunkHeight, 2.8),
				CFrame.new(trunkX, waterY + h * 0.56 + trunkHeight / 2, trunkZ),
				Color3.fromRGB(124, 91, 57),
				Enum.Material.Wood,
				"Cylinder"
			)
			for leaf = 1, 4 do
				local angle = math.rad((leaf - 1) * 90 + 25)
				local leafCF = CFrame.new(trunkX, trunkTop, trunkZ)
					* CFrame.Angles(0, angle, math.rad(8))
					* CFrame.new(0, 0, -9)
				makeDistantPart(
					"DistantPalmLeaf_" .. index .. "_" .. leaf,
					Vector3.new(16, 1.8, 5),
					leafCF,
					Color3.fromRGB(54, 139, 74),
					Enum.Material.Grass,
					"WedgePart"
				)
			end
		end
	end
end

-- ==========================================================
-- 1. PISTA, ENTORNO Y CHECKPOINTS BEACH RESORT
-- ==========================================================
local function buildTestCourse()
	if mapBuilt then return end
	mapBuilt = true

	configureBeachLighting()


	local course = Workspace:FindFirstChild("KartTestCourse") or Instance.new("Folder")
	course.Name = "KartTestCourse"
	course.Parent = Workspace
	for _, child in ipairs(course:GetChildren()) do
		if child:GetAttribute("GeneratedByKartService") == true then child:Destroy() end
	end

	local yGround = COURSE_SURFACE_Y
	local yWaterShallow = 0.35
	local yWaterDeep = 0.20

	local C_SAND = Color3.fromRGB(240, 218, 158)
	local C_WATER_SHALLOW = Color3.fromRGB(55, 205, 230)
	local C_WATER_DEEP = Color3.fromRGB(28, 125, 205)
	local C_FOAM = Color3.fromRGB(245, 252, 255)
	local C_WOOD = Color3.fromRGB(145, 98, 52)
	local C_WOOD_LIGHT = Color3.fromRGB(175, 125, 75)
	local C_DARKWOOD = Color3.fromRGB(95, 62, 34)
	local C_THATCH = Color3.fromRGB(210, 185, 120)
	local C_LEAVES = Color3.fromRGB(45, 165, 40)
	local C_LEAVES_DARK = Color3.fromRGB(35, 135, 32)
	local C_ASPHALT = Color3.fromRGB(66, 70, 76)
	local C_WHITE = Color3.fromRGB(248, 248, 250)
	local C_BLACK = Color3.fromRGB(30, 32, 36)
	local C_RED = Color3.fromRGB(220, 40, 40)
	local C_BLUE = Color3.fromRGB(35, 120, 230)
	local C_YELLOW = Color3.fromRGB(250, 205, 30)
	local C_ORANGE = Color3.fromRGB(245, 125, 30)
	local C_TEAL = Color3.fromRGB(30, 185, 160)

	local sandFloor = makePart(course, "IslandSand", Vector3.new(650, 4, 650), CFrame.new(50, yGround - 2, 0), C_SAND, Enum.Material.Sand)
	sandFloor.CustomPhysicalProperties = PhysicalProperties.new(1.2, 0.05, 0.05, 10, 1)

	buildOceanAndHorizon(course)
	local foam = makePart(course, "ShoreFoam", Vector3.new(4, 0.05, 600), CFrame.new(-140, yWaterShallow + 0.02, 0), C_FOAM, Enum.Material.SmoothPlastic)
	foam.CanCollide = false
	foam.Transparency = 0.25

	for _, bz in ipairs({ -120, -50, 20, 90, 160 }) do
		makePart(course, "Buoy", Vector3.new(2.4, 2.4, 2.4), CFrame.new(-175, yWaterShallow + 1.2, bz), C_ORANGE, Enum.Material.Plastic, "Ball")
	end

	makePart(course, "PierDeck", Vector3.new(24, 1.2, 75), CFrame.new(-150, yGround + 0.5, 70), C_WOOD, Enum.Material.WoodPlanks)
	for pz = 35, 105, 14 do
		makePart(course, "PierPostL", Vector3.new(1.6, 5.5, 1.6), CFrame.new(-161, yGround - 1.5, pz), C_DARKWOOD, Enum.Material.Wood)
		makePart(course, "PierPostR", Vector3.new(1.6, 5.5, 1.6), CFrame.new(-139, yGround - 1.5, pz), C_DARKWOOD, Enum.Material.Wood)
	end
	makePart(course, "BoatRed", Vector3.new(8, 2.2, 16), CFrame.new(-172, yWaterDeep + 0.8, 55) * CFrame.Angles(0, math.rad(18), 0), C_RED)
	makePart(course, "BoatBlue", Vector3.new(8, 2.2, 16), CFrame.new(-172, yWaterDeep + 0.8, 85) * CFrame.Angles(0, math.rad(-12), 0), C_BLUE)

	for bz = -45, 35, 10 do
		makePart(course, "FencePost_" .. bz, Vector3.new(0.8, 3.2, 0.8), CFrame.new(-138, yGround + 1.6, bz), C_WOOD, Enum.Material.Wood)
		makePart(course, "FenceRailTop_" .. bz, Vector3.new(0.4, 0.4, 10), CFrame.new(-138, yGround + 2.8, bz + 5), C_WOOD_LIGHT, Enum.Material.Wood)
		makePart(course, "FenceRailMid_" .. bz, Vector3.new(0.4, 0.4, 10), CFrame.new(-138, yGround + 1.6, bz + 5), C_WOOD_LIGHT, Enum.Material.Wood)
	end

	makePart(course, "BoardwalkNorth", Vector3.new(8, 0.15, 110), CFrame.new(-144, yGround + 0.08, -15), C_WOOD_LIGHT, Enum.Material.WoodPlanks)
	makePart(course, "BoardwalkEast", Vector3.new(125, 0.15, 8), CFrame.new(-75, yGround + 0.08, -145), C_WOOD_LIGHT, Enum.Material.WoodPlanks)

	local function spawnBeachKiosk(x, z, canopyColor)
		local cf = CFrame.new(x, yGround, z)
		makePart(course, "KioskFloor", Vector3.new(12, 0.4, 10), cf * CFrame.new(0, 0.2, 0), C_WOOD_LIGHT, Enum.Material.WoodPlanks)
		for _, px in ipairs({ -5.2, 5.2 }) do
			for _, pz in ipairs({ -4.2, 4.2 }) do
				makePart(course, "KioskPost", Vector3.new(0.8, 7.5, 0.8), cf * CFrame.new(px, 3.95, pz), C_DARKWOOD, Enum.Material.Wood)
			end
		end
		makePart(course, "KioskCounter", Vector3.new(10.5, 3.4, 2.2), cf * CFrame.new(0, 1.7, 3.2), C_WOOD, Enum.Material.WoodPlanks)
		makePart(course, "KioskCounterTop", Vector3.new(11.2, 0.3, 2.8), cf * CFrame.new(0, 3.5, 3.2), C_DARKWOOD, Enum.Material.Wood)
		local roofCF = cf * CFrame.new(0, 8.0, 0) * CFrame.Angles(math.rad(8), 0, 0)
		makePart(course, "KioskRoof", Vector3.new(13.5, 0.6, 11.5), roofCF, canopyColor, Enum.Material.Fabric)
		makePart(course, "KioskValance", Vector3.new(13.5, 1.2, 0.3), roofCF * CFrame.new(0, -0.6, 5.75), C_WHITE, Enum.Material.Fabric)
		local lantern = makePart(course, "KioskLamp", Vector3.new(0.8, 0.8, 0.8), cf * CFrame.new(0, 6.8, 0), Color3.fromRGB(255, 210, 120), Enum.Material.Neon)
		lantern.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 110)
		light.Range = 28
		light.Brightness = 0.65
		light.Parent = lantern
	end

	local kioskData = {
		{ x = 35,  z = -140, c = C_BLUE },
		{ x = 55,  z = -140, c = C_RED },
		{ x = 75,  z = -140, c = C_YELLOW },
		{ x = 95,  z = -140, c = C_ORANGE },
		{ x = 115, z = -140, c = C_TEAL },
	}
	for _, k in ipairs(kioskData) do
		spawnBeachKiosk(k.x, k.z, k.c)
	end

	local function spawnCabana(x, z, rot)
		local baseCF = CFrame.new(x, yGround, z) * CFrame.Angles(0, math.rad(rot or 0), 0)
		makePart(course, "HutFloor", Vector3.new(14, 0.6, 14), baseCF * CFrame.new(0, 0.3, 0), C_WOOD, Enum.Material.WoodPlanks)
		for _, cx in ipairs({ -5.5, 5.5 }) do
			for _, cz in ipairs({ -5.5, 5.5 }) do
				makePart(course, "HutPillar", Vector3.new(1.2, 8, 1.2), baseCF * CFrame.new(cx, 4.3, cz), C_DARKWOOD, Enum.Material.Wood)
			end
		end
		makePart(course, "HutRoof", Vector3.new(18, 4, 18), baseCF * CFrame.new(0, 9.5, 0), C_THATCH, Enum.Material.Fabric)
	end
	spawnCabana(-85, -145, 10)
	spawnCabana(-55, -145, -5)
	spawnCabana(-25, -145, 0)

	for tier = 1, 3 do
		-- Desplazar toda la grada 8 studs hacia atrás para separarla
		-- de la barrera junto a la recta de salida.
		local benchZ = 44 - (tier - 1) * 3.5
		local benchY = yGround + tier * 1.0
		makePart(course, "GrandstandStep_" .. tier, Vector3.new(50, 0.8, 3.2), CFrame.new(35, benchY, benchZ), C_WOOD, Enum.Material.Wood)
		local seatColors = { C_BLUE, C_RED, C_YELLOW, C_TEAL }
		for sx = 14, 56, 4 do
			local c = seatColors[((sx + tier) % #seatColors) + 1]
			makePart(course, "Seat_" .. tier .. "_" .. sx, Vector3.new(2.8, 0.3, 2.2), CFrame.new(sx, benchY + 0.5, benchZ), c)
		end
	end

	local pitRoadZ = 96
	local pitRoadWidth = 22
	makePart(course, "PitLanePad", Vector3.new(75, 0.04, pitRoadWidth), CFrame.new(80, yGround + 0.02, pitRoadZ), C_ASPHALT, Enum.Material.Asphalt)

	local entryStart = Vector3.new(118, yGround + 0.02, 60)
	local entryEnd = Vector3.new(95, yGround + 0.02, pitRoadZ)
	local entryDiff = entryEnd - entryStart
	local entryLen = entryDiff.Magnitude
	local entryMid = (entryStart + entryEnd) / 2
	local entryCF = CFrame.lookAt(entryMid, entryEnd)
	local pitEntry = makePart(course, "PitEntryLane", Vector3.new(16, 0.04, entryLen), entryCF, C_ASPHALT, Enum.Material.Asphalt)
	pitEntry.CanCollide = false

	local wedgeCF = CFrame.new(103, yGround + 0.02, 78) * CFrame.Angles(0, math.rad(-145), 0)
	local transitionWedge = makePart(course, "PitEntryGapFiller", Vector3.new(12, 0.04, 18), wedgeCF, C_ASPHALT, Enum.Material.Asphalt, "WedgePart")
	transitionWedge.CanCollide = false

	local exitStart = Vector3.new(45, yGround + 0.02, pitRoadZ)
	local exitEnd = Vector3.new(15, yGround + 0.02, 83)
	local exitDiff = exitEnd - exitStart
	local exitLen = exitDiff.Magnitude
	local exitMid = (exitStart + exitEnd) / 2
	local exitCF = CFrame.lookAt(exitMid, exitEnd)
	local pitExit = makePart(course, "PitExitLane", Vector3.new(16, 0.04, exitLen), exitCF, C_ASPHALT, Enum.Material.Asphalt)
	pitExit.CanCollide = false

	local exitLine = makePart(course, "PitExitLine", Vector3.new(0.6, 0.02, exitLen), exitCF * CFrame.new(-7.8, 0.02, 0), C_WHITE)
	exitLine.CanCollide = false

	makePart(course, "PitWallBase", Vector3.new(55, 1.6, 1.4), CFrame.new(77.5, yGround + 0.8, 83.5), C_WHITE, Enum.Material.Concrete)
	makePart(course, "PitWallCap", Vector3.new(55, 0.3, 1.8), CFrame.new(77.5, yGround + 1.75, 83.5), C_RED)

	for px = 55, 105, 13 do
		local pline = makePart(course, "PitStallLine_" .. px, Vector3.new(0.6, 0.03, 16), CFrame.new(px, yGround + 0.04, 102), C_WHITE)
		pline.CanCollide = false
		makePart(course, "PitWheelStop_" .. px, Vector3.new(5.5, 0.45, 0.8), CFrame.new(px + 2.5, yGround + 0.25, 108), C_WHITE, Enum.Material.Concrete)
	end

	local trackWidth = 26
	local waypoints = {
		Vector3.new(80, yGround + 0.02, 70),
		Vector3.new(-65, yGround + 0.02, 70),
		Vector3.new(-115, yGround + 0.02, 40),
		Vector3.new(-115, yGround + 0.02, -50),
		Vector3.new(-80, yGround + 0.02, -95),
		Vector3.new(-50, yGround + 0.02, -95),
		Vector3.new(-50, yGround + 0.02, -15),
		Vector3.new(-25, yGround + 0.02, 10),
		Vector3.new(0, yGround + 0.02, -15),
		Vector3.new(0, yGround + 0.02, -85),
		Vector3.new(45, yGround + 0.02, -105),
		Vector3.new(85, yGround + 0.02, -65),
		Vector3.new(125, yGround + 0.02, -10),
		Vector3.new(125, yGround + 0.02, 35),
		Vector3.new(105, yGround + 0.02, 65),
		Vector3.new(80, yGround + 0.02, 70),
	}

	for i = 1, #waypoints do
		local corner = makePart(course, "CornerHub_" .. i, Vector3.new(0.04, trackWidth, trackWidth), CFrame.new(waypoints[i]) * CFrame.Angles(0, 0, math.pi / 2), C_ASPHALT, Enum.Material.Asphalt, "Cylinder")
		corner.CanCollide = false
		corner.CanTouch = false
	end

	for i = 1, #waypoints - 1 do
		local p1 = waypoints[i]
		local p2 = waypoints[i + 1]
		local diff = p2 - p1
		local length = diff.Magnitude
		local mid = (p1 + p2) / 2
		local roadCF = CFrame.lookAt(mid, p2)

		local road = makePart(course, "RoadSeg_" .. i, Vector3.new(trackWidth, 0.04, length), roadCF, C_ASPHALT, Enum.Material.Asphalt)
		road.CanCollide = false
		road.CanTouch = false

		for dist = 8, length - 8, 14 do
			local linePos = roadCF * CFrame.new(0, 0.025, -length / 2 + dist)
			local worldPos = linePos.Position
			-- Deja libre el rectángulo de salida: la línea discontinua no debe
			-- atravesar ni quedar coplanar con los cuadros de la bandera.
			local insideStartGrid = math.abs(worldPos.X) < 4
				and math.abs(worldPos.Z - 70) < trackWidth / 2 + 1
			if not insideStartGrid then
				local line = makePart(course, "DashLine", Vector3.new(0.7, 0.02, 6), linePos, C_WHITE)
				line.CanCollide = false
				line.CanTouch = false
			end
		end
	end


	-- ==========================================================
	-- PIANOS ROJO/BLANCO: recorrido paralelo cerrado con esquinas redondeadas.
	local curbWidth = 1.6
	local curbHeight = 0.14
	local curbEdgeOffset = 1.0
	local curbTileLength = 1.25
	local guardrailOffset = trackWidth / 2 + 5.0
	local guardrailPostSpacing = 8.0
	local guardrailPostHeight = 1.75
	local guardrailPostWidth = 0.32
	local guardrailBeamThickness = 0.22
	local guardrailBeamHeight = 0.24
	local guardrailColors = { C_RED, C_WHITE }
	local C_GUARDRAIL = Color3.fromRGB(155, 165, 172)
	local C_GUARDRAIL_DARK = Color3.fromRGB(95, 105, 112)

	local function curbDirection(a, b)
		local v = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		return v.Magnitude > 0.001 and v.Unit or Vector3.new(0, 0, -1)
	end

	local uniqueCount = #waypoints - 1
	local curbOffset = trackWidth / 2 + curbEdgeOffset

	for sideIndex, side in ipairs({ -1, 1 }) do
		local curbCorners = {}
		for i = 1, uniqueCount do
			local previousIndex = (i - 2) % uniqueCount + 1
			local nextIndex = i % uniqueCount + 1
			local incoming = curbDirection(waypoints[previousIndex], waypoints[i])
			local outgoing = curbDirection(waypoints[i], waypoints[nextIndex])
			local normalIn = Vector3.new(-incoming.Z, 0, incoming.X) * side
			local normalOut = Vector3.new(-outgoing.Z, 0, outgoing.X) * side
			local bisector = normalIn + normalOut
			if bisector.Magnitude < 0.001 then bisector = normalOut else bisector = bisector.Unit end
			local denominator = math.max(math.abs(bisector:Dot(normalOut)), 0.35)
			local miterDistance = math.min(curbOffset / denominator, curbOffset * 1.8)
			local point = waypoints[i] + bisector * miterDistance
			curbCorners[i] = Vector3.new(point.X, yGround + 0.13, point.Z)
		end

		-- Redondea cada vértice con una curva Bézier cuadrática.
		-- Los tramos rectos se conservan entre la salida de una curva
		-- y la entrada de la siguiente.
		local pathPoints = {}
		local function appendPoint(point)
			local previous = pathPoints[#pathPoints]
			if not previous or (point - previous).Magnitude > 0.015 then
				pathPoints[#pathPoints + 1] = point
			end
		end

		for i = 1, uniqueCount do
			local previousIndex = (i - 2) % uniqueCount + 1
			local nextIndex = i % uniqueCount + 1
			local corner = curbCorners[i]
			local previousCorner = curbCorners[previousIndex]
			local nextCorner = curbCorners[nextIndex]
			local incomingVector = corner - previousCorner
			local outgoingVector = nextCorner - corner
			local incomingLength = incomingVector.Magnitude
			local outgoingLength = outgoingVector.Magnitude
			if incomingLength > 0.01 and outgoingLength > 0.01 then
				local incoming = incomingVector.Unit
				local outgoing = outgoingVector.Unit
				local dot = math.clamp(incoming:Dot(outgoing), -0.999, 0.999)
				local turnAngle = math.acos(dot)
				local tangentDistance = 3.5 * math.tan(turnAngle / 2)
				tangentDistance = math.min(tangentDistance, incomingLength * 0.35, outgoingLength * 0.35)
				if turnAngle < math.rad(3) then tangentDistance = 0 end
				local curveStart = corner - incoming * tangentDistance
				local curveEnd = corner + outgoing * tangentDistance
				appendPoint(curveStart)
				for step = 1, 12 do
					local t = step / 12
					local oneMinusT = 1 - t
					local point = curveStart * (oneMinusT * oneMinusT)
						+ corner * (2 * oneMinusT * t)
						+ curveEnd * (t * t)
					appendPoint(point)
				end
			end
		end

		if #pathPoints > 2 then appendPoint(pathPoints[1]) end
		local cumulative = { 0 }
		for i = 2, #pathPoints do
			cumulative[i] = cumulative[i - 1] + (pathPoints[i] - pathPoints[i - 1]).Magnitude
		end
		local totalLength = cumulative[#cumulative]

		local function pointAtDistance(distance)
			distance = distance % totalLength
			for i = 2, #cumulative do
				if distance <= cumulative[i] then
					local segmentLength = cumulative[i] - cumulative[i - 1]
					local alpha = segmentLength > 0.001 and (distance - cumulative[i - 1]) / segmentLength or 0
					return pathPoints[i - 1]:Lerp(pathPoints[i], alpha)
				end
			end
			return pathPoints[1]
		end

		local tileCount = math.max(1, math.floor(totalLength / curbTileLength))
		local actualTileLength = totalLength / tileCount
		for tileIndex = 1, tileCount do
			local distance = (tileIndex - 0.5) * actualTileLength
			local center = pointAtDistance(distance)
			local before = pointAtDistance(distance - actualTileLength * 0.45)
			local after = pointAtDistance(distance + actualTileLength * 0.45)
			local direction = after - before
			if direction.Magnitude > 0.001 then direction = direction.Unit else direction = Vector3.new(0, 0, -1) end
			local tile = makePart(
				course,
				("Kerb_%d_%d"):format(sideIndex, tileIndex),
				Vector3.new(curbWidth, curbHeight, math.max(0.1, actualTileLength - 0.025)),
				CFrame.lookAt(center, center + direction),
				guardrailColors[((tileIndex - 1) % #guardrailColors) + 1],
				Enum.Material.SmoothPlastic
			)
			tile.CanCollide = false
			tile.CanTouch = false
			tile.CanQuery = false
		end
	end

		local function horizontalDirection(a, b)
		local v = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		return v.Magnitude > 0.001 and v.Unit or Vector3.new(0, 0, -1)
	end

	local function sideNormal(direction)
		return Vector3.new(-direction.Z, 0, direction.X)
	end

	for sideIndex, side in ipairs({ -1, 1 }) do
		local railPoints = {}
		for i = 1, #waypoints do
			local previousIndex = (i == 1) and (#waypoints - 1) or (i - 1)
			local nextIndex = (i == #waypoints) and 2 or (i + 1)
			local incoming = horizontalDirection(waypoints[previousIndex], waypoints[i])
			local outgoing = horizontalDirection(waypoints[i], waypoints[nextIndex])
			local normalIn = sideNormal(incoming)
			local normalOut = sideNormal(outgoing)
			local bisector = normalIn + normalOut
			if bisector.Magnitude < 0.001 then
				bisector = normalOut
			else
				bisector = bisector.Unit
			end
			local denominator = math.abs(bisector:Dot(normalOut))
			local miterDistance = guardrailOffset / math.max(denominator, 0.35)
			miterDistance = math.min(miterDistance, guardrailOffset * 1.8)
			railPoints[i] = waypoints[i] + bisector * (side * miterDistance)
		end

		-- O último waypoint repete o primeiro: força o fechamento exato do circuito.
		railPoints[#waypoints] = railPoints[1]

		for i = 1, #waypoints - 1 do
			local a = railPoints[i]
			local b = railPoints[i + 1]
			local segment = b - a
			local length = segment.Magnitude
			if length > 0.5 then
				local direction = segment.Unit
				local mid = (a + b) / 2
				local railCF = CFrame.lookAt(mid, b)
				local postCount = math.max(1, math.ceil(length / guardrailPostSpacing))
				for postIndex = 0, postCount do
					local t = postIndex / postCount
					local postPosition = a:Lerp(b, t)
					local post = makePart(
						course,
						("GuardrailPost_%d_%d_%d"):format(i, sideIndex, postIndex),
						Vector3.new(guardrailPostWidth, guardrailPostHeight, guardrailPostWidth),
						CFrame.new(postPosition.X, yGround + guardrailPostHeight / 2, postPosition.Z) * CFrame.lookAt(Vector3.zero, direction),
						C_GUARDRAIL_DARK,
						Enum.Material.Metal
					)
					post.CanTouch = false
				end

				-- Os perfis terminam exatamente no ponto miter da curva seguinte.
				for railIndex, railY in ipairs({ 1.05, 1.58 }) do
					local rail = makePart(
						course,
						("GuardrailBeam_%d_%d_%d"):format(i, sideIndex, railIndex),
						Vector3.new(guardrailBeamThickness, guardrailBeamHeight, length + 0.015),
						CFrame.new(mid.X, yGround + railY, mid.Z) * CFrame.lookAt(Vector3.zero, direction),
						C_GUARDRAIL,
						Enum.Material.Metal
					)
					rail.CanTouch = false
				end

				-- Barrera invisible continua detrás de la baranda visual.
				-- Evita que el chasis atraviese los huecos entre postes o los perfiles delgados.
				local collisionBarrier = makePart(
					course,
					("GuardrailCollision_%d_%d"):format(i, sideIndex),
					Vector3.new(0.9, 3.2, length + 0.35),
					CFrame.new(mid.X, yGround + 1.65, mid.Z) * CFrame.lookAt(Vector3.zero, direction),
					C_GUARDRAIL,
					Enum.Material.SmoothPlastic
				)
				collisionBarrier.Transparency = 1
				collisionBarrier.CanCollide = true
				collisionBarrier.CanTouch = false
				collisionBarrier.CanQuery = false

			end
		end
	end

	-- Arco de meta: el asset completo del usuario reemplaza los postes y el banner procedural.
	local gantryX = 0
	local spanWidth = trackWidth + 6
	local FINISH_STRUCTURE_ASSET_ID = 86635101465127
	local finishAssetOk, finishAssetOrError = pcall(function()
		return InsertService:LoadAsset(FINISH_STRUCTURE_ASSET_ID)
	end)

	if finishAssetOk and finishAssetOrError then
		local loadedFinishAsset = finishAssetOrError
		local sourceModel = loadedFinishAsset
		if not sourceModel:IsA("Model") then
			sourceModel = loadedFinishAsset:FindFirstChildWhichIsA("Model", true)
		end

		if sourceModel then
			local finishStructure = sourceModel:Clone()
			finishStructure.Name = "ImportedFinishStructure"
			finishStructure.Parent = course

			-- Livery deportiva para el arco original: base blanca con acentos rojos y azules.
			-- Solo se ajusta Color; se conservan MeshPart.TextureID, SurfaceAppearance,
			-- Decals y demás texturas originales del asset.
			local function applyFinishCompetitionColors(model)
				local boundsCFrame, boundsSize = model:GetBoundingBox()
				local red = Color3.fromRGB(220, 40, 45)
				local blue = Color3.fromRGB(35, 115, 220)
				local white = Color3.fromRGB(245, 247, 250)

				for _, part in ipairs(model:GetDescendants()) do
					if part:IsA("BasePart") then
						local partName = string.lower(part.Name)
						local localPosition = boundsCFrame:PointToObjectSpace(part.Position)
						local color = white

						if string.find(partName, "red") or string.find(partName, "rojo") then
							color = red
						elseif string.find(partName, "blue") or string.find(partName, "azul") then
							color = blue
						elseif string.find(partName, "stripe") or string.find(partName, "trim")
							or string.find(partName, "accent") or string.find(partName, "line") then
							color = red
						elseif string.find(partName, "panel") or string.find(partName, "banner")
							or string.find(partName, "sign") then
							color = blue
						elseif boundsSize.X > 0 and math.abs(localPosition.X) > boundsSize.X * 0.28
							and localPosition.Y < boundsSize.Y * 0.38 then
							color = localPosition.X < 0 and red or blue
						end

						part.Color = color

						-- Acabado por tipo de pieza: estructura metálica y paneles de pintura lisa.
						-- No se reemplazan TextureID, SurfaceAppearance, Decals ni texturas importadas.
						local isMetalFrame = string.find(partName, "frame")
							or string.find(partName, "support")
							or string.find(partName, "beam")
							or string.find(partName, "post")
							or string.find(partName, "leg")
							or string.find(partName, "truss")
							or string.find(partName, "pole")
							or string.find(partName, "structure")

						if isMetalFrame then
							part.Material = Enum.Material.Metal
							part.Reflectance = 0.1
						else
							part.Material = Enum.Material.SmoothPlastic
							part.Reflectance = 0.025
						end
					end
				end
			end
			applyFinishCompetitionColors(finishStructure)

			-- Se conserva el giro de 90 grados que orienta el vano transversalmente
			-- y se añade media vuelta para que el frente mire hacia el sentido correcto.
			finishStructure:PivotTo(finishStructure:GetPivot() * CFrame.Angles(0, math.rad(270), 0))

			local _, initialBounds = finishStructure:GetBoundingBox()
			local horizontalSpan = math.max(initialBounds.X, initialBounds.Z)
			if horizontalSpan > 0.01 then
				local scaled, scaleError = pcall(function()
					finishStructure:ScaleTo(spanWidth / horizontalSpan)
				end)

				if scaled then
					for _, descendant in ipairs(finishStructure:GetDescendants()) do
						if descendant:IsA("BasePart") then
							descendant.Anchored = true
							descendant.CanCollide = false
							descendant.CanTouch = false
							descendant.CanQuery = false
							descendant.Massless = true
						end
					end

					-- Conserva la rotación aplicada y solo traslada el bounding box:
					-- centrado en la recta y con la base apoyada en el nivel del circuito.
					local boundsCFrame, boundsSize = finishStructure:GetBoundingBox()
					local targetBoundsPosition = Vector3.new(gantryX, yGround + boundsSize.Y / 2, 70)
					local offset = targetBoundsPosition - boundsCFrame.Position
					finishStructure:PivotTo(CFrame.new(offset) * finishStructure:GetPivot())
				else
					warn(("[BLOXY-KART][FINISH] No se pudo escalar el asset %d: %s"):format(FINISH_STRUCTURE_ASSET_ID, tostring(scaleError)))
					finishStructure:Destroy()
				end
			else
				warn(("[BLOXY-KART][FINISH] El asset %d tiene dimensiones inválidas."):format(FINISH_STRUCTURE_ASSET_ID))
				finishStructure:Destroy()
			end
		else
			warn(("[BLOXY-KART][FINISH] El asset %d no contiene un Model utilizable."):format(FINISH_STRUCTURE_ASSET_ID))
		end

		loadedFinishAsset:Destroy()
	else
		warn(("[BLOXY-KART][FINISH] No se pudo cargar el asset %d: %s"):format(FINISH_STRUCTURE_ASSET_ID, tostring(finishAssetOrError)))
	end

	local function spawnTireStack(pos)
		local tColors = { C_BLACK, C_WHITE, C_RED }
		for h = 1, 3 do
			local tire = makePart(course, "Tire", Vector3.new(0.65, 2.6, 2.6), CFrame.new(pos + Vector3.new(0, (h - 1) * 0.65 + 0.35, 0)) * CFrame.Angles(0, 0, math.pi / 2), tColors[h], Enum.Material.Rubber, "Cylinder")
			tire.CanCollide = true
		end
	end

	local tireLocations = {
		Vector3.new(-70, yGround, 88), Vector3.new(-66, yGround, 88),
		Vector3.new(-132, yGround, 45), Vector3.new(-132, yGround, -52),
		Vector3.new(-88, yGround, -112), Vector3.new(-84, yGround, -112),
		Vector3.new(-32, yGround, 26), Vector3.new(-28, yGround, 26),
		Vector3.new(52, yGround, -122), Vector3.new(56, yGround, -122),
		Vector3.new(142, yGround, -12), Vector3.new(120, yGround, 80)
	}
	for _, tPos in ipairs(tireLocations) do
		spawnTireStack(tPos)
	end

	-- Antorchas tiki construidas con piezas nativas para evitar el asset gris sin textura.
	-- Se mantienen intactas todas las posiciones existentes.
	local function spawnTikiTorch(pos)
		local torchModel = Instance.new("Model")
		torchModel.Name = "TrackTorch"
		torchModel.Parent = course

		local wood = Color3.fromRGB(126, 76, 39)
		local woodLight = Color3.fromRGB(166, 105, 55)
		local woodDark = Color3.fromRGB(75, 45, 27)
		local metal = Color3.fromRGB(65, 58, 48)

		local function torchPart(name, size, offset, color, material, shape)
			local partCFrame = CFrame.new(pos + offset)
			local partSize = size
			if shape == "Cylinder" then
				-- Roblox construye el cilindro con su eje longitudinal en X.
				-- Reordenamos dimensiones para que la altura solicitada (Y)
				-- pase a X, y luego rotamos ese eje para dejarlo vertical.
				partSize = Vector3.new(size.Y, size.X, size.Z)
				partCFrame = partCFrame * CFrame.Angles(0, 0, math.rad(90))
			end
			local part = makePart(
				torchModel,
				name,
				partSize,
				partCFrame,
				color,
				material,
				shape
			)
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			return part
		end

		-- Poste de madera con vetas/bandas oscuras y un pequeño soporte superior.
		torchPart("WoodenPole", Vector3.new(0.42, 6.7, 0.42), Vector3.new(0, 3.35, 0), wood, Enum.Material.Wood, "Cylinder")
		torchPart("PoleHighlight", Vector3.new(0.10, 5.9, 0.10), Vector3.new(-0.2, 3.35, -0.24), woodLight, Enum.Material.Wood, "Cylinder")
		torchPart("LowerBinding", Vector3.new(0.78, 0.18, 0.78), Vector3.new(0, 1.0, 0), woodDark, Enum.Material.Wood, "Cylinder")
		torchPart("UpperBinding", Vector3.new(0.82, 0.2, 0.82), Vector3.new(0, 6.15, 0), metal, Enum.Material.Metal, "Cylinder")

		-- Copa/cestillo superior que sostiene el fuego.
		torchPart("BrazierBase", Vector3.new(1.15, 0.28, 1.15), Vector3.new(0, 6.75, 0), woodDark, Enum.Material.Wood, "Cylinder")
		torchPart("BrazierRim", Vector3.new(1.35, 0.18, 1.35), Vector3.new(0, 6.95, 0), metal, Enum.Material.Metal, "Cylinder")
		for angle = 0, 3 do
			local a = angle * math.pi / 2
			local x = math.cos(a) * 0.48
			local z = math.sin(a) * 0.48
			torchPart("BrazierSlat", Vector3.new(0.16, 0.65, 0.16), Vector3.new(x, 7.22, z), woodLight, Enum.Material.Wood, "Cylinder")
		end

		local flameAnchor = Instance.new("Part")
		flameAnchor.Name = "TorchFlame"
		flameAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
		flameAnchor.CFrame = CFrame.new(pos + Vector3.new(0, 7.35, 0))
		flameAnchor.Transparency = 1
		flameAnchor.Anchored = true
		flameAnchor.CanCollide = false
		flameAnchor.CanTouch = false
		flameAnchor.CanQuery = false
		flameAnchor.Parent = torchModel

		local fire = Instance.new("Fire")
		fire.Name = "TorchFire"
		fire.Color = Color3.fromRGB(255, 224, 105)
		fire.SecondaryColor = Color3.fromRGB(255, 105, 24)
		fire.Size = 4.2
		fire.Heat = 8
		fire.Parent = flameAnchor

		local light = Instance.new("PointLight")
		light.Name = "TorchGlow"
		light.Color = Color3.fromRGB(255, 164, 72)
		light.Range = 36
		light.Brightness = 1.15
		light.Shadows = true
		light.Parent = flameAnchor
	end

	-- Mismas ubicaciones: perímetro y claros de arena interiores.
	local torchPositions = {
		Vector3.new(-165, yGround, -105),
		Vector3.new(-165, yGround, -35),
		Vector3.new(-165, yGround, 35),
		Vector3.new(-165, yGround, 105),
		Vector3.new(175, yGround, -105),
		Vector3.new(175, yGround, -35),
		Vector3.new(175, yGround, 35),
		Vector3.new(125, yGround, 145),
		Vector3.new(28, yGround, 25),
		Vector3.new(67, yGround, 25),
		Vector3.new(28, yGround, -45),
		Vector3.new(67, yGround, -45),
	}
	for _, tp in ipairs(torchPositions) do
		spawnTikiTorch(tp)
	end

	-- Modelo original de palmera importado en Roblox Studio.
	-- Si el asset no está disponible para esta experiencia, se usa el modelo procedural como respaldo.
	local InsertService = game:GetService("InsertService")
	local PALM_ASSET_ID = 135644677713727
	local importedPalmTemplate = nil
	local palmLoadOk, palmAssetOrError = pcall(function()
		return InsertService:LoadAsset(PALM_ASSET_ID)
	end)
	if palmLoadOk and palmAssetOrError then
		local loadedAsset = palmAssetOrError
		local candidate = loadedAsset
		if not candidate:IsA("Model") then
			candidate = loadedAsset:FindFirstChildWhichIsA("Model", true)
		end
		if candidate and #candidate:GetDescendants() > 0 then
			importedPalmTemplate = candidate:Clone()
			importedPalmTemplate.Name = "PalmTemplate"
			for _, descendant in ipairs(importedPalmTemplate:GetDescendants()) do
				if descendant:IsA("BasePart") then
					descendant.Anchored = true
					descendant.CanCollide = false
					descendant.CanTouch = false
					descendant.CanQuery = false
					descendant.Massless = true
				end
			end
		else
			warn("[BLOXY-KART][PALM] El asset cargó, pero no contiene un Model utilizable. Se usará el respaldo procedural.")
		end
		loadedAsset:Destroy()
	else
		warn(("[BLOXY-KART][PALM] No se pudo cargar el asset %d: %s. Se usará el respaldo procedural."):format(PALM_ASSET_ID, tostring(palmAssetOrError)))
	end

	local function spawnImportedPalm(pos, tiltDeg, tiltYaw, scale)
		local palmModel = importedPalmTemplate:Clone()
		palmModel.Name = "Palm"
		palmModel.Parent = course

		-- Normaliza el tamaño por la altura real del FBX. El factor anterior
		-- (0.85-1.2) asumía que el asset ya estaba cerca de la escala de Roblox.
		local _, originalBounds = palmModel:GetBoundingBox()
		if originalBounds.Y <= 0.01 then
			warn("[BLOXY-KART][PALM] El modelo importado tiene una altura inválida; se usará el respaldo procedural.")
			palmModel:Destroy()
			return false
		end
		local targetHeight = 15.5 * math.clamp(scale or 1, 0.9, 1.1)
		local normalizedScale = targetHeight / originalBounds.Y
		local scaled, scaleError = pcall(function()
			palmModel:ScaleTo(normalizedScale)
		end)
		if not scaled then
			warn("[BLOXY-KART][PALM] No se pudo normalizar la escala del modelo: " .. tostring(scaleError))
			palmModel:Destroy()
			return false
		end

		local boxCFrame, boxSize = palmModel:GetBoundingBox()
		local pivotToBox = palmModel:GetPivot():ToObjectSpace(boxCFrame)
		local targetBox = CFrame.new(pos)
			* CFrame.Angles(0, math.rad(tiltYaw or 0), 0)
			* CFrame.Angles(0, 0, math.rad(tiltDeg or 0))
			* CFrame.new(0, boxSize.Y / 2, 0)
		palmModel:PivotTo(targetBox * pivotToBox:Inverse())

		-- Recalcula los límites después de mover el modelo: las posiciones de
		-- las piezas ya están en su ubicación final dentro del circuito.
		local finalBoxCFrame, finalBoxSize = palmModel:GetBoundingBox()
		local boxBottomY = finalBoxCFrame.Position.Y - finalBoxSize.Y / 2
		local boxTopY = finalBoxCFrame.Position.Y + finalBoxSize.Y / 2

		-- Apariencia del asset: el modelo contiene tronco y hojas como piezas independientes.
		-- Se colorea el clon del juego, sin modificar el asset publicado en Roblox.
		local palmParts = {}
		for _, descendant in ipairs(palmModel:GetDescendants()) do
			if descendant:IsA("BasePart") then
				table.insert(palmParts, descendant)
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
				descendant.Massless = true
			end
		end

		-- Roblox puede renombrar las piezas al importar el FBX. Primero se
		-- buscan los nombres originales; si no existen, se clasifican por altura
		-- en el eje local de la palmera, para que la inclinación no altere el resultado.
		local trunkParts = 0
		local leafParts = 0
		for _, part in ipairs(palmParts) do
			local partName = string.lower(part.Name)
			local localPartY = finalBoxCFrame:PointToObjectSpace(part.Position).Y
			local isTrunk = partName:find("trunk", 1, true) or partName:find("stem", 1, true)
			local isLeaf = partName:find("leaf", 1, true) or partName:find("leaves", 1, true) or partName:find("foliage", 1, true)
			if isTrunk or (not isLeaf and localPartY < 0) then
				part.Color = Color3.fromRGB(126, 82, 48)
				part.Material = Enum.Material.Wood
				trunkParts += 1
			elseif isLeaf or localPartY >= 0 then
				part.Color = Color3.fromRGB(48, 150, 58)
				part.Material = Enum.Material.Grass
				leafParts += 1
			end
		end
		if #palmParts == 0 then
			warn("[BLOXY-KART][PALM] El modelo importado no contiene piezas BasePart; revisa la estructura del asset.")
		elseif trunkParts == 0 or leafParts == 0 then
			warn(("[BLOXY-KART][PALM] Clasificación incompleta: piezas=%d tronco=%d hojas=%d."):format(#palmParts, trunkParts, leafParts))
		else
			print(("[BLOXY-KART][PALM] Apariencia aplicada: piezas=%d tronco=%d hojas=%d."):format(#palmParts, trunkParts, leafParts))
		end
		return true
	end

	local function spawnProceduralPalm(pos, tiltDeg, tiltYaw, scale)
		-- Respaldo visual estable si el asset publicado no puede cargarse.
		scale = math.clamp(scale or 1, 0.85, 1.2)
		local palmModel = Instance.new("Model")
		palmModel.Name = "Palm_ProceduralFallback"
		palmModel.Parent = course
		local trunkH = 10.5 * scale
		local palmBaseCF = CFrame.new(pos)
			* CFrame.Angles(0, math.rad(tiltYaw or 0), math.rad(tiltDeg or 0))
		local trunk = makePart(palmModel, "PalmTrunk", Vector3.new(1.25 * scale, trunkH, 1.25 * scale), palmBaseCF * CFrame.new(0, trunkH / 2, 0), C_WOOD, Enum.Material.Wood)
		trunk.CanCollide = false
		trunk.CanTouch = false
		trunk.CanQuery = false
		trunk.Massless = true
		local crownCF = palmBaseCF * CFrame.new(0, trunkH, 0)
		for rot = 0, 300, 60 do
			local leafMat = (rot % 120 == 0) and C_LEAVES or C_LEAVES_DARK
			local leaf = makePart(palmModel, "PalmLeaf", Vector3.new(2.6 * scale, 0.28 * scale, 5.4 * scale),
				crownCF * CFrame.Angles(0, math.rad(rot), math.rad(-18)) * CFrame.new(0, 0, 2.8 * scale), leafMat)
			leaf.CanCollide = false
			leaf.CanTouch = false
			leaf.CanQuery = false
			leaf.Massless = true
		end
		for _, offset in ipairs({Vector3.new(0.35, -0.35, 0.35), Vector3.new(-0.35, -0.35, 0.35), Vector3.new(0, -0.4, -0.4)}) do
			local coconut = makePart(palmModel, "Coconut", Vector3.new(0.55, 0.55, 0.55) * scale,
				crownCF * CFrame.new(offset * scale), C_DARKWOOD, Enum.Material.Wood, "Ball")
			coconut.CanCollide = false
			coconut.CanTouch = false
			coconut.CanQuery = false
			coconut.Massless = true
		end
	end

	-- Palmeras agrupadas en la franja perimetral de arena, lejos del trazado.
	local palmData = {
		{ pos = Vector3.new(-175, yGround, -245), tilt = 6, yaw = 45, scale = 1.1 },
		{ pos = Vector3.new(-105, yGround, -245), tilt = -8, yaw = 120, scale = 1.2 },
		{ pos = Vector3.new(-35, yGround, -245), tilt = 5, yaw = -30, scale = 0.95 },
		{ pos = Vector3.new(35, yGround, -245), tilt = -7, yaw = 90, scale = 1.1 },
		{ pos = Vector3.new(105, yGround, -245), tilt = 6, yaw = -45, scale = 1.0 },
		{ pos = Vector3.new(175, yGround, -220), tilt = 8, yaw = 160, scale = 1.05 },
		{ pos = Vector3.new(195, yGround, -130), tilt = -6, yaw = 210, scale = 1.15 },
		{ pos = Vector3.new(195, yGround, -30), tilt = 7, yaw = -60, scale = 1.05 },
		{ pos = Vector3.new(195, yGround, 70), tilt = -5, yaw = 30, scale = 1.1 },
		{ pos = Vector3.new(115, yGround, 205), tilt = 6, yaw = -80, scale = 1.0 },
		{ pos = Vector3.new(-35, yGround, 205), tilt = -6, yaw = 50, scale = 0.95 },
	}
	for _, p in ipairs(palmData) do
		local spawned = false
		if importedPalmTemplate then
			spawned = spawnImportedPalm(p.pos, p.tilt, p.yaw, p.scale)
		end
		if not spawned then
			spawnProceduralPalm(p.pos, p.tilt, p.yaw, p.scale)
		end
	end

	-- Reposeras importadas desde el asset del usuario. Se carga una plantilla
	-- y se clona para cada puesto de playa, conservando colores y materiales.
	local LOUNGER_ASSET_ID = 110854388215298
	local loungerTemplate = nil
	local loungerLoadOk, loungerAssetOrError = pcall(function()
		return InsertService:LoadAsset(LOUNGER_ASSET_ID)
	end)
	if loungerLoadOk and loungerAssetOrError then
		local loadedLoungerAsset = loungerAssetOrError
		local candidate = loadedLoungerAsset
		if not candidate:IsA("Model") then
			candidate = loadedLoungerAsset:FindFirstChildWhichIsA("Model", true)
		end
		if candidate and #candidate:GetDescendants() > 0 then
			loungerTemplate = candidate:Clone()
			loungerTemplate.Name = "LoungerTemplate"
			for _, descendant in ipairs(loungerTemplate:GetDescendants()) do
				if descendant:IsA("BasePart") then
					descendant.Anchored = true
					descendant.CanCollide = false
					descendant.CanTouch = false
					descendant.CanQuery = false
					descendant.Massless = true
				end
			end
		else
			warn(("[BLOXY-KART][LOUNGER] El asset %d cargó, pero no contiene un Model utilizable."):format(LOUNGER_ASSET_ID))
		end
		loadedLoungerAsset:Destroy()
	else
		warn(("[BLOXY-KART][LOUNGER] No se pudo cargar el asset %d: %s"):format(LOUNGER_ASSET_ID, tostring(loungerAssetOrError)))
	end

	local loungerRandom = Random.new()
	local loungerColors = {
		Color3.fromRGB(235, 75, 75),   -- coral
		Color3.fromRGB(255, 175, 55),  -- naranja
		Color3.fromRGB(255, 220, 75),  -- amarillo
		Color3.fromRGB(55, 185, 205),  -- turquesa
		Color3.fromRGB(75, 125, 225),  -- azul
		Color3.fromRGB(100, 185, 105), -- verde
		Color3.fromRGB(205, 105, 185), -- rosa
		Color3.fromRGB(240, 235, 215), -- crema
	}
	local LOUNGER_FRAME_COLOR = Color3.fromRGB(115, 120, 128)
	local UMBRELLA_STAND_COLOR = Color3.fromRGB(205, 208, 212)

	local function getLoungerPartRole(part)
		-- Usar exclusivamente los nombres reales del asset; no inferir por
		-- nombres de padres ni palabras genéricas para evitar teñir todo el modelo.
		local name = part.Name
		if name == "Reposera_A_Estructura" or name == "Reposera_B_Estructura" then
			return "frame"
		elseif name == "Reposera_A_Colchon" or name == "Reposera_B_Colchon" then
			return "cushion"
		elseif name == "Sombrilla_Palo" then
			return "stand"
		elseif name == "Sombrilla_Toldo" then
			return "umbrella"
		end
		return nil
	end

	local function spawnLounger(pos, rotY)
		-- No se genera ningún respaldo procedural: si el asset no carga,
		-- se omite la reposera para evitar superponer el modelo antiguo. 
		if not loungerTemplate then return false end

		local lounger = loungerTemplate:Clone()
		lounger.Name = "BeachLounger"
		lounger.Parent = course

		local _, originalBounds = lounger:GetBoundingBox()
		local longestAxis = math.max(originalBounds.X, originalBounds.Y, originalBounds.Z)
		if longestAxis <= 0.01 then
			warn("[BLOXY-KART][LOUNGER] El modelo tiene dimensiones inválidas; se omite esta instancia.")
			lounger:Destroy()
			return false
		end

		local scaled, scaleError = pcall(function()
			lounger:ScaleTo(6.5 / longestAxis)
		end)
		if not scaled then
			warn("[BLOXY-KART][LOUNGER] No se pudo ajustar la escala: " .. tostring(scaleError))
			lounger:Destroy()
			return false
		end

		local umbrellaColor = loungerColors[loungerRandom:NextInteger(1, #loungerColors)]
		for _, descendant in ipairs(lounger:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
				descendant.Massless = true

				local role = getLoungerPartRole(descendant)
				if role == "frame" then
					descendant.Color = LOUNGER_FRAME_COLOR
				elseif role == "stand" then
					descendant.Color = UMBRELLA_STAND_COLOR
				elseif role == "cushion" then
					descendant.Color = loungerColors[loungerRandom:NextInteger(1, #loungerColors)]
				elseif role == "umbrella" then
					descendant.Color = umbrellaColor
				end
			end
		end

		local boxCFrame, boxSize = lounger:GetBoundingBox()
		local pivotToBox = lounger:GetPivot():ToObjectSpace(boxCFrame)
		local targetBox = CFrame.new(pos.X, pos.Y + boxSize.Y / 2, pos.Z)
			* CFrame.Angles(0, math.rad(rotY or 0), 0)
			* CFrame.Angles(math.rad(-8), 0, 0)
		lounger:PivotTo(targetBox * pivotToBox:Inverse())
		return true
	end

	local function spawnBeachCluster(pos, rot)
		-- Cada puesto contiene únicamente las dos reposeras importadas.
		-- Las sombrillas, toallas y pelotas procedurales antiguas se retiraron.
		local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(rot or 0), 0)
		spawnLounger((cf * CFrame.new(-3.2, 0, 0.5)).Position, rot)
		spawnLounger((cf * CFrame.new(3.2, 0, 0.5)).Position, rot)
	end

	-- Reposeras y sombrillas sobre arena abierta al norte del circuito.
	-- Reposeras en la franja de arena al sur del circuito, dentro del área visible.
	spawnBeachCluster(Vector3.new(-145, yGround, 155), 25)
	spawnBeachCluster(Vector3.new(-85, yGround, 155), -15)
	spawnBeachCluster(Vector3.new(-25, yGround, 155), 40)
	spawnBeachCluster(Vector3.new(35, yGround, 155), -30)
	spawnBeachCluster(Vector3.new(95, yGround, 155), 10)

	-- Dos rincones de playa en los claros interiores de arena.
	-- Se mantienen separados del asfalto y de las barreras.
	spawnBeachCluster(Vector3.new(45, yGround, 20), 18)
	spawnBeachCluster(Vector3.new(48, yGround, -45), -22)

	-- Tablas de surf importadas desde el asset del usuario.
	-- Se carga una sola plantilla y se clona para cada punto decorativo.
	local SURFBOARD_ASSET_ID = 109207384771697
	local surfboardTemplate = nil
	local surfLoadOk, surfAssetOrError = pcall(function()
		return InsertService:LoadAsset(SURFBOARD_ASSET_ID)
	end)
	if surfLoadOk and surfAssetOrError then
		local loadedSurfAsset = surfAssetOrError
		local candidate = loadedSurfAsset
		if not candidate:IsA("Model") then
			candidate = loadedSurfAsset:FindFirstChildWhichIsA("Model", true)
		end
		if candidate and #candidate:GetDescendants() > 0 then
			surfboardTemplate = candidate:Clone()
			surfboardTemplate.Name = "SurfboardTemplate"
			for _, descendant in ipairs(surfboardTemplate:GetDescendants()) do
				if descendant:IsA("BasePart") then
					descendant.Anchored = true
					descendant.CanCollide = false
					descendant.CanTouch = false
					descendant.CanQuery = false
					descendant.Massless = true
				end
			end
		else
			warn(("[BLOXY-KART][SURFBOARD] El asset %d cargó, pero no contiene un Model utilizable."):format(SURFBOARD_ASSET_ID))
		end
		loadedSurfAsset:Destroy()
	else
		warn(("[BLOXY-KART][SURFBOARD] No se pudo cargar el asset %d: %s"):format(SURFBOARD_ASSET_ID, tostring(surfAssetOrError)))
	end

	local surfboardRandom = Random.new()
	local surfboardColors = {
		Color3.fromRGB(255, 76, 76),   -- coral
		Color3.fromRGB(255, 190, 55),  -- amarillo tropical
		Color3.fromRGB(45, 190, 220),  -- turquesa
		Color3.fromRGB(75, 125, 245),  -- azul
		Color3.fromRGB(90, 205, 115),  -- verde
		Color3.fromRGB(220, 105, 220), -- magenta
		Color3.fromRGB(255, 130, 55),  -- naranja
		Color3.fromRGB(245, 235, 205), -- crema
	}

	local function spawnSurfboard(pos, rotY, leanDeg, scale)
		if not surfboardTemplate then return false end
		local board = surfboardTemplate:Clone()
		board.Name = "Surfboard"
		board.Parent = course

		local boardColor = surfboardColors[surfboardRandom:NextInteger(1, #surfboardColors)]
		for _, descendant in ipairs(board:GetDescendants()) do
			if descendant:IsA("BasePart") then
				-- Un tinte por tabla para distinguirlas sin alterar la geometría del asset.
				descendant.Color = boardColor
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
				descendant.Massless = true
			end
		end

		local _, originalBounds = board:GetBoundingBox()
		local longestAxis = math.max(originalBounds.X, originalBounds.Y, originalBounds.Z)
		if longestAxis <= 0.01 then
			warn("[BLOXY-KART][SURFBOARD] El modelo tiene dimensiones inválidas; se omite esta instancia.")
			board:Destroy()
			return false
		end

		local targetLength = 8.0 * (scale or 1)
		local scaled, scaleError = pcall(function()
			board:ScaleTo(targetLength / longestAxis)
		end)
		if not scaled then
			warn("[BLOXY-KART][SURFBOARD] No se pudo ajustar la escala: " .. tostring(scaleError))
			board:Destroy()
			return false
		end

		local boxCFrame, boxSize = board:GetBoundingBox()
		local pivotToBox = board:GetPivot():ToObjectSpace(boxCFrame)
		local targetBox = CFrame.new(pos)
			* CFrame.Angles(0, math.rad(rotY or 0), 0)
			* CFrame.Angles(0, 0, math.rad(leanDeg or 12))
			* CFrame.new(0, boxSize.Y / 2, 0)
		board:PivotTo(targetBox * pivotToBox:Inverse())
		return true
	end

	-- Centro de referencia del circuito Beach Resort (derivado del trazado de waypoints).
	-- Las tablas se distribuyen en claros perimetrales visibles desde la pista, sin invadir asfalto ni barreras.
	local TRACK_CENTER = Vector3.new(5, yGround, -15)
	local surfboardPlacements = {
		-- Sector de playa oriental/suroriental.
		{ offset = Vector3.new(170, 0, 180), rot = 30, lean = 12, scale = 1.00 },
		{ offset = Vector3.new(178, 0, 165), rot = -20, lean = 18, scale = 0.96 },
		{ offset = Vector3.new(185, 0, 150), rot = 45, lean = 8, scale = 1.04 },
		{ offset = Vector3.new(192, 0, 178), rot = -35, lean = 15, scale = 0.92 },
		{ offset = Vector3.new(158, 0, 195), rot = 18, lean = 10, scale = 1.02 },
		-- Costado oriental, visibles desde las curvas del lado derecho.
		{ offset = Vector3.new(185, 0, 75), rot = 65, lean = 14, scale = 0.98 },
		{ offset = Vector3.new(185, 0, -5), rot = -55, lean = 9, scale = 1.06 },
		{ offset = Vector3.new(170, 0, -95), rot = 25, lean = 16, scale = 0.94 },
		-- Sector norte y noroeste, junto a los claros de arena.
		{ offset = Vector3.new(95, 0, -175), rot = -30, lean = 12, scale = 1.00 },
		{ offset = Vector3.new(5, 0, -185), rot = 50, lean = 7, scale = 0.95 },
		{ offset = Vector3.new(-85, 0, -175), rot = -65, lean = 15, scale = 1.03 },
		-- Sector sur, repartidas para que el atrezo se lea desde distintos tramos.
		{ offset = Vector3.new(65, 0, 175), rot = -15, lean = 11, scale = 0.97 },
		{ offset = Vector3.new(-35, 0, 175), rot = 40, lean = 17, scale = 1.05 },
		{ offset = Vector3.new(-125, 0, 145), rot = -45, lean = 10, scale = 0.93 },
		{ offset = Vector3.new(-155, 0, -105), rot = 20, lean = 13, scale = 1.01 },
	}
	for _, placement in ipairs(surfboardPlacements) do
		local worldPos = TRACK_CENTER + placement.offset
		spawnSurfboard(worldPos, placement.rot, placement.lean, placement.scale)
	end

	-- Checkpoints
	local checkpointsFolder = Workspace:FindFirstChild("CourseCheckpoints") or Instance.new("Folder")
	checkpointsFolder.Name = "CourseCheckpoints"
	checkpointsFolder.Parent = Workspace
	for _, child in ipairs(checkpointsFolder:GetChildren()) do
		if child.Name == "FinishLine" or child.Name:match("^Checkpoint_%d+$") then child:Destroy() end
	end

	local debugTrans = KartConfig.DEBUG_CHECKPOINTS and 0.75 or 1
	local triggerHeight = 15
	local triggerThickness = 2
	local triggerSpan = 48

	local finishCF = CFrame.lookAt(Vector3.new(gantryX, yGround + triggerHeight / 2, 70), Vector3.new(gantryX - 10, yGround + triggerHeight / 2, 70))
	local finishPart = makePart(checkpointsFolder, "FinishLine", Vector3.new(triggerSpan, triggerHeight, triggerThickness), finishCF, Color3.fromRGB(255, 255, 255))
	finishPart.Transparency = debugTrans
	finishPart.CanCollide = false
	finishPart.CanTouch = true
	finishPart.CanQuery = false
	finishPart:SetAttribute("CheckpointIndex", 0)

	local checkpointDefinitions = {
		{ pos = Vector3.new(-35, yGround + triggerHeight / 2, 70),     target = Vector3.new(-65, yGround + triggerHeight / 2, 70) },
		{ pos = Vector3.new(-90, yGround + triggerHeight / 2, 55),     target = Vector3.new(-115, yGround + triggerHeight / 2, 40) },
		{ pos = Vector3.new(-115, yGround + triggerHeight / 2, -5),    target = Vector3.new(-115, yGround + triggerHeight / 2, -50) },
		{ pos = Vector3.new(-97.5, yGround + triggerHeight / 2, -72.5),target = Vector3.new(-80, yGround + triggerHeight / 2, -95) },
		{ pos = Vector3.new(-65, yGround + triggerHeight / 2, -95),    target = Vector3.new(-50, yGround + triggerHeight / 2, -95) },
		{ pos = Vector3.new(-50, yGround + triggerHeight / 2, -55),    target = Vector3.new(-50, yGround + triggerHeight / 2, -15) },
		{ pos = Vector3.new(-37.5, yGround + triggerHeight / 2, -2.5), target = Vector3.new(-25, yGround + triggerHeight / 2, 10) },
		{ pos = Vector3.new(-12.5, yGround + triggerHeight / 2, -2.5), target = Vector3.new(0, yGround + triggerHeight / 2, -15) },
		{ pos = Vector3.new(0, yGround + triggerHeight / 2, -50),      target = Vector3.new(0, yGround + triggerHeight / 2, -85) },
		{ pos = Vector3.new(22.5, yGround + triggerHeight / 2, -95),   target = Vector3.new(45, yGround + triggerHeight / 2, -105) },
		{ pos = Vector3.new(65, yGround + triggerHeight / 2, -85),     target = Vector3.new(85, yGround + triggerHeight / 2, -65) },
		{ pos = Vector3.new(105, yGround + triggerHeight / 2, -37.5),  target = Vector3.new(125, yGround + triggerHeight / 2, -10) },
		{ pos = Vector3.new(125, yGround + triggerHeight / 2, 12.5),   target = Vector3.new(125, yGround + triggerHeight / 2, 35) },
		{ pos = Vector3.new(115, yGround + triggerHeight / 2, 50),     target = Vector3.new(105, yGround + triggerHeight / 2, 65) },
	}

	for idx, def in ipairs(checkpointDefinitions) do
		local cpCF = CFrame.lookAt(def.pos, def.target)
		local cpPart = makePart(checkpointsFolder, "Checkpoint_" .. idx, Vector3.new(triggerSpan, triggerHeight, triggerThickness), cpCF, Color3.fromRGB(0, 170, 255))
		cpPart.Transparency = debugTrans
		cpPart.CanCollide = false
		cpPart.CanTouch = true
		cpPart.CanQuery = false
		cpPart:SetAttribute("CheckpointIndex", idx)
	end
end

-- ==========================================================
-- 2. ENSAMBLAJE ROBUSTO DEL KART
-- ==========================================================
local function weldTo(root, part)
	part.Anchored = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = root
end

local KART_VISUAL_SCALE = 0.85

local function scaleVisualCFrame(chassis, cframe)
	local localCFrame = chassis.CFrame:ToObjectSpace(cframe)
	local scaledPosition = localCFrame.Position * KART_VISUAL_SCALE
	return chassis.CFrame * CFrame.new(scaledPosition) * (localCFrame - localCFrame.Position)
end

local function makeVisualPart(model, chassis, name, size, cframe, color, material, shapeOrClass)
	local scaledSize = size * KART_VISUAL_SCALE
	local scaledCFrame = scaleVisualCFrame(chassis, cframe)
	local part = makePart(model, name, scaledSize, scaledCFrame, color, material, shapeOrClass)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
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

	local startX = 45 + (spawnIndex - 1) * 12
	local startZ = 70
	local spawnCFrame = CFrame.lookAt(
		Vector3.new(startX, COURSE_SURFACE_Y + 1.8, startZ),
		Vector3.new(startX - 10, COURSE_SURFACE_Y + 1.8, startZ)
	)

	local chassis = makePart(model, "Chassis", Vector3.new(4.8, 0.4, 6.4), spawnCFrame, Color3.fromRGB(25, 27, 30), Enum.Material.Metal)
	chassis.Anchored = false
	chassis.CustomPhysicalProperties = PhysicalProperties.new(1.2, 0.05, 0.05, 10, 1)
	model.PrimaryPart = chassis

	local C_BLACK   = Color3.fromRGB(26, 28, 32)
	local C_DARK    = Color3.fromRGB(38, 40, 45)
	local C_RED     = Color3.fromRGB(205, 35, 35)
	local C_YELLOW  = Color3.fromRGB(245, 195, 25)
	local C_WHITE   = Color3.fromRGB(242, 242, 245)
	local C_ENGINE  = Color3.fromRGB(110, 115, 125)
	local C_EXHAUST = Color3.fromRGB(160, 165, 175)
	local C_TIRE    = Color3.fromRGB(32, 35, 40)
	local C_RIM     = Color3.fromRGB(60, 65, 75)

	local function visual(name, size, offset, color, material, shapeOrClass)
		return makeVisualPart(model, chassis, name, size, spawnCFrame * offset, color, material, shapeOrClass)
	end
	local function visualRod(name, startOffset, endOffset, thickness, color, material)
		return makeVisualRod(model, chassis, name, startOffset, endOffset, thickness, color, material, spawnCFrame)
	end

	visual("FloorPan", Vector3.new(3.2, 0.15, 5.2), CFrame.new(0, 0.08, 0.1), C_RED)
	visual("ChassisRailL", Vector3.new(0.2, 0.22, 4.8), CFrame.new(-1.45, 0.18, 0.1), C_BLACK)
	visual("ChassisRailR", Vector3.new(0.2, 0.22, 4.8), CFrame.new(1.45, 0.18, 0.1), C_BLACK)

	for _, side in ipairs({ -1, 1 }) do
		local sideName = side < 0 and "L" or "R"
		visual("SidePodRed_" .. sideName, Vector3.new(0.85, 0.5, 2.5), CFrame.new(side * 1.85, 0.32, 0.15), C_RED)
		visual("SidePodYellowTop_" .. sideName, Vector3.new(0.65, 0.08, 1.6), CFrame.new(side * 1.85, 0.6, 0.0), C_YELLOW)
		visual("SidePodWhiteSide_" .. sideName, Vector3.new(0.06, 0.35, 0.85), CFrame.new(side * 2.29, 0.32, 0.8), C_WHITE)
		visual("SidePodYellowSide_" .. sideName, Vector3.new(0.06, 0.16, 1.2), CFrame.new(side * 2.29, 0.18, -0.2), C_YELLOW)
	end

	visual("BumperBarLower", Vector3.new(3.8, 0.24, 0.24), CFrame.new(0, 0.2, -3.25), C_BLACK)
	visual("BumperBarUpper", Vector3.new(3.0, 0.24, 0.24), CFrame.new(0, 0.52, -3.25), C_BLACK)
	visual("BumperPostL", Vector3.new(0.24, 0.58, 0.25), CFrame.new(-1.15, 0.36, -3.26), C_BLACK)
	visual("BumperPostR", Vector3.new(0.24, 0.58, 0.25), CFrame.new(1.15, 0.36, -3.26), C_BLACK)
	visual("FrontNoseBaseRed", Vector3.new(2.8, 0.35, 0.85), CFrame.new(0, 0.25, -2.7), C_RED)

	local wedgeRot = CFrame.Angles(0, math.pi, 0)
	visual("NoseYellowOuter", Vector3.new(1.6, 0.85, 1.8), CFrame.new(0, 0.65, -1.9) * wedgeRot, C_YELLOW, nil, "WedgePart")
	visual("NoseRedCenter", Vector3.new(0.95, 0.88, 1.82), CFrame.new(0, 0.66, -1.9) * wedgeRot, C_RED, nil, "WedgePart")
	visual("NoseWhitePlate", Vector3.new(0.7, 0.90, 0.75), CFrame.new(0, 0.82, -1.55) * wedgeRot, C_WHITE, nil, "WedgePart")

	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(1.8, 0.4, 1.6)
	seat.CFrame = spawnCFrame * CFrame.new(0, 0.75, 0.25)
	seat.Transparency = 1
	seat.Anchored = false
	seat.CanCollide = false
	seat.Massless = true
	seat.HeadsUpDisplay = false -- Desactiva el velocímetro nativo que Roblox muestra al ocupar el VehicleSeat.
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.Parent = model

	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = chassis
	seatWeld.Part1 = seat
	seatWeld.Parent = chassis

	visual("SeatBase", Vector3.new(1.6, 0.18, 1.4), CFrame.new(0, 0.22, 0.25), C_DARK)
	visual("SeatBolsterL", Vector3.new(0.2, 0.55, 1.3), CFrame.new(-0.75, 0.5, 0.25), C_DARK)
	visual("SeatBolsterR", Vector3.new(0.2, 0.55, 1.3), CFrame.new(0.75, 0.5, 0.25), C_DARK)
	visual("SeatBack", Vector3.new(1.6, 1.85, 0.25), CFrame.new(0, 1.25, 0.95) * CFrame.Angles(math.rad(-16), 0, 0), C_DARK)

	local steerCenter = Vector3.new(0, 1.5, -0.9)
	local steerAngle = CFrame.Angles(math.rad(25), 0, 0)
	visualRod("SteeringColumn", Vector3.new(0, 0.4, -0.7), Vector3.new(0, 1.45, -0.9), 0.12, C_BLACK, Enum.Material.Metal)
	for i = 1, 8 do
		local angle = (i - 1) * math.pi / 4
		local ringPos = steerCenter + Vector3.new(math.cos(angle) * 0.36, math.sin(angle) * 0.36, 0)
		visual("SteerRim" .. i, Vector3.new(0.08, 0.26, 0.08), CFrame.new(ringPos) * steerAngle * CFrame.Angles(0, 0, angle), C_BLACK)
	end
	visual("SteerHub", Vector3.new(0.18, 0.18, 0.12), CFrame.new(steerCenter) * steerAngle, C_DARK)

	visual("EngineBlock", Vector3.new(1.6, 1.1, 1.3), CFrame.new(0, 1.05, 1.9), C_ENGINE, Enum.Material.Metal)
	visual("EngineCylinderHead", Vector3.new(1.4, 0.35, 1.1), CFrame.new(0, 1.7, 1.9), C_DARK, Enum.Material.Metal)
	local exhaustL = CFrame.new(-1.05, 1.25, 2.2) * CFrame.Angles(math.rad(28), math.rad(-20), 0)
	visual("ExhaustL", Vector3.new(0.38, 0.38, 1.4), exhaustL, C_EXHAUST, Enum.Material.Metal, "Cylinder")
	local exhaustR = CFrame.new(1.05, 1.25, 2.2) * CFrame.Angles(math.rad(28), math.rad(20), 0)
	visual("ExhaustR", Vector3.new(0.38, 0.38, 1.4), exhaustR, C_EXHAUST, Enum.Material.Metal, "Cylinder")

	visual("SpoilerPillarL", Vector3.new(0.18, 1.35, 0.25), CFrame.new(-0.85, 1.85, 2.55) * CFrame.Angles(math.rad(-12), 0, 0), C_BLACK)
	visual("SpoilerPillarR", Vector3.new(0.18, 1.35, 0.25), CFrame.new(0.85, 1.85, 2.55) * CFrame.Angles(math.rad(-12), 0, 0), C_BLACK)
	visual("SpoilerWingPlank", Vector3.new(3.8, 0.22, 0.8), CFrame.new(0, 2.45, 2.68) * CFrame.Angles(math.rad(5), 0, 0), C_BLACK)
	visual("SpoilerEndplateL", Vector3.new(0.15, 0.75, 1.05), CFrame.new(-1.96, 2.55, 2.68) * CFrame.Angles(math.rad(5), 0, 0), C_BLACK)
	visual("SpoilerEndplateR", Vector3.new(0.15, 0.75, 1.05), CFrame.new(1.96, 2.55, 2.68) * CFrame.Angles(math.rad(5), 0, 0), C_BLACK)
	visual("RearBumperBar", Vector3.new(4.0, 0.28, 0.28), CFrame.new(0, 0.26, 3.05), C_BLACK)

	local wheelConfigs = {
		{ name = "FrontL", pos = Vector3.new(-2.25, 0.18, -1.95), width = 0.85, diam = 1.35, isRight = false },
		{ name = "FrontR", pos = Vector3.new(2.25, 0.18, -1.95), width = 0.85, diam = 1.35, isRight = true },
		{ name = "RearL",  pos = Vector3.new(-2.35, 0.28, 2.1),   width = 1.15, diam = 1.55, isRight = false },
		{ name = "RearR",  pos = Vector3.new(2.35, 0.28, 2.1),   width = 1.15, diam = 1.55, isRight = true },
	}
	for _, w in ipairs(wheelConfigs) do
		visual("Wheel_" .. w.name, Vector3.new(w.width, w.diam, w.diam), CFrame.new(w.pos), C_TIRE, Enum.Material.Rubber, "Cylinder")
		local rimOffset = w.pos + Vector3.new((w.isRight and 1 or -1) * (w.width / 2 + 0.02), 0, 0)
		visual("Rim_" .. w.name, Vector3.new(0.08, w.diam * 0.58, w.diam * 0.58), CFrame.new(rimOffset), C_RIM, Enum.Material.Metal, "Cylinder")
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
	prompt.MaxActivationDistance = 14
	prompt.Parent = seat
	prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer ~= player then return end
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
			if model.Parent then model:SetAttribute("NetworkOwnerUserId", 0) end
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
		end
	end
	seat:GetPropertyChangedSignal("Occupant"):Connect(updateNetworkOwner)
	task.defer(updateNetworkOwner)
	return kart
end

-- ==========================================================
-- 3. VALIDACIÓN DE CARRERA Y CHECKPOINTS (BACKEND)
-- ==========================================================
local TOTAL_INTERMEDIATE_CHECKPOINTS = 14

local function initPlayerRaceData(player, spawnCFrame)
	player:SetAttribute("RaceLap", 1)
	player:SetAttribute("RaceCheckpoint", 0)
	raceData[player] = {
		CurrentLap = 1,
		NextCheckpoint = 1,
		TotalCheckpoints = TOTAL_INTERMEDIATE_CHECKPOINTS,
		LastValidCFrame = spawnCFrame,
		LapStartTime = 0.0,
		BestLapTime = nil,
		CanFinishLap = false,
		IsWrongWay = false,
		LastTriggerTime = 0.0,
	}
end

local function onCheckpointTouched(hitPart, triggerPart)
	if hitPart.Name ~= "Chassis" then return end
	local kartModel = hitPart.Parent
	if not kartModel or not kartModel:IsA("Model") then return end

	local ownerUserId = kartModel:GetAttribute("OwnerUserId")
	if typeof(ownerUserId) ~= "number" then return end

	local player = Players:GetPlayerByUserId(ownerUserId)
	if not player then return end

	local pData = raceData[player]
	if not pData then return end

	local now = os.clock()
	if now - pData.LastTriggerTime < (KartConfig.CHECKPOINT_DEBOUNCE_TIME or 0.4) then
		return
	end

	local cpIndex = triggerPart:GetAttribute("CheckpointIndex")
	if typeof(cpIndex) ~= "number" then return end

	local chassis = hitPart
	local dotProduct = chassis.CFrame.LookVector:Dot(triggerPart.CFrame.LookVector)
	local isFacingWrongWay = dotProduct < (KartConfig.WRONG_WAY_DOT_THRESHOLD or -0.2)
	
	if isFacingWrongWay ~= pData.IsWrongWay then
		pData.IsWrongWay = isFacingWrongWay
		wrongWayRemote:FireClient(player, isFacingWrongWay)
	end

	if cpIndex == 0 then
		if pData.CanFinishLap then
			pData.LastTriggerTime = now
			local lapTime = now - pData.LapStartTime
			local isBest = (pData.BestLapTime == nil) or (lapTime < pData.BestLapTime)
			if isBest then
				pData.BestLapTime = lapTime
			end

			lapCompletedRemote:FireClient(player, pData.CurrentLap, lapTime, isBest)
			pData.CurrentLap = pData.CurrentLap + 1
			player:SetAttribute("RaceLap", pData.CurrentLap)
			player:SetAttribute("RaceCheckpoint", 0)
			pData.NextCheckpoint = 1
			pData.CanFinishLap = false
			pData.LapStartTime = now
			pData.LastValidCFrame = triggerPart.CFrame
		elseif pData.LapStartTime == 0.0 and pData.NextCheckpoint == 1 then
			pData.LastTriggerTime = now
			pData.LapStartTime = now
			pData.LastValidCFrame = triggerPart.CFrame
			checkpointPassedRemote:FireClient(player, 0, TOTAL_INTERMEDIATE_CHECKPOINTS)
		end
		return
	end

	if cpIndex == pData.NextCheckpoint then
		pData.LastTriggerTime = now
		pData.LastValidCFrame = triggerPart.CFrame
		pData.NextCheckpoint = pData.NextCheckpoint + 1
		player:SetAttribute("RaceCheckpoint", cpIndex)
		checkpointPassedRemote:FireClient(player, cpIndex, TOTAL_INTERMEDIATE_CHECKPOINTS)

		if pData.NextCheckpoint > TOTAL_INTERMEDIATE_CHECKPOINTS then
			pData.CanFinishLap = true
		end
	end
end

local function hookCheckpoints()
	local folder = Workspace:WaitForChild("CourseCheckpoints", 10)
	if not folder then return end

	for _, trigger in ipairs(folder:GetChildren()) do
		if trigger:IsA("BasePart") then
			trigger.Touched:Connect(function(hit)
				onCheckpointTouched(hit, trigger)
			end)
		end
	end
end

requestRespawnRemote.OnServerEvent:Connect(function(player)
	local kart = activeKarts[player]
	local pData = raceData[player]
	if not kart or not kart.chassis.Parent then return end

	local targetCF = (pData and pData.LastValidCFrame) or kart.spawnCFrame
	local respawnOffset = Vector3.new(0, KartConfig.RESPAWN_Y_OFFSET or 3.0, 0)

	kart.chassis.CFrame = targetCF + respawnOffset
	kart.chassis.AssemblyLinearVelocity = Vector3.zero
	kart.chassis.AssemblyAngularVelocity = Vector3.zero

	if pData and pData.IsWrongWay then
		pData.IsWrongWay = false
		wrongWayRemote:FireClient(player, false)
	end
end)

-- ==========================================================
-- 4. GESTIÓN Y SPAWN DEL PILOTO
-- ==========================================================
local function spawnPlayerKart(player)
	player:SetAttribute("RaceStarted", false)
	player:SetAttribute("RaceCountdownActive", false)
	player:SetAttribute("RaceCamera", nil)
	selectedCameras[player] = nil
	raceInProgress = false
	countdownToken += 1
	local current = activeKarts[player]
	if current then
		current.model:Destroy()
	end

	local spawnIndex = player:GetAttribute("KartSpawnIndex") or 1
	local kart = createKart(player, spawnIndex)
	activeKarts[player] = kart
	driverInputs[player] = { throttle = 0, steering = 0, braking = false }
	player:SetAttribute("KartOwnerUserId", player.UserId)

	initPlayerRaceData(player, kart.spawnCFrame)

	local function seatCharacter(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not humanoid or not root or not kart.model.Parent then return end

		root.CFrame = kart.spawnCFrame * CFrame.new(0, 4, 1)
		task.wait(0.15)
		if kart.seat.Parent and not kart.seat.Occupant then
			kart.seat:Sit(humanoid)
		end
		if kart.seat.Occupant == humanoid and not player:GetAttribute("RaceStarted") then
			player:SetAttribute("RaceCountdownActive", false)
			player:SetAttribute("RaceCamera", nil)
			selectedCameras[player] = nil
			driverInputs[player] = { throttle = 0, steering = 0, braking = false }
			publishSelectionState()
		end
	end

	player.CharacterAdded:Connect(seatCharacter)
	if player.Character then
		task.spawn(seatCharacter, player.Character)
	end
end

remote.OnServerEvent:Connect(function(player, throttle, steering, braking)
	if typeof(throttle) ~= "number" or typeof(steering) ~= "number" or typeof(braking) ~= "boolean" then return end
	local kart = activeKarts[player]
	local occupant = kart and kart.seat.Occupant
	local isAuthorizedDriver = occupant ~= nil and occupant.Parent == player.Character
	if throttle ~= throttle or steering ~= steering or not isAuthorizedDriver then return end
	if player:GetAttribute("RaceStarted") ~= true then
		driverInputs[player] = { throttle = 0, steering = 0, braking = false }
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
		if not kart.chassis.Parent then continue end
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
			kart.lastDiagnosticPosition = kart.chassis.Position
		end
	end
end)

buildTestCourse()
hookCheckpoints()

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
	if kart then kart.model:Destroy() end
	activeKarts[player] = nil
	selectedCameras[player] = nil
	driverInputs[player] = nil
	raceData[player] = nil
	if raceInProgress then raceInProgress=false; countdownToken+=1; for _,p in ipairs(Players:GetPlayers()) do p:SetAttribute("RaceStarted",false); p:SetAttribute("RaceCountdownActive",false) end end
	task.defer(function() publishSelectionState(); tryStartRace() end)
end)

return true
