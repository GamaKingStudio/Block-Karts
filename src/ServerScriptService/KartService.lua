local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local InsertService = game:GetService("InsertService")
local DataStoreService = game:GetService("DataStoreService")

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
local startRaceFromLobbyRemote = getOrCreateRemote("StartRaceFromLobby")
local raceFinishedRemote = getOrCreateRemote("RaceFinished")
local returnToLobbyRemote = getOrCreateRemote("ReturnToLobby")
local anotherRaceRemote = getOrCreateRemote("AnotherRace")
local returnedToLobbyRemote = getOrCreateRemote("ReturnedToLobby")

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
local ghostRecords = {}
local selectedCameras = {}
local finishCruiseStates = {}

-- Estadísticas persistentes para los marcadores del garaje.
-- DataStore no está disponible en experiencias sin publicar o sin API Services.
-- Su fallo no debe impedir cargar el circuito ni iniciar una carrera en Studio.
local bestLapStore, winsStore
local storesOk, storesError = pcall(function()
 bestLapStore = DataStoreService:GetOrderedDataStore("BloxyKartz_BestLapMs_v1")
 winsStore = DataStoreService:GetOrderedDataStore("BloxyKartz_RaceWins_v1")
end)
if not storesOk then
 bestLapStore, winsStore = nil, nil
 warn("[GARAGE-LEADERBOARD] Estadísticas persistentes desactivadas en esta sesión: " .. tostring(storesError))
end
local function formatLapTime(milliseconds)
 local total = math.max(0, tonumber(milliseconds) or 0) / 1000
 return string.format("%02d:%06.3f", math.floor(total / 60), total % 60)
end
local function refreshLeaderboard(boardName, store, ascending, valueFormatter)
 if not store then return end
 task.spawn(function()
  local garage = Workspace:FindFirstChild("BlockKartsGarage")
  local board = garage and garage:FindFirstChild(boardName)
  local display = board and board:FindFirstChild("LeaderboardDisplay")
  local panel = display and display:FindFirstChild("Panel")
  if not panel then return end
  local ok, pages = pcall(function() return store:GetSortedAsync(ascending, 5) end)
  if not ok or not pages then warn("[GARAGE-LEADERBOARD] No se pudieron leer " .. boardName); return end
  local page = pages:GetCurrentPage()
  for i = 1, 5 do
   local row = panel:FindFirstChild("LeaderboardRow" .. i)
   local entry = page[i]
   if row then
    if entry then
     local username = "Piloto"
     local userId = tonumber(entry.key)
     if userId then
      local nameOk, name = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
      if nameOk and name then username = name end
     end
     row.Text = string.format("%d   %-16s   %s", i, username, valueFormatter(entry.value))
    else row.Text = string.format("%d   ---", i) end
   end
  end
 end)
end
local function saveBestLap(player, lapTime)
 if not bestLapStore then return end
 task.spawn(function()
  local value = math.floor(lapTime * 1000 + 0.5)
  local ok = pcall(function()
   bestLapStore:UpdateAsync(tostring(player.UserId), function(old)
    if type(old) == "number" then return math.min(old, value) end
    return value
   end)
  end)
  if ok then refreshLeaderboard("TimesBoard", bestLapStore, true, formatLapTime)
  else warn("[GARAGE-LEADERBOARD] No se pudo guardar el mejor tiempo de " .. player.Name) end
 end)
end
local function saveRaceWin(player)
 if not winsStore then return end
 task.spawn(function()
  local ok = pcall(function()
   winsStore:UpdateAsync(tostring(player.UserId), function(old) return (tonumber(old) or 0) + 1 end)
  end)
  if ok then refreshLeaderboard("WinsBoard", winsStore, false, function(value) return tostring(value) end)
  else warn("[GARAGE-LEADERBOARD] No se pudo guardar la victoria de " .. player.Name) end
 end)
end

task.spawn(function()
 local garage = Workspace:WaitForChild("BlockKartsGarage", 120)
 if garage then
  task.wait(2)
  refreshLeaderboard("TimesBoard", bestLapStore, true, formatLapTime)
  refreshLeaderboard("WinsBoard", winsStore, false, function(value) return tostring(value) end)
 end
end)

local raceInProgress = false
local countdownToken = 0
local roomBusyPlayer = nil
local cpuKart = nil
local cpuRace = nil
local function getRacePlayers()
 local list = {}
 for _, p in ipairs(Players:GetPlayers()) do
  if p:GetAttribute("InRaceRoom") == true and activeKarts[p] then table.insert(list, p) end
 end
 return list
