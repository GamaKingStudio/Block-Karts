--[[
	LobbyBuilder (Script de servidor)
	Ruta Rojo:  src/ServerScriptService/LobbyBuilder.server.lua

	Construye por código un estacionamiento subterráneo viejo y cerrado:
	  - Pilares con bandas amarillo/negro y numeración
	  - Plazas de parqueo con líneas, topes y autos abandonados
	  - Luces fluorescentes (algunas muertas, otras parpadean)
	  - Tuberías, ductos y vigas en el techo
	  - Portón de salida cerrado
	  - ZONA DE MATCHMAKING con letrero neón (tag "MatchmakingZone")
	  - Pared norte con tableros: MEJOR VUELTA y MÁS CARRERAS GANADAS
	  - Spawn de jugadores

	NO toca la pista, los checkpoints ni la cámara.
	Todo es geometría sólida (sin texturas ni IDs de assets).
]]

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local Leaderboards = require(ServerScriptService:WaitForChild("Leaderboards"))

-- ---------------------------------------------------------------------------
-- CONFIGURACIÓN
-- ---------------------------------------------------------------------------
local ORIGIN = Vector3.new(520, 1, 0) -- centro del piso (misma zona del garage anterior)
local W, D, H = 180, 160, 20          -- garage ampliado: 180 studs de ancho, 160 de largo, 20 de alto
local REMOVE_OLD_GARAGE = true        -- borra Workspace.BlockKartsGarage si existe
local MODEL_NAME = "BlockKartsGarage"

local rng = Random.new(1337)          -- semilla fija: el garage siempre sale igual

local C = {
	floor = Color3.fromRGB(58, 58, 63),
	wall = Color3.fromRGB(118, 118, 122),
	wallDark = Color3.fromRGB(88, 88, 94),
	ceiling = Color3.fromRGB(80, 80, 86),
	concrete = Color3.fromRGB(135, 135, 140),
	beam = Color3.fromRGB(70, 70, 76),
	yellow = Color3.fromRGB(240, 190, 20),
	black = Color3.fromRGB(25, 25, 28),
	pink = Color3.fromRGB(255, 60, 160),
	cyan = Color3.fromRGB(0, 220, 255),
	line = Color3.fromRGB(205, 205, 195),
}

print("[LOBBY][BOOT] Construyendo garage subterráneo...")

-- ---------------------------------------------------------------------------
-- LIMPIEZA
-- ---------------------------------------------------------------------------
local previous = Workspace:FindFirstChild(MODEL_NAME)
if previous then
	previous:Destroy()
end
if REMOVE_OLD_GARAGE then
	local oldGarage = Workspace:FindFirstChild("BlockKartsGarage")
	if oldGarage then
		oldGarage:Destroy()
	end
end

local model = Instance.new("Model")
model.Name = MODEL_NAME

local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = model
	return f
end

local structure = folder("Structure")
local pillars = folder("Pillars")
local lights = folder("Lights")
local bays = folder("ParkingBays")
local props = folder("Props")
local zoneFolder = folder("MatchmakingZone")
local boardsFolder = folder("Leaderboards")

-- ---------------------------------------------------------------------------
-- AYUDAS
-- ---------------------------------------------------------------------------
local function toWorld(pos)
	if typeof(pos) == "CFrame" then
		return CFrame.new(ORIGIN) * pos
	end
	return CFrame.new(ORIGIN + pos)
end

-- Crea una pieza sólida. pos puede ser Vector3 o CFrame (relativo al centro del piso).
local function P(parent, name, size, pos, color, material, extra)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = toWorld(pos)
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if extra then
		for k, v in pairs(extra) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

-- Texto en una cara de una pieza (SurfaceGui)
local function sign(part, face, text, color, strokeColor, pos, size)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part

	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size or UDim2.fromScale(1, 1)
	l.Position = pos or UDim2.fromScale(0, 0)
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = color
	l.Parent = gui

	if strokeColor then
		local s = Instance.new("UIStroke")
		s.Color = strokeColor
		s.Thickness = 3
		s.Parent = l
	end
	return gui