end
local function publishSelectionState()
 local list = getRacePlayers()
 local ready = 0
 for _, p in ipairs(list) do
  local k = activeKarts[p]
  if selectedCameras[p] and k and k.seat.Parent and k.seat.Occupant and k.seat.Occupant.Parent == p.Character then ready += 1 end
 end
 for _, p in ipairs(list) do selectionStateRemote:FireClient(p, ready, #list, selectedCameras[p] ~= nil) end
end
local function tryStartRace()
 if raceInProgress then return end
 local list = getRacePlayers()
 if #list ~= 1 then return end
 for _, p in ipairs(list) do
  local k = activeKarts[p]
  if not k or not k.seat.Parent or not k.seat.Occupant or k.seat.Occupant.Parent ~= p.Character or not selectedCameras[p] then publishSelectionState(); return end
 end
 raceInProgress = true
 countdownToken += 1
 local token = countdownToken
 for _, p in ipairs(list) do
  p:SetAttribute("RaceCountdownActive", true)
  p:SetAttribute("RaceStarted", false)
  driverInputs[p] = { throttle = 0, steering = 0, braking = false }
 end
 if cpuRace then cpuRace.started = false end
 task.spawn(function()
  for n = 5, 1, -1 do
   if token ~= countdownToken then return end
   for _, p in ipairs(list) do raceCountdownRemote:FireClient(p, n) end
   task.wait(1)
  end
  if token ~= countdownToken then return end
  for _, p in ipairs(list) do
   local k = activeKarts[p]
   if k and k.seat.Parent and k.seat.Occupant and k.seat.Occupant.Parent == p.Character then
    local d = raceData[p]
    if d then
     d.LapStartTime = os.clock()
     d.RaceStartTime = d.LapStartTime
     d.RaceCompleted = false
      p:SetAttribute("RaceResult", nil)
      p:SetAttribute("RaceFinalPosition", nil)
      p:SetAttribute("RaceBestLapTime", nil)
      p:SetAttribute("RaceTotalTime", nil)
      d.GhostSamples = {}
     d.LastGhostSampleAt = 0
     d.CanFinishLap = false
     if k and k.chassis then
      table.insert(d.GhostSamples, { t = 0, cf = k.chassis.CFrame })
     end
    end
    p:SetAttribute("RaceStarted", true)
    raceCountdownRemote:FireClient(p, 0)
   end
  end
  -- El rival permanece oculto y detenido durante toda la primera vuelta.
  -- Se activa únicamente al cruzar la meta y tener grabada la vuelta del jugador.
  if cpuRace then
    cpuRace.started = false
  end
 end)
end
cameraSelectionRemote.OnServerEvent:Connect(function(p, mode)
 if raceInProgress or p:GetAttribute("InRaceRoom") ~= true or (mode ~= "Classic" and mode ~= "Isometric") then return end
 local k = activeKarts[p]
 if not k or not k.seat.Parent or not k.seat.Occupant or k.seat.Occupant.Parent ~= p.Character then return end
 selectedCameras[p] = mode
 p:SetAttribute("RaceCamera", mode)
 publishSelectionState()
 tryStartRace()
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
-- Genera la ruta de la baranda como un offset continuo del eje de la pista.
-- Curvas exteriores: arco redondeado. Curvas interiores y tramos que pasan cerca
-- de otra parte del circuito: se recorta todo lo que quede a menos de
-- (offset - 0.25) del eje, asi la baranda nunca entra en el asfalto.
-- Devuelve una lista de cadenas; cada cadena es una lista de puntos {x=, z=}.
-- Offset path (guardrail) generator: pure 2D math, {x=,z=} tables.
local function computeGuardrailChains(points, offset, side)
	local count = #points
	local clearance = offset - 0.25
	local arcStep = math.rad(12)

	local function unit(ax, az, bx, bz)
		local dx, dz = bx - ax, bz - az
		local m = math.sqrt(dx * dx + dz * dz)
		if m < 0.0001 then return 0, -1 end
		return dx / m, dz / m
	end

	-- 1) Offset "crudo": un borde por tramo + arco en las curvas exteriores.
	local raw = {}
	for i = 1, count do
		local a = points[i]
		local b = points[i % count + 1]
		local c = points[(i + 1) % count + 1]
		local d1x, d1z = unit(a.x, a.z, b.x, b.z)
		local d2x, d2z = unit(b.x, b.z, c.x, c.z)
		local n1x, n1z = -d1z * side, d1x * side
		local n2x, n2z = -d2z * side, d2x * side
		raw[#raw + 1] = { x = a.x + n1x * offset, z = a.z + n1z * offset }
		raw[#raw + 1] = { x = b.x + n1x * offset, z = b.z + n1z * offset }
		-- Giro hacia este lado (curva interior): no hace falta arco.
		local turnsToward = (n1x * d2x + n1z * d2z) > 0
		if not turnsToward then
			local a1 = math.atan2(n1z, n1x)
			local a2 = math.atan2(n2z, n2x)
			local delta = a2 - a1
			while delta > math.pi do delta -= 2 * math.pi end
			while delta < -math.pi do delta += 2 * math.pi end
			local steps = math.floor(math.abs(delta) / arcStep)
			for k = 1, steps do
				local ang = a1 + delta * (k / (steps + 1))
				raw[#raw + 1] = { x = b.x + math.cos(ang) * offset, z = b.z + math.sin(ang) * offset }
			end
		end
	end

	-- 2) Recorta cada borde crudo: se descarta todo lo que queda a menos de
	--    `clearance` del eje de la pista (cubre bucles de curvas interiores y
	--    tramos que pasan cerca de otra parte del circuito).
	local function blockedInterval(px, pz, dx, dz, s)
		local ax, az = s.a.x, s.a.z
		local bx, bz = s.b.x, s.b.z
		local lo, hi = math.huge, -math.huge
		local function add(l, h)
			if l < lo then lo = l end
			if h > hi then hi = h end
		end
		local function circle(cx, cz)
			local fx, fz = px - cx, pz - cz
			local qa = dx * dx + dz * dz
			local qb = 2 * (fx * dx + fz * dz)
			local qc = fx * fx + fz * fz - clearance * clearance
			local disc = qb * qb - 4 * qa * qc
			if qa > 1e-9 and disc >= 0 then
				local sq = math.sqrt(disc)
				add((-qb - sq) / (2 * qa), (-qb + sq) / (2 * qa))
			end
		end
		circle(ax, az)
		circle(bx, bz)
		-- Franja rectangular del tramo.
		local ux, uz = s.ux, s.uz
		local vx, vz = -uz, ux
		local s0 = (px - ax) * ux + (pz - az) * uz
		local s1 = dx * ux + dz * uz
		local w0 = (px - ax) * vx + (pz - az) * vz
		local w1 = dx * vx + dz * vz
		local tl, th = -math.huge, math.huge
		local function slab(v0, v1, minV, maxV)
			if math.abs(v1) < 1e-9 then
				if v0 < minV or v0 > maxV then tl, th = 1, 0 end
			else
				local t1, t2 = (minV - v0) / v1, (maxV - v0) / v1
				if t1 > t2 then t1, t2 = t2, t1 end
				if t1 > tl then tl = t1 end
				if t2 < th then th = t2 end
			end
		end
		slab(s0, s1, 0, s.len)
		slab(w0, w1, -clearance, clearance)
		if tl < th then add(tl, th) end
		if lo < hi then return lo, hi end
		return nil
	end

	local segs = {}
	for i = 1, count do
		local a, b = points[i], points[i % count + 1]
		local ux, uz = unit(a.x, a.z, b.x, b.z)
		segs[i] = { a = a, b = b, ux = ux, uz = uz, len = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2) }
	end

	local pieces = {}
	for k = 1, #raw do
		local p, q = raw[k], raw[k % #raw + 1]
		local dx, dz = q.x - p.x, q.z - p.z
		local length = math.sqrt(dx * dx + dz * dz)
		if length > 0.0001 then
			local blocked = {}
			for _, s in ipairs(segs) do
				local lo, hi = blockedInterval(p.x, p.z, dx, dz, s)
				if lo and hi > 0 and lo < 1 then
					blocked[#blocked + 1] = { math.max(lo, 0), math.min(hi, 1) }
				end
			end
			table.sort(blocked, function(u, v) return u[1] < v[1] end)
			local cursor = 0
			local function emit(t0, t1)
				if (t1 - t0) * length > 0.25 then
					pieces[#pieces + 1] = {
						{ x = p.x + dx * t0, z = p.z + dz * t0 },
						{ x = p.x + dx * t1, z = p.z + dz * t1 },
					}
				end
			end
			for _, iv in ipairs(blocked) do
				if iv[1] > cursor then emit(cursor, iv[1]) end
				if iv[2] > cursor then cursor = iv[2] end
			end
			if cursor < 1 then emit(cursor, 1) end
		end
	end

	-- 3) Une los trozos consecutivos en cadenas continuas.
	local function near(u, v, tol)
		return (u.x - v.x) ^ 2 + (u.z - v.z) ^ 2 <= tol * tol
	end
	local chains = {}
	for _, piece in ipairs(pieces) do
		local last = chains[#chains]
		if last and near(last[#last], piece[1], 1.0) then
			last[#last + 1] = piece[2]
		else
			chains[#chains + 1] = { piece[1], piece[2] }
		end
	end
	if #chains > 1 and near(chains[#chains][#chains[#chains]], chains[1][1], 1.0) then
		local tail = table.remove(chains)
		for k = 2, #chains[1] do tail[#tail + 1] = chains[1][k] end
		chains[1] = tail
	end
	return chains
end

-- Baranda divisoria: donde dos partes NO consecutivas del circuito corren tan
-- juntas que no caben las barandas exteriores (borde a borde < 2 * 5 studs),
-- se coloca UNA sola baranda por la linea media entre ambas. Se limita a puntos
-- que quedan fuera del asfalto y se conecta con los extremos de las barandas.
local function computeDividerChains(points, railOffset, railChains)
	local count = #points
	local step = 3
	local safeDistance = 19 -- borde de pista (18) + margen para el muro

	local function distanceToCenterline(x, z)
		local best = math.huge
		for i = 1, count do
			local a, b = points[i], points[i % count + 1]
			local dx, dz = b.x - a.x, b.z - a.z
			local lenSq = dx * dx + dz * dz
			local t = lenSq > 0 and math.clamp(((x - a.x) * dx + (z - a.z) * dz) / lenSq, 0, 1) or 0
			local ex, ez = x - (a.x + dx * t), z - (a.z + dz * t)
			local d = math.sqrt(ex * ex + ez * ez)
			if d < best then best = d end
		end
		return best
	end

	local samples = {}
	local cumulative = 0
	for i = 1, count do
		local a, b = points[i], points[i % count + 1]
		local dx, dz = b.x - a.x, b.z - a.z
		local length = math.sqrt(dx * dx + dz * dz)
		local pieces = math.max(1, math.floor(length / step))
		for k = 0, pieces - 1 do
			local t = k / pieces
			samples[#samples + 1] = { x = a.x + dx * t, z = a.z + dz * t, s = cumulative + length * t }
		end
		cumulative += length
	end
	local total = cumulative
	local minSeparation = 120
	local maxDistance = railOffset * 2 + 1
	local minDistance = 37

	local chains = {}
	local current = nil
	for i, p in ipairs(samples) do
		local bestDistance, bestIndex = math.huge, nil
		for j, q in ipairs(samples) do
			local ds = math.abs(p.s - q.s)
			ds = math.min(ds, total - ds)
			if ds > minSeparation then
				local d = math.sqrt((p.x - q.x) ^ 2 + (p.z - q.z) ^ 2)
				if d < bestDistance then bestDistance, bestIndex = d, j end
			end
		end
		local accepted = false
		-- Solo i < j: cada franja se detecta desde sus dos lados, usamos uno.
		if bestIndex and bestIndex > i and bestDistance < maxDistance and bestDistance > minDistance then
			local q = samples[bestIndex]
			local mx, mz = (p.x + q.x) / 2, (p.z + q.z) / 2
			if distanceToCenterline(mx, mz) >= safeDistance then
				accepted = true
				local mid = { x = mx, z = mz }
				if current and i - current.last == 1 then
					current.points[#current.points + 1] = mid
					current.last = i
				else
					current = { points = { mid }, last = i }
					chains[#chains + 1] = current
				end
			end
		end
		if not accepted then current = nil end
	end

	-- Extremos abiertos de las barandas exteriores.
	local openEnds = {}
	for _, chain in ipairs(railChains) do
		openEnds[#openEnds + 1] = chain[1]
		openEnds[#openEnds + 1] = chain[#chain]
	end
	local function connectionIsSafe(p, q)
		local length = math.sqrt((q.x - p.x) ^ 2 + (q.z - p.z) ^ 2)
		local pieces = math.max(1, math.ceil(length))
		for k = 0, pieces do
			local t = k / pieces
			if distanceToCenterline(p.x + (q.x - p.x) * t, p.z + (q.z - p.z) * t) < safeDistance - 0.5 then
				return false
			end
		end
		return true
	end
	local function nearestEnd(p)
		local best, bestDistance = nil, 30
		for _, e in ipairs(openEnds) do
			local d = math.sqrt((e.x - p.x) ^ 2 + (e.z - p.z) ^ 2)
			if d < bestDistance and connectionIsSafe(p, e) then best, bestDistance = e, d end
		end
		return best
	end

	local result = {}
	for _, c in ipairs(chains) do
		local pts = c.points
		if #pts >= 2 then
			local first = nearestEnd(pts[1])
			if first then table.insert(pts, 1, { x = first.x, z = first.z }) end
			local last = nearestEnd(pts[#pts])
			if last then pts[#pts + 1] = { x = last.x, z = last.z } end
			result[#result + 1] = pts
		end
	end
	return result
end

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

	-- Beach Resort ampliado: se conserva la recta de salida y el sector norte,
	-- y se añade un bucle exterior al sureste con curvas rápidas y una zona técnica.
	local trackWidth = 36
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
		Vector3.new(170, yGround + 0.02, 45),
		Vector3.new(205, yGround + 0.02, 85),
		Vector3.new(215, yGround + 0.02, 135),
		Vector3.new(185, yGround + 0.02, 180),
		Vector3.new(135, yGround + 0.02, 205),
		Vector3.new(75, yGround + 0.02, 205),
		Vector3.new(35, yGround + 0.02, 175),
		Vector3.new(25, yGround + 0.02, 135),
		Vector3.new(75, yGround + 0.02, 145),
		Vector3.new(130, yGround + 0.02, 145),
		Vector3.new(155, yGround + 0.02, 100),
		Vector3.new(150, yGround + 0.02, 75),
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

	-- Barandas: visibles (postes + vigas) y barrera invisible de colision salen
	-- de la MISMA ruta corregida, que siempre queda fuera del asfalto.
	local railCenterline = {}
	for i = 1, uniqueCount do
		railCenterline[i] = { x = waypoints[i].X, z = waypoints[i].Z }
	end

	local railJobs = {}
	local sideChains = {}
	for sideIndex, side in ipairs({ -1, 1 }) do
		for chainIndex, chain in ipairs(computeGuardrailChains(railCenterline, guardrailOffset, side)) do
			railJobs[#railJobs + 1] = { sideIndex = sideIndex, chainIndex = chainIndex, chain = chain }
			sideChains[#sideChains + 1] = chain
		end
	end
	-- Una sola baranda en el centro donde dos tramos de pista corren pegados.
	for chainIndex, chain in ipairs(computeDividerChains(railCenterline, guardrailOffset, sideChains)) do
		railJobs[#railJobs + 1] = { sideIndex = 3, chainIndex = chainIndex, chain = chain }
	end

	for _, job in ipairs(railJobs) do
		do
			local sideIndex, chainIndex, chain = job.sideIndex, job.chainIndex, job.chain
			local cumulative = { 0 }
			for k = 2, #chain do
				local dx = chain[k].x - chain[k - 1].x
				local dz = chain[k].z - chain[k - 1].z
				cumulative[k] = cumulative[k - 1] + math.sqrt(dx * dx + dz * dz)
			end
			local total = cumulative[#chain]

			if total > 0.5 then
				-- Postes repartidos por distancia sobre la cadena.
				local postCount = math.max(1, math.ceil(total / guardrailPostSpacing))
				local segIndex = 1
				for postIndex = 0, postCount do
					local distance = total * postIndex / postCount
					while segIndex < #chain - 1 and cumulative[segIndex + 1] < distance do
						segIndex += 1
					end
					local p1, p2 = chain[segIndex], chain[segIndex + 1]
					local segLength = cumulative[segIndex + 1] - cumulative[segIndex]
					local alpha = segLength > 0.001 and math.clamp((distance - cumulative[segIndex]) / segLength, 0, 1) or 0
					local px = p1.x + (p2.x - p1.x) * alpha
					local pz = p1.z + (p2.z - p1.z) * alpha
					local postDirection = Vector3.new(p2.x - p1.x, 0, p2.z - p1.z)
					postDirection = postDirection.Magnitude > 0.001 and postDirection.Unit or Vector3.new(0, 0, -1)
					local post = makePart(
						course,
						("GuardrailPost_%d_%d_%d"):format(sideIndex, chainIndex, postIndex),
						Vector3.new(guardrailPostWidth, guardrailPostHeight, guardrailPostWidth),
						CFrame.new(px, yGround + guardrailPostHeight / 2, pz) * CFrame.lookAt(Vector3.zero, postDirection),
						C_GUARDRAIL_DARK,
						Enum.Material.Metal
					)
					post.CanTouch = false
				end

				-- Vigas visibles y barrera invisible, tramo por tramo, sobre la misma ruta.
				for k = 1, #chain - 1 do
					local a = Vector3.new(chain[k].x, 0, chain[k].z)
					local b = Vector3.new(chain[k + 1].x, 0, chain[k + 1].z)
					local segment = b - a
					local length = segment.Magnitude
					if length > 0.3 then
						local direction = segment.Unit
						local mid = (a + b) / 2
						for railIndex, railY in ipairs({ 1.05, 1.58 }) do
							local rail = makePart(
								course,
								("GuardrailBeam_%d_%d_%d_%d"):format(sideIndex, chainIndex, k, railIndex),
								Vector3.new(guardrailBeamThickness, guardrailBeamHeight, length + 0.015),
								CFrame.new(mid.X, yGround + railY, mid.Z) * CFrame.lookAt(Vector3.zero, direction),
								C_GUARDRAIL,
								Enum.Material.Metal
							)
							rail.CanTouch = false
						end

						local collisionBarrier = makePart(
							course,
							("GuardrailCollision_%d_%d_%d"):format(sideIndex, chainIndex, k),
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
		end
	end

	-- Arco de meta: el asset completo del usuario reemplaza los postes y el banner procedural.
	local gantryX = 0
	local spanWidth = trackWidth + 6
	local FINISH_STRUCTURE_ASSET_ID = 77625250062263
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
		Vector3.new(142, yGround, -12), Vector3.new(270, yGround, 115)
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
		Vector3.new(270, yGround, 35),
		Vector3.new(270, yGround, 145),
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
		{ pos = Vector3.new(285, yGround, 70), tilt = -5, yaw = 30, scale = 1.1 },
		{ pos = Vector3.new(280, yGround, 245), tilt = 6, yaw = -80, scale = 1.0 },
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
	spawnBeachCluster(Vector3.new(35, yGround, 270), -30)
	spawnBeachCluster(Vector3.new(95, yGround, 270), 10)

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
		-- Reubicadas hacia la playa exterior para despejar el nuevo bucle sureste.
		{ offset = Vector3.new(265, 0, 180), rot = 30, lean = 12, scale = 1.00 },
		{ offset = Vector3.new(275, 0, 155), rot = -20, lean = 18, scale = 0.96 },
		{ offset = Vector3.new(280, 0, 130), rot = 45, lean = 8, scale = 1.04 },
		{ offset = Vector3.new(285, 0, 185), rot = -35, lean = 15, scale = 0.92 },
		{ offset = Vector3.new(255, 0, 205), rot = 18, lean = 10, scale = 1.02 },
		-- Costado oriental, visibles desde las curvas del lado derecho.
		{ offset = Vector3.new(315, 0, -80), rot = 65, lean = 14, scale = 0.98 },
		{ offset = Vector3.new(185, 0, -5), rot = -55, lean = 9, scale = 1.06 },
		{ offset = Vector3.new(170, 0, -95), rot = 25, lean = 16, scale = 0.94 },
		-- Sector norte y noroeste, junto a los claros de arena.
		{ offset = Vector3.new(95, 0, -175), rot = -30, lean = 12, scale = 1.00 },
		{ offset = Vector3.new(5, 0, -185), rot = 50, lean = 7, scale = 0.95 },
		{ offset = Vector3.new(-85, 0, -175), rot = -65, lean = 15, scale = 1.03 },
		-- Sector sur, repartidas para que el atrezo se lea desde distintos tramos.
		{ offset = Vector3.new(315, 0, 255), rot = -15, lean = 11, scale = 0.97 },
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
	local triggerSpan = 60

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
		{ pos = Vector3.new(147.5, yGround + triggerHeight / 2, 40),   target = Vector3.new(170, yGround + triggerHeight / 2, 45) },
		{ pos = Vector3.new(187.5, yGround + triggerHeight / 2, 65),   target = Vector3.new(205, yGround + triggerHeight / 2, 85) },
		{ pos = Vector3.new(210, yGround + triggerHeight / 2, 110),   target = Vector3.new(215, yGround + triggerHeight / 2, 135) },
		{ pos = Vector3.new(200, yGround + triggerHeight / 2, 157.5), target = Vector3.new(185, yGround + triggerHeight / 2, 180) },
		{ pos = Vector3.new(160, yGround + triggerHeight / 2, 192.5), target = Vector3.new(135, yGround + triggerHeight / 2, 205) },
		{ pos = Vector3.new(105, yGround + triggerHeight / 2, 205),   target = Vector3.new(75, yGround + triggerHeight / 2, 205) },
		{ pos = Vector3.new(55, yGround + triggerHeight / 2, 190),    target = Vector3.new(35, yGround + triggerHeight / 2, 175) },
		{ pos = Vector3.new(30, yGround + triggerHeight / 2, 155),    target = Vector3.new(25, yGround + triggerHeight / 2, 135) },
		{ pos = Vector3.new(50, yGround + triggerHeight / 2, 140),    target = Vector3.new(75, yGround + triggerHeight / 2, 145) },
		{ pos = Vector3.new(102.5, yGround + triggerHeight / 2, 145), target = Vector3.new(130, yGround + triggerHeight / 2, 145) },
		{ pos = Vector3.new(142.5, yGround + triggerHeight / 2, 122.5),target = Vector3.new(155, yGround + triggerHeight / 2, 100) },
		{ pos = Vector3.new(152.5, yGround + triggerHeight / 2, 87.5), target = Vector3.new(150, yGround + triggerHeight / 2, 75) },
		{ pos = Vector3.new(127.5, yGround + triggerHeight / 2, 70), target = Vector3.new(105, yGround + triggerHeight / 2, 65) },
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

-- Radio aproximado de una rueda: promedio de sus dos dimensiones mas grandes (el disco).
local function estimateWheelRadius(part)
	local size = part.Size
	local dims = { size.X, size.Y, size.Z }
	table.sort(dims, function(a, b) return a > b end)
	return math.max(0.3, (dims[1] + dims[2]) / 4)
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
	seat.CFrame = spawnCFrame * CFrame.new(0, 1.05, 0.25)
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

	-- Carga el kart original del usuario. El kart procedural solo se oculta
	-- después de comprobar que el modelo importado quedó montado correctamente.
	local CUSTOM_KART_ASSET_ID = 122554188649486
	local customKartAsset = nil
	local importedKart = nil
	local importedParts = 0
	local customKartError = nil
	-- Solo las ruedas delanteras usan articulaciones orientables.
	-- Las traseras permanecen soldadas al chasis.
	local kartWheelMotors = {}

	local loadOk, loadResult = pcall(function()
		return InsertService:LoadAsset(CUSTOM_KART_ASSET_ID)
	end)

	if loadOk and loadResult then
		customKartAsset = loadResult
		local setupOk, setupError = pcall(function()
			local sourceModel = customKartAsset:IsA("Model") and customKartAsset
				or customKartAsset:FindFirstChildWhichIsA("Model", true)
			assert(sourceModel, "El asset no contiene un Model")

			importedKart = sourceModel:Clone()
			importedKart.Name = "CustomKartBody"

			local initialParts = {}
			for _, descendant in ipairs(importedKart:GetDescendants()) do
				if descendant:IsA("BasePart") then
					table.insert(initialParts, descendant)
				end
			end
			assert(#initialParts > 0, "El modelo importado no contiene piezas BasePart")

			-- El asset original tiene la trompa hacia su X local negativo.
			-- El chasis de carrera apunta hacia su Z local negativo (LookVector).
			-- Por eso el cuerpo visual necesita -90 grados respecto del chasis.
			-- En el asset, la pieza de ejes/manguetas invade el volumen de las
			-- cuatro ruedas. Las desplazamos hacia fuera sobre el eje lateral
			-- original del modelo antes de escalarlo y orientarlo.
			-- Se conservan las posiciones laterales originales de las cuatro ruedas.
			-- El desplazamiento artificial anterior (+/-23 unidades) separaba
			-- los neumáticos del chasis y ensanchaba innecesariamente el kart.

			local _, orientedBounds = importedKart:GetBoundingBox()
			assert(
				orientedBounds.X > 0 and orientedBounds.Y > 0 and orientedBounds.Z > 0,
				"El modelo tiene dimensiones inválidas"
			)

			-- El largo va sobre X y el ancho sobre Z. El ancho objetivo aumenta
			-- ligeramente para dejar espacio real entre neumáticos y ejes.
			local targetWidth, targetLength, targetHeight = 8.5, 10.0, 4.8
			local scale = math.min(
				targetWidth / orientedBounds.Z,
				targetLength / orientedBounds.X,
				targetHeight / orientedBounds.Y
			)
			assert(scale > 0 and scale < 20, "La escala calculada no es válida")
			importedKart:ScaleTo(importedKart:GetScale() * scale)

			-- Centramos la caja geométrica (no el pivote arbitrario del asset)
			-- sobre el chasis y conservamos la orientación ya corregida.
			local scaledBoundsCFrame = importedKart:GetBoundingBox()
			local targetBoundsCFrame = spawnCFrame
				* CFrame.Angles(0, math.rad(-90), 0)
				* CFrame.new(0, 0.75, 0)
			local pivotOffset = scaledBoundsCFrame:ToObjectSpace(importedKart:GetPivot())
			importedKart:PivotTo(targetBoundsCFrame * pivotOffset)

			-- Alinea el punto más bajo de los cuatro neumáticos con la superficie
			-- real de la pista. Evita que el cuerpo parezca suspendido por encima
			-- del suelo debido al margen incluido en el bounding box del asset.
			local wheelNamesForGrounding = {
				Rueda_Delantera_Der = true,
				Rueda_Delantera_Izq = true,
				Rueda_Trasera_Der = true,
				Rueda_Trasera_Izq = true,
			}
			local lowestWheelY = math.huge
			for _, wheelPart in ipairs(importedKart:GetDescendants()) do
				if wheelPart:IsA("BasePart") and wheelNamesForGrounding[wheelPart.Name] then
					local cf = wheelPart.CFrame
					local size = wheelPart.Size
					local halfHeight =
						math.abs(cf.RightVector.Y) * size.X / 2
						+ math.abs(cf.UpVector.Y) * size.Y / 2
						+ math.abs(cf.LookVector.Y) * size.Z / 2
					lowestWheelY = math.min(lowestWheelY, wheelPart.Position.Y - halfHeight)
				end
			end
			if lowestWheelY < math.huge then
				local groundOffset = (COURSE_SURFACE_Y + 0.03) - lowestWheelY
				importedKart:PivotTo(importedKart:GetPivot() + Vector3.new(0, groundOffset, 0))
				print(("[CUSTOM-KART-GROUND] lowestWheelY=%.3f targetY=%.3f offset=%.3f"):format(
					lowestWheelY, COURSE_SURFACE_Y + 0.03, groundOffset
				))
			else
				warn("[CUSTOM-KART-GROUND] No se encontraron las cuatro ruedas por nombre; se conserva la altura anterior.")
			end

			-- Diagnóstico visual: registra la orientación real de cada neumático
			-- respecto del chasis, sin alterar la geometría ni el manejo.
			local wheelDiagnosticNames = {
				Rueda_Delantera_Der = true,
				Rueda_Delantera_Izq = true,
				Rueda_Trasera_Der = true,
				Rueda_Trasera_Izq = true,
			}
			print(("[CUSTOM-KART-WHEEL-DIAG] bounds=(%.2f, %.2f, %.2f) scale=%.5f"):format(
				orientedBounds.X, orientedBounds.Y, orientedBounds.Z, scale
			))
			for _, wheelPart in ipairs(importedKart:GetDescendants()) do
				if wheelPart:IsA("BasePart") and wheelDiagnosticNames[wheelPart.Name] then
					local localCF = chassis.CFrame:ToObjectSpace(wheelPart.CFrame)
					local localSize = wheelPart.Size
					print(("[CUSTOM-KART-WHEEL-DIAG] %s pos=(%.3f, %.3f, %.3f) size=(%.3f, %.3f, %.3f) right=(%.3f, %.3f, %.3f) up=(%.3f, %.3f, %.3f) look=(%.3f, %.3f, %.3f)"):format(
						wheelPart.Name,
						localCF.Position.X, localCF.Position.Y, localCF.Position.Z,
						localSize.X, localSize.Y, localSize.Z,
						localCF.RightVector.X, localCF.RightVector.Y, localCF.RightVector.Z,
						localCF.UpVector.X, localCF.UpVector.Y, localCF.UpVector.Z,
						localCF.LookVector.X, localCF.LookVector.Y, localCF.LookVector.Z
					))
				end
			end

			-- Las ruedas del lado -X deben mirar hacia fuera, igual que las del lado +X.
			-- El modelo importado trae las cuatro con el mismo sentido lateral.
			for _, wheelPart in ipairs(importedKart:GetDescendants()) do
				if wheelPart:IsA("BasePart") and (
					wheelPart.Name == "Rueda_Delantera_Der"
					or wheelPart.Name == "Rueda_Delantera_Izq"
					or wheelPart.Name == "Rueda_Trasera_Der"
					or wheelPart.Name == "Rueda_Trasera_Izq"
				) then
					local wheelLocalPosition = chassis.CFrame:PointToObjectSpace(wheelPart.Position)
					if wheelLocalPosition.X < 0 then
						wheelPart.CFrame = wheelPart.CFrame * CFrame.Angles(0, math.rad(180), 0)
					end
				end
			end

			importedKart.Parent = model
			-- Paleta definitiva del kart: rojo/amarillo en carrocería,
			-- grises en chasis y neumáticos. Se asigna por nombre para no
			-- alterar la geometría ni las articulaciones del modelo.
			local kartColors = {
				red = Color3.fromRGB(190, 28, 35),
				yellow = Color3.fromRGB(255, 195, 25),
				chassis = Color3.fromRGB(112, 118, 125),
				tire = Color3.fromRGB(48, 51, 56),
				seat = Color3.fromRGB(45, 47, 51),
				metal = Color3.fromRGB(135, 140, 146),
			}
			local kartWheelNames = {
				Rueda_Delantera_Der = true,
				Rueda_Delantera_Izq = true,
				Rueda_Trasera_Der = true,
				Rueda_Trasera_Izq = true,
			}
			for _, part in ipairs(importedKart:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 0
					part.LocalTransparencyModifier = 0
					part.Reflectance = 0

					local name = part.Name
					if kartWheelNames[name] then
						-- La rueda importada es una sola MeshPart; por ahora se
						-- pinta completa de gris oscuro. El centro requiere una
						-- pieza de tapa independiente o una textura UV específica.
						part.Color = kartColors.tire
						part.Material = Enum.Material.Rubber
					elseif name == "Carroceria_Frontal" or name == "Carroceria_Pontones" then
						part.Color = kartColors.red
						part.Material = Enum.Material.SmoothPlastic
					elseif name == "Carroceria_Columna_Trompa" or name == "Carroceria_Piso_Azul" then
						part.Color = kartColors.yellow
						part.Material = Enum.Material.SmoothPlastic
					elseif name:find("Chasis_", 1, true) then
						part.Color = kartColors.chassis
						part.Material = Enum.Material.Metal
					elseif name == "Equipamiento_Asiento" then
						part.Color = kartColors.seat
						part.Material = Enum.Material.SmoothPlastic
					elseif name == "Equipamiento_Motor_Escapes" then
						part.Color = kartColors.metal
						part.Material = Enum.Material.Metal
					elseif name == "Equipamiento_Volante" then
						part.Color = kartColors.yellow
						part.Material = Enum.Material.SmoothPlastic
					else
						-- Cualquier pieza adicional conserva un acabado neutro.
						part.Color = kartColors.chassis
						part.Material = Enum.Material.SmoothPlastic
					end
					if part:IsA("MeshPart") then
						part.DoubleSided = true
						-- El alpha de la textura importada estaba dejando ver el fondo.
						-- Overlay conserva el color de la malla sin aplicar transparencia por alpha.
						local surfaceAppearance = part:FindFirstChildOfClass("SurfaceAppearance")
						if surfaceAppearance then
							surfaceAppearance.AlphaMode = Enum.AlphaMode.Opaque
						end
					end
					part.Anchored = false
					part.Massless = true
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false

					-- El asset trae la rueda trasera con transparencia heredada.
					-- Forzamos opacidad completa en los cuatro neumáticos.
					if part.Name == "Rueda_Delantera_Der"
						or part.Name == "Rueda_Delantera_Izq"
						or part.Name == "Rueda_Trasera_Der"
						or part.Name == "Rueda_Trasera_Izq" then
						part.Transparency = 0
						part.LocalTransparencyModifier = 0
						part.CastShadow = true
						-- Algunas mallas importadas tienen caras visibles solo desde un lado.
						-- Al invertir la rueda izquierda, DoubleSided evita el efecto hueco/transparente.
						if part:IsA("MeshPart") then
							part.DoubleSided = true
						end
					end

					local isFrontWheel = part.Name == "Rueda_Delantera_Der"
						or part.Name == "Rueda_Delantera_Izq"

					if kartWheelNames[name] then
						-- Cada rueda cuelga de un "cubo" invisible con los ejes del chasis:
						--   chasis -> cubo : direccion (ruedas delanteras) o soldadura (traseras)
						--   cubo   -> rueda: Motor6D "WheelSpin_*" que gira la rueda sobre su eje
						--                   (eje X del chasis). El giro lo anima cada cliente.
						local hubCFrame = chassis.CFrame.Rotation + part.Position
						local hub = Instance.new("Part")
						hub.Name = "WheelHub_" .. name
						hub.Size = Vector3.new(0.2, 0.2, 0.2)
						hub.Transparency = 1
						hub.CanCollide = false
						hub.CanTouch = false
						hub.CanQuery = false
						hub.CastShadow = false
						hub.Massless = true
						hub.Anchored = false
						hub.CFrame = hubCFrame
						hub.Parent = part.Parent

						local spinMotor = Instance.new("Motor6D")
						spinMotor.Name = "WheelSpin_" .. name
						spinMotor.Part0 = hub
						spinMotor.Part1 = part
						spinMotor.C0 = CFrame.new()
						spinMotor.C1 = part.CFrame:ToObjectSpace(hubCFrame)
						spinMotor:SetAttribute("WheelRadius", estimateWheelRadius(part))
						spinMotor.Parent = hub

						if isFrontWheel then
							-- Direccion: gira el cubo sobre el eje vertical del kart.
							local motor = Instance.new("Motor6D")
							motor.Name = "FrontWheelSteering_" .. part.Name
							motor.Part0 = chassis
							motor.Part1 = hub
							motor.C0 = chassis.CFrame:ToObjectSpace(hubCFrame)
							motor.C1 = CFrame.new()
							motor.Parent = chassis
							table.insert(kartWheelMotors, motor)
						else
							local hubWeld = Instance.new("WeldConstraint")
							hubWeld.Name = "WheelHubWeld"
							hubWeld.Part0 = chassis
							hubWeld.Part1 = hub
							hubWeld.Parent = chassis
						end
					else
						local weld = Instance.new("WeldConstraint")
						weld.Name = "CustomKartPartWeld"
						weld.Part0 = chassis
						weld.Part1 = part
						weld.Parent = chassis
					end
					importedParts += 1
				end
			end
			assert(importedParts > 0, "No se pudo unir ninguna pieza al chasis")

			-- Solo ahora se oculta el respaldo procedural.
			chassis.Transparency = 1
			chassis.CastShadow = false
			for _, oldPart in ipairs(model:GetChildren()) do
				if oldPart:IsA("BasePart") and oldPart ~= chassis and oldPart ~= seat then
					oldPart.Transparency = 1
					oldPart.CanCollide = false
					oldPart.CanTouch = false
					oldPart.CanQuery = false
				end
			end

			-- Anclajes invisibles para conservar el humo de derrape trasero.
			for _, wheel in ipairs({
				{ name = "Wheel_RearL", source = "Rueda_Trasera_Izq", offset = Vector3.new(-1.65, -0.15, 2.0) },
				{ name = "Wheel_RearR", source = "Rueda_Trasera_Der", offset = Vector3.new(1.65, -0.15, 2.0) },
			}) do
				-- El humo sale del punto de contacto de la rueda trasera real
				-- (antes salia del centro del kart, tapado por la carroceria).
				local markerOffset = wheel.offset
				local sourceWheel = importedKart:FindFirstChild(wheel.source, true)
				if sourceWheel and sourceWheel:IsA("BasePart") then
					markerOffset = chassis.CFrame:PointToObjectSpace(sourceWheel.Position)
						- Vector3.new(0, estimateWheelRadius(sourceWheel) * 0.85, 0)
				end
				local marker = Instance.new("Part")
				marker.Name = wheel.name
				marker.Size = Vector3.new(0.2, 0.2, 0.2)
				marker.Transparency = 1
				marker.CanCollide = false
				marker.CanTouch = false
				marker.CanQuery = false
				marker.Massless = true
				marker.CFrame = chassis.CFrame * CFrame.new(markerOffset)
				marker.Parent = model
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = chassis
				weld.Part1 = marker
				weld.Parent = chassis
			end
		end)

		if not setupOk then
			customKartError = setupError
			if importedKart then importedKart:Destroy() end
			importedKart = nil
			importedParts = 0
			warn(("[BLOXY-KART][SERVER][CUSTOM-KART-SETUP-FAILED] asset=%d error=%s"):format(CUSTOM_KART_ASSET_ID, tostring(setupError)))
		end
	else
		customKartError = loadResult
		warn(("[BLOXY-KART][SERVER][CUSTOM-KART-LOAD-FAILED] asset=%d error=%s"):format(CUSTOM_KART_ASSET_ID, tostring(loadResult)))
	end

	if importedKart and importedParts > 0 then
		print(("[BLOXY-KART][SERVER][CUSTOM-KART-LOADED] asset=%d parts=%d"):format(CUSTOM_KART_ASSET_ID, importedParts))
	else
		warn(("[BLOXY-KART][SERVER][PROCEDURAL-FALLBACK] asset=%d reason=%s"):format(CUSTOM_KART_ASSET_ID, tostring(customKartError or "modelo no válido")))
	end
	if customKartAsset then customKartAsset:Destroy() end

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
		wheelMotors = kartWheelMotors or {},
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
local TOTAL_INTERMEDIATE_CHECKPOINTS = 26

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
        RaceStartTime = 0,
        RaceCompleted = false,
		GhostSamples = {},
		LastGhostSampleAt = 0,
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
	if not pData or pData.RaceCompleted then return end

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
                saveBestLap(player, lapTime)
			end
            -- Guarda la vuelta 1 y activa el fantasma para la segunda vuelta.
            if pData.CurrentLap == 1 then
                table.insert(pData.GhostSamples, { t = lapTime, cf = hitPart.CFrame })
                if #pData.GhostSamples < 2 and pData.GhostSamples[1] then
                    table.insert(pData.GhostSamples, { t = lapTime, cf = hitPart.CFrame })
                end

                local recordedGhost = {
                    samples = table.clone(pData.GhostSamples),
                    duration = math.max(lapTime, 0.1),
                }
                ghostRecords[player.UserId] = recordedGhost

                if cpuRace and cpuRace.kart and cpuRace.kart.model then
                    local ghostModel = cpuRace.kart.model
                    cpuRace.ghostSamples = recordedGhost.samples
                    cpuRace.ghostDuration = recordedGhost.duration
                    cpuRace.estimatedLapDuration = recordedGhost.duration
                    cpuRace.ghostIndex = 1

                    -- Publica el kart fantasma antes de iniciar su reproducción.
                    -- Fuerza una transparencia uniforme para que no quede invisible.
                    ghostModel.Parent = kartsFolder
                    for _, ghostPart in ipairs(ghostModel:GetDescendants()) do
                        if ghostPart:IsA("BasePart") then
                            local originalTransparency = (cpuRace.hiddenTransparency or {})[ghostPart]
                            ghostPart.Transparency = math.clamp(originalTransparency or ghostPart.Transparency, 0.42, 0.75)
                            ghostPart.LocalTransparencyModifier = 0
                            ghostPart.CanCollide = false
                            ghostPart.CanTouch = false
                            ghostPart.CanQuery = false
                        elseif ghostPart:IsA("Decal") or ghostPart:IsA("Texture") then
                            local originalTransparency = (cpuRace.hiddenTransparency or {})[ghostPart]
                            ghostPart.Transparency = math.clamp(originalTransparency or ghostPart.Transparency, 0.42, 0.75)
                        end
                    end
                    cpuRace.hiddenTransparency = nil
                    if recordedGhost.samples[1] then
                        cpuRace.kart.chassis.CFrame = recordedGhost.samples[1].cf
                    end

                    if not ghostModel:FindFirstChild("FirstLapGhostHighlight") then
                        local highlight = Instance.new("Highlight")
                        highlight.Name = "FirstLapGhostHighlight"
                        highlight.FillColor = Color3.fromRGB(50, 220, 255)
                        highlight.FillTransparency = 0.68
                        highlight.OutlineColor = Color3.fromRGB(80, 235, 255)
                        highlight.OutlineTransparency = 0.12
                        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        highlight.Parent = ghostModel
                    end

                    cpuRace.startedAt = now
                    cpuRace.started = true
                    print(("[CPU-GHOST] Fantasma activado para vuelta 2: %d muestras, %.2fs, parent=%s"):format(
                        #recordedGhost.samples, lapTime, ghostModel.Parent:GetFullName()
                    ))
                else
                    warn("[CPU-GHOST] No existe un kart fantasma que activar al terminar la vuelta 1.")
                end
            end

			lapCompletedRemote:FireClient(player, pData.CurrentLap, lapTime, isBest)
            if pData.CurrentLap >= (KartConfig.TOTAL_LAPS or 3) and not pData.RaceCompleted then
                pData.RaceCompleted = true
                local totalTime = now - (pData.RaceStartTime > 0 and pData.RaceStartTime or now)
                local referenceLap = cpuRace and (cpuRace.ghostDuration or cpuRace.estimatedLapDuration)
                local referenceTime = referenceLap and referenceLap * (KartConfig.TOTAL_LAPS or 3) or math.huge
                local finalPosition = totalTime <= referenceTime and 1 or 2
                local resultText = finalPosition == 1 and "VICTORIA" or "SEGUNDO LUGAR"

                if finalPosition == 1 then saveRaceWin(player) end
                player:SetAttribute("RaceResult", resultText)
                player:SetAttribute("RaceFinalPosition", finalPosition)
                player:SetAttribute("RaceBestLapTime", pData.BestLapTime or 0)
                player:SetAttribute("RaceTotalTime", totalTime)
                player:SetAttribute("RaceStarted", false)
                player:SetAttribute("RaceCountdownActive", false)
                driverInputs[player] = { throttle = 0, steering = 0, braking = false }

                -- Piloto automático tras la meta: repite una vuelta real grabada.
                local finishedKart = activeKarts[player]
                if finishedKart and finishedKart.chassis and finishedKart.chassis.Parent then
                    finishedKart.chassis.AssemblyLinearVelocity = Vector3.zero
                    finishedKart.chassis.AssemblyAngularVelocity = Vector3.zero
                    if finishedKart.driveForce then finishedKart.driveForce.Enabled = false end
                    local cruiseSamples = pData.GhostSamples
                    if cruiseSamples and #cruiseSamples >= 2 then
                        finishedKart.chassis.Anchored = true
                        finishCruiseStates[player] = {
                            kart = finishedKart,
                            samples = table.clone(cruiseSamples),
                            duration = math.max(0.1, cruiseSamples[#cruiseSamples].t),
                            startedAt = os.clock(),
                            sampleIndex = 1,
                        }
                    end
                end

                raceFinishedRemote:FireClient(
                    player,
                    finalPosition,
                    pData.BestLapTime or 0,
                    totalTime,
                    resultText
                )
                print(("[RACE] %s terminó en posición %d en %.2fs; mejor vuelta %.2fs; referencia fantasma %.2fs"):format(
                    player.Name, finalPosition, totalTime, pData.BestLapTime or 0, referenceTime
                ))
            end
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
	if pData and pData.RaceCompleted then return end
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
local GARAGE_SPAWN_CFRAME = CFrame.new(520, 6.5, 12) * CFrame.Angles(0, math.rad(180), 0)

local function placeCharacterInGarage(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then return end

	-- Si el jugador ya solicitó entrar a una carrera, se sienta en su kart.
	local kart = activeKarts[player]
	if kart and kart.model.Parent and kart.seat.Parent then
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
		return
	end

	-- Espera a que el escenario del garaje exista antes de colocar al personaje.
	local garage = Workspace:WaitForChild("BlockKartsGarage", 60)
	if not garage then
		warn("[GARAGE] No se encontró BlockKartsGarage; no se pudo ubicar al jugador.")
		return
	end

	-- El lobby es el spawn por defecto. No se crea ni se ocupa ningún kart.
	player:SetAttribute("InGarage", true)
	player:SetAttribute("RaceStarted", false)
	player:SetAttribute("RaceCountdownActive", false)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = GARAGE_SPAWN_CFRAME
end

local function spawnPlayerKart(player)
	if activeKarts[player] then return end
	player:SetAttribute("InGarage", false)
	player:SetAttribute("RaceStarted", false)
	player:SetAttribute("RaceCountdownActive", false)
	player:SetAttribute("RaceCamera", nil)
	selectedCameras[player] = nil

	local spawnIndex = player:GetAttribute("KartSpawnIndex") or 1
	local kart = createKart(player, spawnIndex)
	activeKarts[player] = kart
	driverInputs[player] = { throttle = 0, steering = 0, braking = false }
	player:SetAttribute("KartOwnerUserId", player.UserId)
	initPlayerRaceData(player, kart.spawnCFrame)

	local character = player.Character
	if character then
		task.spawn(placeCharacterInGarage, player, character)
	end
end

startRaceFromLobbyRemote.OnServerEvent:Connect(function(player)
	if activeKarts[player] or player:GetAttribute("InGarage") ~= true or player:GetAttribute("InRaceRoom") ~= true then return end
	spawnPlayerKart(player)
end)

local function addFallbackCpuPilot(kart)
 if not kart or not kart.chassis or not kart.chassis.Parent then return end
 local rng = Random.new()
 local suitColors = {
  Color3.fromRGB(25, 105, 190),
  Color3.fromRGB(190, 45, 45),
  Color3.fromRGB(35, 145, 95),
  Color3.fromRGB(135, 75, 185),
  Color3.fromRGB(225, 135, 35),
 }
 local helmetColors = {
  Color3.fromRGB(245, 195, 35),
  Color3.fromRGB(35, 195, 210),
  Color3.fromRGB(235, 65, 65),
  Color3.fromRGB(235, 235, 240),
  Color3.fromRGB(45, 48, 55),
 }
 local skinColors = {
  Color3.fromRGB(242, 195, 155),
  Color3.fromRGB(190, 125, 85),
  Color3.fromRGB(120, 78, 55),
  Color3.fromRGB(225, 170, 125),
 }
 local suit = suitColors[rng:NextInteger(1, #suitColors)]
 local helmet = helmetColors[rng:NextInteger(1, #helmetColors)]
 local skin = skinColors[rng:NextInteger(1, #skinColors)]
 local chassis = kart.chassis

 local function pilotPart(name, size, offset, color, material, shape)
  local p = Instance.new("Part")
  p.Name = "CPU_Pilot_" .. name
  p.Size = size
  p.CFrame = chassis.CFrame * CFrame.new(offset)
  p.Color = color
  p.Material = material or Enum.Material.SmoothPlastic
  p.Anchored = false
  p.Massless = true
  p.CanCollide = false
  p.CanTouch = false
  p.CanQuery = false
  p.TopSurface = Enum.SurfaceType.Smooth
  p.BottomSurface = Enum.SurfaceType.Smooth
  if shape then p.Shape = shape end
  p.Parent = kart.model
  local weld = Instance.new("WeldConstraint")
  weld.Part0 = chassis
  weld.Part1 = p
  weld.Parent = p
  return p
 end

 -- Static blocky racer welded to the CPU chassis, seated above the hidden VehicleSeat.
 pilotPart("Torso", Vector3.new(1.15, 1.05, 0.55), Vector3.new(0, 2.05, 0.25), suit)
 pilotPart("Head", Vector3.new(0.72, 0.72, 0.72), Vector3.new(0, 2.95, 0.12), skin)
 pilotPart("Helmet", Vector3.new(0.92, 0.48, 0.9), Vector3.new(0, 3.36, 0.12), helmet, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
 pilotPart("Visor", Vector3.new(0.58, 0.2, 0.08), Vector3.new(0, 3.0, -0.27), Color3.fromRGB(22, 31, 42), Enum.Material.Glass)
 pilotPart("ArmL", Vector3.new(0.34, 0.95, 0.38), Vector3.new(-0.78, 2.0, -0.05), suit)
 pilotPart("ArmR", Vector3.new(0.34, 0.95, 0.38), Vector3.new(0.78, 2.0, -0.05), suit)
 pilotPart("GloveL", Vector3.new(0.34, 0.3, 0.34), Vector3.new(-0.78, 1.55, -0.38), Color3.fromRGB(28, 30, 34))
 pilotPart("GloveR", Vector3.new(0.34, 0.3, 0.34), Vector3.new(0.78, 1.55, -0.38), Color3.fromRGB(28, 30, 34))
 pilotPart("LegL", Vector3.new(0.42, 0.7, 0.45), Vector3.new(-0.32, 1.35, 0.48), Color3.fromRGB(30, 34, 42))
 pilotPart("LegR", Vector3.new(0.42, 0.7, 0.45), Vector3.new(0.32, 1.35, 0.48), Color3.fromRGB(30, 34, 42))
 kart.model:SetAttribute("HasCpuPilot", true)
end

local function getRandomFriend(player)
 if not player or not player.Parent then return nil end

 local ok, pages = pcall(function()
  return Players:GetFriendsAsync(player.UserId)
 end)
 if not ok or not pages then
  warn("[CPU] No se pudo consultar la lista de amigos; se usará piloto de respaldo.")
  return nil
 end

 local selected = nil
 local seen = 0
 local pageCount = 0
 repeat
  local pageOk, currentPage = pcall(function()
   return pages:GetCurrentPage()
  end)
  if not pageOk or type(currentPage) ~= "table" then break end

  for _, friend in ipairs(currentPage) do
   if friend and tonumber(friend.Id) then
    seen += 1
    -- Reservoir sampling: each friend in the complete list has the same chance.
    if math.random(1, seen) == 1 then
     selected = {
      UserId = tonumber(friend.Id),
      Username = tostring(friend.Username or "Friend"),
      DisplayName = tostring(friend.DisplayName or friend.Username or "Friend"),
     }
    end
   end
  end

  pageCount += 1
  if pages.IsFinished or pageCount >= 30 then break end
  local advanced = pcall(function()
   pages:AdvanceToNextPageAsync()
  end)
  if not advanced then break end
 until false

 if selected then
  print(("[CPU] Amigo elegido para el rival: %s (%d)"):format(selected.Username, selected.UserId))
 else
  print("[CPU] El jugador no tiene amigos disponibles para usar como rival.")
 end
 return selected
end

local function addCpuPilot(kart, player)
 if not kart or not kart.chassis or not kart.chassis.Parent then return end

 local friend = getRandomFriend(player)
 if friend then
  local ok, avatar = pcall(function()
   return Players:CreateHumanoidModelFromUserIdAsync(friend.UserId)
  end)

  if ok and avatar and avatar:IsA("Model") then
   local root = avatar:FindFirstChild("HumanoidRootPart")
   local humanoid = avatar:FindFirstChildOfClass("Humanoid")
   if root and humanoid then
    avatar.Name = "CPU_FriendPilot_" .. friend.Username
    avatar.Parent = kart.model
    -- Ajusta el avatar para que quepa en el kart y alinea la cadera con el asiento.
    avatar:ScaleTo(0.82)
    local pilotSeat = kart.seat
    local pilotBaseCFrame = pilotSeat and pilotSeat.CFrame or kart.chassis.CFrame
    avatar:PivotTo(pilotBaseCFrame * CFrame.new(0, 1.0, 0))

    for _, descendant in ipairs(avatar:GetDescendants()) do
     if descendant:IsA("BasePart") then
      descendant.Anchored = false
      descendant.Massless = true
      descendant.CanCollide = false
      descendant.CanTouch = false
      descendant.CanQuery = false
     end
    end

    humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
    humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    humanoid.AutoRotate = false
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0
    humanoid.PlatformStand = true

    local weld = Instance.new("WeldConstraint")
    weld.Name = "CPU_FriendPilotWeld"
    weld.Part0 = kart.chassis
    weld.Part1 = root
    weld.Parent = root

    kart.model:SetAttribute("CpuFriendUserId", friend.UserId)
    kart.model:SetAttribute("CpuFriendUsername", friend.Username)
    kart.model:SetAttribute("CpuFriendDisplayName", friend.DisplayName)
    kart.model:SetAttribute("HasCpuPilot", true)
    print(("[CPU] Avatar de amigo cargado: %s"):format(friend.Username))
    return
   end

   avatar:Destroy()
  else
   warn(("[CPU] No se pudo cargar el avatar de %s; se usará piloto de respaldo."):format(friend.Username))
  end
 end

 addFallbackCpuPilot(kart)
 kart.model:SetAttribute("CpuFriendUsername", "CPU")
end

local function createCpuOpponent(player)
 if cpuKart then cpuKart.model:Destroy(); cpuKart = nil end
 local kart = createKart({ UserId = -999001 }, 2)
 kart.model.Name = "Kart_CPU_01"
 kart.model:SetAttribute("IsCPUOpponent", true)
 kart.model:SetAttribute("OwnerUserId", -999001)
 addCpuPilot(kart, player)
 kart.chassis.Anchored = true
 kart.driveForce.Enabled = false
 cpuKart = kart
 local folder = Workspace:WaitForChild("CourseCheckpoints", 10)
 if not folder then warn("[CPU] No se encontró CourseCheckpoints."); return end
 local route = {}
 local finish = folder:FindFirstChild("FinishLine")
 if finish then table.insert(route, finish.Position) end
 for i = 1, TOTAL_INTERMEDIATE_CHECKPOINTS do
  local cp = folder:FindFirstChild("Checkpoint_" .. i)
  if cp then table.insert(route, cp.Position) end
 end
 if finish then table.insert(route, finish.Position) end
 if #route < 28 then warn(("[CPU] Ruta incompleta: %d puntos."):format(#route)); return end
 local routeDistance = 0
 for i = 1, #route - 1 do routeDistance += (route[i + 1] - route[i]).Magnitude end

 -- Guarda la transparencia original de cada pieza y oculta por completo
 -- el kart rival hasta que el jugador complete su primera vuelta.
 local hiddenTransparency = {}
 for _, descendant in ipairs(kart.model:GetDescendants()) do
  if descendant:IsA("BasePart") then
   hiddenTransparency[descendant] = descendant.Transparency
   descendant.Transparency = 1
   descendant.LocalTransparencyModifier = 0
   -- El rival no debe bloquear ni activar contactos mientras se graba la vuelta.
   descendant.CanCollide = false
   descendant.CanTouch = false
   descendant.CanQuery = false
  elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
   hiddenTransparency[descendant] = descendant.Transparency
   descendant.Transparency = 1
  end
 end  -- Mantiene al rival fuera de Workspace durante toda la primera vuelta.
  -- Ocultar la transparencia no basta para garantizar que no haya colisiones.
  kart.model.Parent = ServerStorage



 cpuRace = {


 kart = kart,
  route = route,
  targetIndex = 1,
  started = false,
  speed = 37,
  laps = 1,
  hiddenTransparency = hiddenTransparency,
  estimatedLapDuration = routeDistance / 37,
 }
 print("[CPU-GHOST] Rival oculto: esperando que el jugador complete la primera vuelta.")
end

local function returnPlayerToLobby(player)
 if roomBusyPlayer ~= player or player:GetAttribute("InRaceRoom") ~= true then return end

 countdownToken += 1
 raceInProgress = false
 local kart = activeKarts[player]
 if kart and kart.model then kart.model:Destroy() end
 activeKarts[player] = nil
 driverInputs[player] = nil
 raceData[player] = nil
 selectedCameras[player] = nil
 finishCruiseStates[player] = nil

 if cpuKart and cpuKart.model then cpuKart.model:Destroy() end
 cpuKart = nil
 cpuRace = nil
 roomBusyPlayer = nil

 player:SetAttribute("InRaceRoom", false)
 player:SetAttribute("InGarage", true)
 player:SetAttribute("RoomStatus", nil)
 player:SetAttribute("RaceStarted", false)
 player:SetAttribute("RaceCountdownActive", false)
 player:SetAttribute("RaceCamera", nil)
 player:SetAttribute("RaceResult", nil)
 player:SetAttribute("RaceFinalPosition", nil)
 player:SetAttribute("RaceBestLapTime", nil)
 player:SetAttribute("RaceTotalTime", nil)
 player:SetAttribute("RaceLap", 1)
 player:SetAttribute("RaceCheckpoint", 0)

 local character = player.Character
 local humanoid = character and character:FindFirstChildOfClass("Humanoid")
 if humanoid then humanoid.Sit = false end
 if character then task.spawn(placeCharacterInGarage, player, character) end
 returnedToLobbyRemote:FireClient(player)
 print(("[RACE] %s volvió al lobby."):format(player.Name))
end

returnToLobbyRemote.OnServerEvent:Connect(function(player)
 if not raceData[player] or not raceData[player].RaceCompleted then return end
 returnPlayerToLobby(player)
end)

anotherRaceRemote.OnServerEvent:Connect(function(player)
 local pData = raceData[player]
 local kart = activeKarts[player]
 if roomBusyPlayer ~= player or player:GetAttribute("InRaceRoom") ~= true
  or not pData or not pData.RaceCompleted or not kart or not kart.model.Parent
  or not kart.seat.Parent then return end

 -- Reinicia la misma sala y el mismo kart; no altera el circuito ni la cámara elegida.
 finishCruiseStates[player] = nil
 countdownToken += 1
 raceInProgress = false
 if cpuKart and cpuKart.model then cpuKart.model:Destroy() end
 cpuKart = nil
 cpuRace = nil
 createCpuOpponent(player)
 if not cpuKart or not cpuRace then
  warn("[RACE] No se pudo preparar el rival para la siguiente carrera.")
  return
 end

 kart.chassis.CFrame = kart.spawnCFrame
 kart.chassis.AssemblyLinearVelocity = Vector3.zero
 kart.chassis.AssemblyAngularVelocity = Vector3.zero
 kart.chassis.Anchored = false
 if kart.driveForce then kart.driveForce.Enabled = true end
 driverInputs[player] = { throttle = 0, steering = 0, braking = false }
 initPlayerRaceData(player, kart.spawnCFrame)
 player:SetAttribute("RaceResult", nil)
 player:SetAttribute("RaceFinalPosition", nil)
 player:SetAttribute("RaceBestLapTime", nil)
 player:SetAttribute("RaceTotalTime", nil)
 player:SetAttribute("RaceStarted", false)
 player:SetAttribute("RaceCountdownActive", false)
 player:SetAttribute("RoomStatus", "PREPARANDO OTRA CARRERA")
 selectedCameras[player] = player:GetAttribute("RaceCamera") or selectedCameras[player]
 if kart.seat.Occupant and kart.seat.Occupant.Parent == player.Character and selectedCameras[player] then
  player:SetAttribute("RoomStatus", "LISTO")
  task.defer(tryStartRace)
 else
  player:SetAttribute("RoomStatus", "ELIGE CÁMARA")
  publishSelectionState()
 end
 print(("[RACE] %s solicitó otra carrera."):format(player.Name))
end)

local function enterCpuRoom(player)
 if roomBusyPlayer or raceInProgress then return end
 if player:GetAttribute("InGarage") ~= true or activeKarts[player] then return end
 roomBusyPlayer = player
 player:SetAttribute("InRaceRoom", true)
 player:SetAttribute("RoomStatus", "PREPARANDO")
 player:SetAttribute("InGarage", false)
 player:SetAttribute("RaceStarted", false)
 player:SetAttribute("RaceCountdownActive", false)
 selectedCameras[player] = nil
 createCpuOpponent(player)
 if not cpuKart or not cpuRace then
  player:SetAttribute("InRaceRoom", false)
  player:SetAttribute("InGarage", true)
  roomBusyPlayer = nil
  return
 end
 spawnPlayerKart(player)
 player:SetAttribute("RoomStatus", "ELIGE CÁMARA")
 task.defer(publishSelectionState)
end

task.spawn(function()
 local garage = Workspace:WaitForChild("BlockKartsGarage", 120)
 if not garage then warn("[GARAGE] No se encontró BlockKartsGarage."); return end
 local pad = garage:WaitForChild("RoomEntryPad_1vCPU", 30)
 if not pad or not pad:IsA("BasePart") then warn("[GARAGE] No se encontró RoomEntryPad_1vCPU."); return end
 local debounce = {}
 pad.Touched:Connect(function(hit)
  local character = hit and hit:FindFirstAncestorOfClass("Model")
  local player = character and Players:GetPlayerFromCharacter(character)
  if not player or debounce[player] then return end
  debounce[player] = true
  task.delay(1.5, function() debounce[player] = nil end)
  enterCpuRoom(player)
 end)
 print("[GARAGE] Sala física 1 VS COMPUTADORA conectada.")
end)

RunService.Heartbeat:Connect(function(dt)
 -- Piloto automático después de terminar: reproduce el recorrido de la primera vuelta.
 for player, cruise in pairs(finishCruiseStates) do
  local kart = cruise.kart
  if not kart or not kart.chassis or not kart.chassis.Parent or not cruise.samples or #cruise.samples < 2 then
   finishCruiseStates[player] = nil
  else
   local elapsed = (os.clock() - cruise.startedAt) % cruise.duration
   local samples = cruise.samples
   while cruise.sampleIndex < #samples - 1 and samples[cruise.sampleIndex + 1].t < elapsed do
    cruise.sampleIndex += 1
   end
   local a = samples[cruise.sampleIndex]
   local b = samples[math.min(cruise.sampleIndex + 1, #samples)]
   if a and b then
    local span = math.max(0.001, b.t - a.t)
    local alpha = math.clamp((elapsed - a.t) / span, 0, 1)
    kart.chassis.CFrame = a.cf:Lerp(b.cf, alpha)
   end
   if elapsed < 0.12 then cruise.sampleIndex = 1 end
  end
 end

 -- Graba la posición y orientación del kart del jugador durante la primera vuelta.
 for player, data in pairs(raceData) do
  local kart = activeKarts[player]
  if kart and player:GetAttribute("RaceStarted") == true and data.CurrentLap == 1
   and data.LapStartTime > 0 and os.clock() - data.LastGhostSampleAt >= 0.1 then
   data.LastGhostSampleAt = os.clock()
   if #data.GhostSamples < 1800 then
    table.insert(data.GhostSamples, { t = os.clock() - data.LapStartTime, cf = kart.chassis.CFrame })
   end
  end
 end

 local state = cpuRace
 if not state or not state.started or not state.kart or not state.kart.chassis.Parent then return end
 local chassis = state.kart.chassis
 if state.ghostSamples and state.ghostDuration and state.ghostDuration > 0 then
  local elapsed = (os.clock() - (state.startedAt or os.clock())) % state.ghostDuration
  local samples = state.ghostSamples
  while state.ghostIndex < #samples - 1 and samples[state.ghostIndex + 1].t < elapsed do
   state.ghostIndex += 1
  end
  local a = samples[state.ghostIndex]
  local b = samples[math.min(state.ghostIndex + 1, #samples)]
  if a and b then
   local span = math.max(0.001, b.t - a.t)
   local alpha = math.clamp((elapsed - a.t) / span, 0, 1)
   chassis.CFrame = a.cf:Lerp(b.cf, alpha)
   chassis.AssemblyLinearVelocity = (b.cf.Position - a.cf.Position) / span
  end
  if elapsed < 0.12 then state.ghostIndex = 1 end
  return
 end
 local target = state.route[state.targetIndex]
 if not target then return end
 local destination = Vector3.new(target.X, COURSE_SURFACE_Y + 1.8, target.Z)
 local current = chassis.Position
 local flatDestination = Vector3.new(destination.X, current.Y, destination.Z)
 local offset = flatDestination - current
 local distance = offset.Magnitude
 if distance < 5 then
  state.targetIndex += 1
  if state.targetIndex > #state.route then state.targetIndex = 2; state.laps += 1 end
  return
 end
 local direction = offset.Unit
 local nextPosition = current + direction * math.min(distance, state.speed * math.min(dt, 0.05))
 chassis.CFrame = CFrame.lookAt(nextPosition, nextPosition + direction)
 chassis.AssemblyLinearVelocity = direction * state.speed
end)

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

RunService.Heartbeat:Connect(function(deltaTime)
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
		local forwardSpeed = velocity:Dot(chassis.CFrame.LookVector)
		if not isAuthorizedDriver and input and (input.throttle ~= 0 or input.steering ~= 0 or input.braking) then
			driverInputs[player] = { throttle = 0, steering = 0, braking = false }
		end

		-- Dirección visual: las ruedas traseras no tienen articulación y quedan fijas.
		-- Invertimos el signo para que la orientación visible coincida con A/D.
		local frontWheelAngle = math.rad(28) * steering
		for _, wheelMotor in ipairs(kart.wheelMotors or {}) do
			if wheelMotor.Parent then
				wheelMotor.Transform = CFrame.Angles(0, frontWheelAngle, 0)
			end
		end

		if DIAGNOSTICS_ENABLED and os.clock() >= kart.nextDiagnosticAt then
			kart.nextDiagnosticAt = os.clock() + DIAGNOSTIC_INTERVAL
			kart.lastDiagnosticPosition = kart.chassis.Position
		end
	end
end)

buildTestCourse()
hookCheckpoints()

local function setupLobbyPlayer(player, spawnIndex)
	player:SetAttribute("KartSpawnIndex", spawnIndex)
	player:SetAttribute("InGarage", true)
	player:SetAttribute("RaceStarted", false)
	player:SetAttribute("RaceCountdownActive", false)
	player:SetAttribute("RaceCamera", nil)
	player.CharacterAdded:Connect(function(character)
		task.spawn(placeCharacterInGarage, player, character)
	end)
	if player.Character then
		task.spawn(placeCharacterInGarage, player, player.Character)
	end
end

Players.PlayerAdded:Connect(function(player)
	setupLobbyPlayer(player, #Players:GetPlayers())
end)

for index, player in ipairs(Players:GetPlayers()) do
	setupLobbyPlayer(player, index)
end

Players.PlayerRemoving:Connect(function(player)
	local kart = activeKarts[player]
	if kart then kart.model:Destroy() end
	activeKarts[player] = nil
	selectedCameras[player] = nil
	driverInputs[player] = nil
	raceData[player] = nil
	finishCruiseStates[player] = nil
	if roomBusyPlayer == player then
		roomBusyPlayer = nil
		if cpuKart then cpuKart.model:Destroy(); cpuKart = nil end
		cpuRace = nil
		raceInProgress = false
		countdownToken += 1
	end
	if raceInProgress then
		raceInProgress = false
		countdownToken += 1
		for _, p in ipairs(Players:GetPlayers()) do
			p:SetAttribute("RaceStarted", false)
			p:SetAttribute("RaceCountdownActive", false)
		end
	end
	task.defer(function() publishSelectionState(); tryStartRace() end)
end)

return true