end

local CYL = { Shape = Enum.PartType.Cylinder }
local rotX90 = CFrame.Angles(0, math.rad(90), 0) -- eje del cilindro: de X a Z
local flat = CFrame.Angles(0, 0, math.rad(90))   -- cilindro acostado -> disco plano

-- ---------------------------------------------------------------------------
-- 1) CASCARÓN: piso, techo, paredes
-- ---------------------------------------------------------------------------
P(structure, "Floor", Vector3.new(W + 4, 2, D + 4), Vector3.new(0, -1, 0), C.floor, Enum.Material.Asphalt)
P(structure, "Ceiling", Vector3.new(W + 4, 2, D + 4), Vector3.new(0, H + 1, 0), C.ceiling)

P(structure, "WallWest", Vector3.new(2, H, D + 4), Vector3.new(-(W / 2 + 1), H / 2, 0), C.wall)
P(structure, "WallEast", Vector3.new(2, H, D + 4), Vector3.new(W / 2 + 1, H / 2, 0), C.wall)
P(structure, "WallNorth", Vector3.new(W, H, 2), Vector3.new(0, H / 2, -(D / 2 + 1)), C.wall)
P(structure, "WallSouth", Vector3.new(W, H, 2), Vector3.new(0, H / 2, D / 2 + 1), C.wall)

-- Zócalo sucio y franja amarilla en las 4 paredes
P(structure, "BaseWest", Vector3.new(0.3, 3, D), Vector3.new(-W / 2 + 0.15, 1.5, 0), C.wallDark)
P(structure, "BaseEast", Vector3.new(0.3, 3, D), Vector3.new(W / 2 - 0.15, 1.5, 0), C.wallDark)
P(structure, "BaseNorth", Vector3.new(W, 3, 0.3), Vector3.new(0, 1.5, -D / 2 + 0.15), C.wallDark)
P(structure, "BaseSouth", Vector3.new(W, 3, 0.3), Vector3.new(0, 1.5, D / 2 - 0.15), C.wallDark)

P(structure, "StripeWest", Vector3.new(0.35, 0.6, D), Vector3.new(-W / 2 + 0.17, 4, 0), C.yellow, Enum.Material.SmoothPlastic)
P(structure, "StripeEast", Vector3.new(0.35, 0.6, D), Vector3.new(W / 2 - 0.17, 4, 0), C.yellow, Enum.Material.SmoothPlastic)
P(structure, "StripeNorth", Vector3.new(W, 0.6, 0.35), Vector3.new(0, 4, -D / 2 + 0.17), C.yellow, Enum.Material.SmoothPlastic)
P(structure, "StripeSouth", Vector3.new(W, 0.6, 0.35), Vector3.new(0, 4, D / 2 - 0.17), C.yellow, Enum.Material.SmoothPlastic)

-- ---------------------------------------------------------------------------
-- 2) TECHO: vigas, tuberías, ductos
-- ---------------------------------------------------------------------------
for z = -70, 70, 20 do
	P(structure, "Beam", Vector3.new(W, 1.6, 2), Vector3.new(0, H - 0.8, z), C.beam)
end

for _, x in ipairs({ -27, 27 }) do
	P(structure, "Pipe", Vector3.new(D, 1.2, 1.2), CFrame.new(x, H - 3, 0) * rotX90,
		Color3.fromRGB(70, 75, 80), Enum.Material.Metal, CYL)
end
for _, x in ipairs({ -36, 36 }) do
	P(structure, "Duct", Vector3.new(3, 2, D - 4), Vector3.new(x, H - 3.2, 0),
		Color3.fromRGB(140, 145, 150), Enum.Material.Metal)
end

-- ---------------------------------------------------------------------------
-- 3) LUCES FLUORESCENTES (algunas muertas, algunas parpadean)
-- ---------------------------------------------------------------------------
local flickers = {}
local idx = 0
for _, z in ipairs({ -60, -40, -20, 0, 20, 40, 60 }) do
	for _, x in ipairs({ -40, -20, 0, 20, 40 }) do
		idx += 1
		local dead = (idx % 11 == 0)
		local flicker = (not dead) and (idx % 7 == 0)
		local f = P(lights, "Fixture_" .. idx, Vector3.new(8, 0.3, 1.2), Vector3.new(x, H - 1.7, z),
			dead and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(255, 244, 214),
			dead and Enum.Material.SmoothPlastic or Enum.Material.Neon)
		if (not dead) and (idx % 2 == 1 or flicker) then
			local l = Instance.new("PointLight")
			l.Brightness = 0.9
			l.Range = 30
			l.Color = Color3.fromRGB(255, 236, 200)
			l.Shadows = false
			l.Parent = f
			if flicker then
				table.insert(flickers, { part = f, light = l })
			end
		end
	end
end

task.spawn(function()
	while model.Parent do
		for _, f in ipairs(flickers) do
			if math.random() < 0.15 then
				local isOn = f.part.Material == Enum.Material.Neon
				f.part.Material = isOn and Enum.Material.SmoothPlastic or Enum.Material.Neon
				f.light.Enabled = not isOn
			end
		end
		task.wait(0.12)
	end
end)

-- ---------------------------------------------------------------------------
-- 4) PILARES con bandas amarillo/negro y numeración
-- ---------------------------------------------------------------------------
local pillarNumber = 0
for _, x in ipairs({ -45, -15, 15, 45 }) do
	for _, z in ipairs({ -50, -20, 10, 40, 70 }) do
		-- No poner pilares dentro de la zona de matchmaking
		local insideZone = math.abs(x) <= 15 and z >= -35 and z <= 5
		if not insideZone then
			pillarNumber += 1
			local p = P(pillars, "Pillar_" .. pillarNumber, Vector3.new(4, H, 4), Vector3.new(x, H / 2, z), C.concrete)
			-- Bandas de advertencia en la base
			for i = 0, 3 do
				P(pillars, "PillarBand", Vector3.new(4.2, 0.8, 4.2), Vector3.new(x, 0.4 + i * 0.8, z),
					(i % 2 == 0) and C.yellow or C.black, Enum.Material.SmoothPlastic)
			end
			-- Capitel oscuro arriba
			P(pillars, "PillarCap", Vector3.new(5, 1, 5), Vector3.new(x, H - 0.5, z), C.wallDark)
			-- Número del pilar en las 4 caras
			local label = string.format("P-%02d", pillarNumber)
			for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
				sign(p, face, label, C.yellow, nil, UDim2.fromScale(0, 0.55), UDim2.fromScale(1, 0.1))
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- 5) PLAZAS DE PARQUEO + AUTOS ABANDONADOS
-- ---------------------------------------------------------------------------
local carColors = {
	Color3.fromRGB(120, 45, 45), Color3.fromRGB(45, 75, 115), Color3.fromRGB(95, 95, 65),
	Color3.fromRGB(150, 150, 150), Color3.fromRGB(60, 95, 70), Color3.fromRGB(110, 80, 45),
}

local function parkedCar(cf, color)
	P(bays, "CarBody", Vector3.new(9, 1.6, 4.4), cf * CFrame.new(0, 1.6, 0), color, Enum.Material.Metal)
	P(bays, "CarCabin", Vector3.new(4.6, 1.4, 3.9), cf * CFrame.new(-0.4, 3.1, 0),
		color:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Metal)
	P(bays, "CarGlass", Vector3.new(4.7, 0.9, 4.0), cf * CFrame.new(-0.4, 3.15, 0),
		Color3.fromRGB(25, 35, 45), Enum.Material.SmoothPlastic)
	for _, sx in ipairs({ -3, 3 }) do
		for _, sz in ipairs({ -2.2, 2.2 }) do
			P(bays, "CarWheel", Vector3.new(0.9, 2.1, 2.1), cf * CFrame.new(sx, 1.05, sz) * rotX90,
				C.black, Enum.Material.SmoothPlastic, CYL)
		end
	end
end

for _, side in ipairs({ -1, 1 }) do
	-- Líneas blancas de cada plaza
	for z = -70, 70, 10 do
		P(bays, "BayLine", Vector3.new(18, 0.05, 0.4), Vector3.new(side * 49, 0.03, z), C.line, Enum.Material.SmoothPlastic)
	end
	-- Topes y autos en el centro de cada plaza
	for k = 0, 13 do
		local z = -65 + k * 10
		P(bays, "WheelStop", Vector3.new(0.6, 0.4, 6), Vector3.new(side * 56.5, 0.2, z), Color3.fromRGB(160, 160, 160))
		if rng:NextNumber() < 0.45 then
			local flip = (rng:NextInteger(0, 1) == 1) and CFrame.Angles(0, math.pi, 0) or CFrame.new()
			local cf = CFrame.new(side * 49, 0, z)
				* CFrame.Angles(0, math.rad(rng:NextNumber(-3, 3)), 0) * flip
			parkedCar(cf, carColors[rng:NextInteger(1, #carColors)])
		end
	end
end

-- ---------------------------------------------------------------------------
-- 6) SUCIEDAD: manchas de aceite y charcos
-- ---------------------------------------------------------------------------
for i = 1, 14 do
	local x = rng:NextNumber(-34, 34)
	local z = rng:NextNumber(-70, 70)
	local nearZone = math.abs(x) < 20 and z > -36 and z < 6
	if not nearZone then
		local d = rng:NextNumber(3, 8)
		local puddle = (i % 4 == 0)
		P(props, puddle and "Puddle" or "OilStain", Vector3.new(0.06, d, d),
			CFrame.new(x, 0.04, z) * flat,
			puddle and Color3.fromRGB(40, 55, 70) or Color3.fromRGB(28, 28, 30),
			Enum.Material.SmoothPlastic,
			{ Shape = Enum.PartType.Cylinder, Reflectance = puddle and 0.35 or 0.1 })
	end
end

-- ---------------------------------------------------------------------------
-- 7) PROPS: barriles y cajas en las esquinas
-- ---------------------------------------------------------------------------
local function barrel(x, z)
	P(props, "Barrel", Vector3.new(3, 2, 2), CFrame.new(x, 1.5, z) * flat,
		Color3.fromRGB(150, 70, 30), Enum.Material.CorrodedMetal, CYL)
end
local function crate(x, y, z)
	P(props, "Crate", Vector3.new(3, 3, 3), Vector3.new(x, y, z), Color3.fromRGB(130, 95, 55), Enum.Material.Wood)
end
for _, cx in ipairs({ -55, 55 }) do
	for _, cz in ipairs({ -76, 76 }) do
		barrel(cx, cz)
		barrel(cx - 2.4, cz + (cz > 0 and -0.8 or 0.8))
		crate(cx + (cx > 0 and -3 or 3), 1.5, cz)
		crate(cx + (cx > 0 and -3 or 3), 4.5, cz)
	end
end

-- ---------------------------------------------------------------------------
-- 8) PORTÓN DE SALIDA CERRADO (pared sur)
-- ---------------------------------------------------------------------------
P(structure, "ShutterFrame", Vector3.new(26, 16, 0.4), Vector3.new(0, 8, D / 2 - 0.2), C.black, Enum.Material.Metal)
P(structure, "ShutterDoor", Vector3.new(22, 14, 0.4), Vector3.new(0, 7.2, D / 2 - 0.5),
	Color3.fromRGB(105, 110, 115), Enum.Material.CorrodedMetal)
for i = 1, 13 do
	P(structure, "ShutterSlat", Vector3.new(22, 0.2, 0.3), Vector3.new(0, i * 1.05, D / 2 - 0.75),
		Color3.fromRGB(80, 85, 90), Enum.Material.Metal)
end
local exitSign = P(structure, "ExitSign", Vector3.new(10, 1.8, 0.4), Vector3.new(0, 17, D / 2 - 0.4),
	Color3.fromRGB(180, 20, 20), Enum.Material.Neon)
sign(exitSign, Enum.NormalId.Front, "SALIDA CERRADA", Color3.fromRGB(255, 255, 255))

-- ---------------------------------------------------------------------------
-- 9) MATCHMAKING: CUATRO PLATAFORMAS ALINEADAS JUNTO A LA PARED ESTE
--    Se elimina por completo el anillo/plataforma central anterior.
-- ---------------------------------------------------------------------------
local PAD_X = W / 2 - 18
local PAD_Z = { -48, -16, 16, 48 }
local PAD_LABELS = { "SOLO vs CPU", "2 JUGADORES", "3 JUGADORES", "4 JUGADORES" }
local PAD_COLORS = { C.cyan, C.pink, C.yellow, Color3.fromRGB(90, 230, 120) }

-- Panel vertical de orientación en la pared; su cara interior mira hacia -X.
local wallPanel = P(zoneFolder, "MatchmakingWallPanel", Vector3.new(0.6, 13, 78),
	Vector3.new(W / 2 - 0.7, 10, 0), Color3.fromRGB(14, 14, 22), Enum.Material.Metal)
sign(wallPanel, Enum.NormalId.Left, "ELIGE TU CARRERA", C.cyan, C.pink)

for i = 1, 4 do
	local z = PAD_Z[i]
	local accent = PAD_COLORS[i]
	local pad = P(zoneFolder, "MatchmakingPad_" .. i, Vector3.new(13, 0.45, 13),
		Vector3.new(PAD_X, 0.25, z), Color3.fromRGB(27, 29, 38), Enum.Material.Metal)
	pad:SetAttribute("MatchmakingMode", ({ "cpu", "p2", "p3", "p4" })[i])

	-- Borde luminoso alrededor de cada plataforma.
	P(zoneFolder, "PadEdge_" .. i .. "_A", Vector3.new(13.2, 0.16, 0.35),
		Vector3.new(PAD_X, 0.55, z - 6.4), accent, Enum.Material.Neon)
	P(zoneFolder, "PadEdge_" .. i .. "_B", Vector3.new(13.2, 0.16, 0.35),
		Vector3.new(PAD_X, 0.55, z + 6.4), accent, Enum.Material.Neon)
	P(zoneFolder, "PadEdge_" .. i .. "_C", Vector3.new(0.35, 0.16, 13.2),
		Vector3.new(PAD_X - 6.4, 0.55, z), accent, Enum.Material.Neon)
	P(zoneFolder, "PadEdge_" .. i .. "_D", Vector3.new(0.35, 0.16, 13.2),
		Vector3.new(PAD_X + 6.4, 0.55, z), accent, Enum.Material.Neon)

	local labelPart = P(zoneFolder, "PadLabel_" .. i, Vector3.new(10, 0.06, 3),
		Vector3.new(PAD_X, 0.57, z), Color3.fromRGB(18, 18, 24), Enum.Material.SmoothPlastic,
		{ CanCollide = false })
	sign(labelPart, Enum.NormalId.Top, PAD_LABELS[i], accent, nil)

	local number = P(zoneFolder, "PadNumber_" .. i, Vector3.new(2.2, 0.08, 2.2),
		Vector3.new(PAD_X, 0.58, z - 4.1), accent, Enum.Material.Neon,
		{ CanCollide = false })
	sign(number, Enum.NormalId.Top, string.format("%02d", i), Color3.fromRGB(15, 15, 20))
end

-- Una única zona invisible cubre las cuatro plataformas para conservar
-- el popup actual y la lógica de cola sin modificar el cliente ni KartService.
local zone = P(zoneFolder, "MatchmakingZone", Vector3.new(24, 14, 72),
	Vector3.new(PAD_X, 7, 0), C.cyan, Enum.Material.SmoothPlastic,
	{ Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false })
CollectionService:AddTag(zone, "MatchmakingZone")

-- ---------------------------------------------------------------------------
-- 10) PARED NORTE: TABLEROS DE LÍDERES
-- ---------------------------------------------------------------------------
local BOARD_SIZE = Vector3.new(36, 16, 0.6)
local BOARD_Y = 10
local BOARD_Z = -D / 2 + 0.5

local function buildBoard(name, x, kind, title, accent)
	P(boardsFolder, name .. "Frame", Vector3.new(37, 17, 0.4), Vector3.new(x, BOARD_Y, BOARD_Z - 0.1),
		Color3.fromRGB(20, 20, 26), Enum.Material.Metal)
	local board = P(boardsFolder, name, BOARD_SIZE, Vector3.new(x, BOARD_Y, BOARD_Z + 0.2),
		Color3.fromRGB(12, 12, 18), Enum.Material.SmoothPlastic)
	-- Marco neón
	P(boardsFolder, name .. "TrimTop", Vector3.new(37.4, 0.4, 0.5), Vector3.new(x, BOARD_Y + 8.7, BOARD_Z + 0.2), accent, Enum.Material.Neon)
	P(boardsFolder, name .. "TrimBottom", Vector3.new(37.4, 0.4, 0.5), Vector3.new(x, BOARD_Y - 8.7, BOARD_Z + 0.2), accent, Enum.Material.Neon)
	P(boardsFolder, name .. "TrimLeft", Vector3.new(0.4, 17.4, 0.5), Vector3.new(x - 18.7, BOARD_Y, BOARD_Z + 0.2), accent, Enum.Material.Neon)
	P(boardsFolder, name .. "TrimRight", Vector3.new(0.4, 17.4, 0.5), Vector3.new(x + 18.7, BOARD_Y, BOARD_Z + 0.2), accent, Enum.Material.Neon)
	local glow = Instance.new("PointLight")
	glow.Color = accent
	glow.Brightness = 1.2
	glow.Range = 28
	glow.Shadows = false
	glow.Parent = boardsFolder:FindFirstChild(name .. "TrimBottom")
	-- La cara visible mira hacia +Z (hacia el interior del garage) = NormalId.Back
	Leaderboards.attachBoard(board, Enum.NormalId.Back, kind, title, accent)
end

buildBoard("BoardBestLap", -21, "lap", "MEJOR VUELTA", C.cyan)
buildBoard("BoardWins", 21, "wins", "CARRERAS GANADAS", C.pink)

local hall = P(boardsFolder, "HallOfFame", Vector3.new(5, 5, 0.4), Vector3.new(0, BOARD_Y, BOARD_Z + 0.1),
	Color3.fromRGB(14, 14, 22), Enum.Material.Metal)
sign(hall, Enum.NormalId.Back, "TOP\nPILOTOS", Color3.fromRGB(255, 205, 50), nil)

Leaderboards.start()

-- ---------------------------------------------------------------------------
-- 11) SPAWN
-- ---------------------------------------------------------------------------
local spawn = Instance.new("SpawnLocation")
spawn.Name = "LobbySpawn"
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Size = Vector3.new(10, 0.2, 10)
spawn.CFrame = toWorld(Vector3.new(0, 0.1, 62)) -- mira hacia el norte (-Z)
spawn.Transparency = 1
spawn.CanCollide = true
spawn.Parent = model

model.Parent = Workspace

-- Los jugadores reaparecen siempre en el lobby
local function assignSpawn(player)
	player.RespawnLocation = spawn
	if player.Character then
		player.Character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	end
end
for _, plr in ipairs(Players:GetPlayers()) do
	assignSpawn(plr)
end
Players.PlayerAdded:Connect(assignSpawn)

print(string.format("[LOBBY][BUILD] Garage subterráneo listo en %s (%dx%dx%d). Pilares: %d. Zona matchmaking activa.",
	tostring(ORIGIN), W, D, H, pillarNumber))
