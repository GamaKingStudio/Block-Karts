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
local ORIGIN = Vector3.new(650, 1, 0) -- desplazado fuera del borde de IslandSand (termina en X=520)
local W, D, H = 180, 160, 20          -- garage ampliado: 180 studs de ancho, 160 de largo, 20 de alto
local REMOVE_OLD_GARAGE = true        -- borra Workspace.BlockKartsGarage si existe
local MODEL_NAME = "BlockKartsGarage"

local rng = Random.new(1337)          -- semilla fija: el garage siempre sale igual

local C = {
	floor = Color3.fromRGB(43, 46, 52),
	wall = Color3.fromRGB(65, 69, 76),
	wallDark = Color3.fromRGB(31, 34, 40),
	ceiling = Color3.fromRGB(37, 40, 46),
	concrete = Color3.fromRGB(48, 52, 59),
	beam = Color3.fromRGB(24, 28, 34),
	yellow = Color3.fromRGB(245, 185, 35),
	black = Color3.fromRGB(16, 19, 24),
	pink = Color3.fromRGB(255, 92, 120),
	cyan = Color3.fromRGB(40, 220, 255),
	line = Color3.fromRGB(150, 164, 178),
}

print("[LOBBY][BOOT] Construyendo BLOCK KARTS RACING HQ...")

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
for z = -50, 70, 20 do
	-- Se deja libre el tramo norte para que nada tape los tableros.
	P(structure, "Beam", Vector3.new(W, 1.6, 2), Vector3.new(0, H - 0.8, z), C.beam)
end

for _, x in ipairs({ -27, 27 }) do
	P(structure, "Pipe", Vector3.new(D, 1.2, 1.2), CFrame.new(x, H - 3, 0) * rotX90,
		Color3.fromRGB(70, 75, 80), Enum.Material.Metal, CYL)
end
for _, x in ipairs({ -65, 65 }) do
	P(structure, "Duct", Vector3.new(3, 2, D - 4), Vector3.new(x, H - 3.2, 0),
		Color3.fromRGB(140, 145, 150), Enum.Material.Metal)
end

-- ---------------------------------------------------------------------------
-- 3) ILUMINACIÓN DE RACING HQ: líneas limpias, luz blanca y acentos cyan
-- ---------------------------------------------------------------------------
local lightIndex = 0
for _, z in ipairs({ -60, -35, -10, 15, 40, 65 }) do
	for _, x in ipairs({ -58, -29, 0, 29, 58 }) do
		lightIndex += 1
		local fixture = P(lights, "CeilingLight_" .. lightIndex,
			Vector3.new(10, 0.28, 1.4), Vector3.new(x, H - 1.65, z),
			Color3.fromRGB(224, 239, 250), Enum.Material.Neon)
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(205, 230, 255)
		glow.Brightness = 1.15
		glow.Range = 34
		glow.Shadows = false
		glow.Parent = fixture
	end
end
for _, z in ipairs({ -42, 42 }) do
	local strip = P(lights, "CyanCeilingStrip", Vector3.new(150, 0.12, 0.35),
		Vector3.new(0, H - 1.3, z), C.cyan, Enum.Material.Neon)
	strip.CanCollide = false
end

-- ---------------------------------------------------------------------------
-- 4) PILARES con bandas amarillo/negro y numeración
-- ---------------------------------------------------------------------------
local pillarNumber = 0
for _, x in ipairs({ -W / 2 + 9, W / 2 - 9 }) do
	for _, z in ipairs({ -50, -20, 10, 40, 70 }) do
		-- Solo pilares perimetrales: el centro queda completamente despejado.
		pillarNumber += 1
		local p = P(pillars, "Pillar_" .. pillarNumber, Vector3.new(4, H, 4), Vector3.new(x, H / 2, z), C.concrete)
		for i = 0, 3 do
			P(pillars, "PillarBand", Vector3.new(4.2, 0.8, 4.2), Vector3.new(x, 0.4 + i * 0.8, z),
				(i % 2 == 0) and C.yellow or C.black, Enum.Material.SmoothPlastic)
		end
		P(pillars, "PillarCap", Vector3.new(5, 1, 5), Vector3.new(x, H - 0.5, z), C.wallDark)
		local label = string.format("P-%02d", pillarNumber)
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
			sign(p, face, label, C.yellow, nil, UDim2.fromScale(0, 0.55), UDim2.fromScale(1, 0.1))
		end
	end
end

-- ---------------------------------------------------------------------------
-- 5) GUÍAS DE CIRCULACIÓN: carriles perimetrales discretos
-- ---------------------------------------------------------------------------
for _, side in ipairs({ -1, 1 }) do
	local x = side * 72
	P(bays, "ServiceLaneLine", Vector3.new(0.22, 0.04, 132),
		Vector3.new(x, 0.025, 0), Color3.fromRGB(105, 119, 132), Enum.Material.SmoothPlastic)
	for _, z in ipairs({ -66, 66 }) do
		P(bays, "LaneEndMark", Vector3.new(8, 0.04, 0.22),
			Vector3.new(x, 0.03, z), C.yellow, Enum.Material.SmoothPlastic)
	end
end

-- ---------------------------------------------------------------------------
-- 6) PISO LIMPIO: sin manchas circulares ni charcos decorativos
-- ---------------------------------------------------------------------------

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
-- 9) RACING HQ: MATCHMAKING CENTRAL ENTRE LOS PILARES LATERALES
-- ---------------------------------------------------------------------------
local PAD_X = { -10, 10, -10, 10 }
local PAD_Z = { -17, -17, 1, 1 }
local PAD_LABELS = { "SOLO  /  CPU", "DUO  /  2 PILOTOS", "TRÍO  /  3 PILOTOS", "SQUAD  /  4 PILOTOS" }
local PAD_COLORS = { C.cyan, Color3.fromRGB(255, 166, 55), C.pink, Color3.fromRGB(105, 235, 145) }
local PAD_NAMES = { "RoomEntryPad_1vCPU", "MatchmakingPad_2", "MatchmakingPad_3", "MatchmakingPad_4" }

-- Isla central baja: organiza la zona sin crear pilares ni bloquear la vista.
P(zoneFolder, "RaceDeck", Vector3.new(39, 0.5, 43), Vector3.new(0, 0.05, -8),
	Color3.fromRGB(27, 31, 39), Enum.Material.Metal)
for _, x in ipairs({ -19.2, 19.2 }) do
	P(zoneFolder, "RaceDeckSideTrim", Vector3.new(0.22, 0.18, 43),
		Vector3.new(x, 0.38, -8), C.cyan, Enum.Material.Neon)
end
for _, z in ipairs({ -29.2, 13.2 }) do
	P(zoneFolder, "RaceDeckEndTrim", Vector3.new(39, 0.18, 0.22),
		Vector3.new(0, 0.38, z), C.cyan, Enum.Material.Neon)
end
local deckTitle = P(zoneFolder, "RaceDeckTitle", Vector3.new(24, 0.08, 2.8),
	Vector3.new(0, 0.42, -30.5), Color3.fromRGB(18, 22, 29), Enum.Material.SmoothPlastic,
	{ CanCollide = false })
sign(deckTitle, Enum.NormalId.Top, "SELECT  YOUR  RACE", C.cyan, nil)

for i = 1, 4 do
	local x, z, accent = PAD_X[i], PAD_Z[i], PAD_COLORS[i]
	local pad = P(zoneFolder, PAD_NAMES[i], Vector3.new(13.5, 0.48, 13.5),
		Vector3.new(x, 0.55, z), Color3.fromRGB(37, 42, 51), Enum.Material.Metal)
	pad:SetAttribute("MatchmakingMode", ({ "cpu", "p2", "p3", "p4" })[i])

	-- Contorno luminoso integrado al piso.
	for edge = 1, 4 do
		local size, offset
		if edge <= 2 then
			size = Vector3.new(13.7, 0.12, 0.22)
			offset = Vector3.new(0, 0.31, edge == 1 and -6.7 or 6.7)
		else
			size = Vector3.new(0.22, 0.12, 13.7)
			offset = Vector3.new(edge == 3 and -6.7 or 6.7, 0.31, 0)
		end
		P(zoneFolder, "Pad_" .. i .. "_Edge_" .. edge, size,
			Vector3.new(x, 0.55, z) + offset, accent, Enum.Material.Neon)
	end

	local floorLabel = P(zoneFolder, "PadFloorLabel_" .. i, Vector3.new(10.8, 0.07, 2.5),
		Vector3.new(x, 0.84, z + 3.8), Color3.fromRGB(18, 22, 29), Enum.Material.SmoothPlastic,
		{ CanCollide = false })
	sign(floorLabel, Enum.NormalId.Top, PAD_LABELS[i], accent, nil)

	local number = P(zoneFolder, "PadNumber_" .. i, Vector3.new(2.8, 0.08, 2.8),
		Vector3.new(x, 0.85, z - 3.6), accent, Enum.Material.Neon, { CanCollide = false })
	sign(number, Enum.NormalId.Top, string.format("%02d", i), Color3.fromRGB(14, 18, 24), nil)

	-- Marcador de cola que KartService actualiza en tiempo real.
	local queueGui = Instance.new("BillboardGui")
	queueGui.Name = "QueueStatus"
	queueGui.Size = UDim2.fromOffset(150, 42)
	queueGui.StudsOffset = Vector3.new(0, 3.2, 0)
	queueGui.AlwaysOnTop = true
	queueGui.LightInfluence = 0
	queueGui.Parent = pad
	local stencil = Instance.new("Frame")
	stencil.Name = "StencilPanel"
	stencil.Size = UDim2.fromScale(1, 1)
	stencil.BackgroundColor3 = Color3.fromRGB(12, 17, 24)
	stencil.BackgroundTransparency = 0.12
	stencil.BorderSizePixel = 0
	stencil.Parent = queueGui
	local count = Instance.new("TextLabel")
	count.Name = "QueueCount"
	count.Size = UDim2.fromScale(1, 1)
	count.BackgroundTransparency = 1
	count.Text = "0/" .. tostring(i)
	count.TextColor3 = accent
	count.TextScaled = true
	count.Font = Enum.Font.GothamBold
	count.Parent = stencil
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 1.5
	stroke.Parent = stencil
end

local zone = P(zoneFolder, "MatchmakingZone", Vector3.new(43, 14, 49),
	Vector3.new(0, 7, -8), C.cyan, Enum.Material.SmoothPlastic,
	{ Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false })
CollectionService:AddTag(zone, "MatchmakingZone")

-- ---------------------------------------------------------------------------
-- 9B) KART LAB Y KART SHOP: DOS ZONAS LATERALES DE EXHIBICIÓN
-- ---------------------------------------------------------------------------
local function wallPanel(parent, name, x, z, title, accent)
	local panel = P(parent, name, Vector3.new(0.5, 8, 22), Vector3.new(x, 5, z),
		Color3.fromRGB(18, 22, 29), Enum.Material.Metal)
	sign(panel, Enum.NormalId.Left, title, accent, nil)
	P(parent, name .. "_Header", Vector3.new(0.55, 0.3, 22),
		Vector3.new(x, 9.2, z), accent, Enum.Material.Neon)
end

-- KART LAB (izquierda): bancos de trabajo, armarios y plataformas de personalización.
wallPanel(props, "KartLabPanel", -77, -5, "KART  LAB", C.cyan)
for i, z in ipairs({ -28, -5, 18 }) do
	P(props, "LabWorkbench_" .. i, Vector3.new(17, 2, 5),
		Vector3.new(-56, 1.2, z), Color3.fromRGB(37, 43, 51), Enum.Material.Metal)
	P(props, "LabWorkbenchTop_" .. i, Vector3.new(17.2, 0.22, 5.2),
		Vector3.new(-56, 2.25, z), Color3.fromRGB(91, 105, 118), Enum.Material.DiamondPlate)
	P(props, "LabWorkbenchLight_" .. i, Vector3.new(13, 0.12, 0.25),
		Vector3.new(-56, 2.42, z - 2.35), C.cyan, Enum.Material.Neon)
	for tire = 1, 2 do
		local tirePart = P(props, "LabTire_" .. i .. "_" .. tire, Vector3.new(2.4, 1.1, 2.4),
			CFrame.new(-64 + tire * 2.4, 0.65, z + 4) * flat,
			Color3.fromRGB(20, 23, 28), Enum.Material.Rubber, CYL)
		tirePart.CanCollide = false
	end
end
P(props, "LabToolCabinet", Vector3.new(7, 7, 5), Vector3.new(-75, 3.5, 34),
	Color3.fromRGB(45, 55, 65), Enum.Material.Metal)
P(props, "LabCabinetStripe", Vector3.new(7.1, 0.45, 5.1), Vector3.new(-75, 4, 34),
	C.cyan, Enum.Material.Neon)

-- KART SHOP (derecha): pedestales limpios, sin autos decorativos falsos.
wallPanel(props, "KartShopPanel", 77, -5, "KART  SHOP", Color3.fromRGB(255, 166, 55))
for i, z in ipairs({ -28, -5, 18 }) do
	local accent = ({ C.cyan, Color3.fromRGB(255, 166, 55), C.pink })[i]
	P(props, "ShopDisplay_" .. i, Vector3.new(17, 0.8, 11),
		Vector3.new(56, 0.55, z), Color3.fromRGB(30, 35, 44), Enum.Material.Metal)
	P(props, "ShopDisplayTrim_" .. i, Vector3.new(16.5, 0.14, 0.25),
		Vector3.new(56, 1.02, z - 5.2), accent, Enum.Material.Neon)
	P(props, "ShopDisplayBack_" .. i, Vector3.new(0.35, 5, 11),
		Vector3.new(64.5, 3.2, z), Color3.fromRGB(48, 55, 65), Enum.Material.Metal)
end
P(props, "ShopCounter", Vector3.new(13, 2.4, 5), Vector3.new(55, 1.35, 37),
	Color3.fromRGB(31, 37, 46), Enum.Material.Metal)
P(props, "ShopCounterTop", Vector3.new(13.2, 0.18, 5.2), Vector3.new(55, 2.65, 37),
	Color3.fromRGB(255, 166, 55), Enum.Material.Neon)

-- ---------------------------------------------------------------------------
-- 10) PARED NORTE: HALL OF FAME Y TABLEROS DE LÍDERES
-- ---------------------------------------------------------------------------
local BOARD_SIZE = Vector3.new(36, 14, 0.6)
local BOARD_Y = 9
local BOARD_Z = -D / 2 + 0.5

local function buildBoard(name, x, kind, title, accent)
	P(boardsFolder, name .. "Frame", Vector3.new(37, 15, 0.4), Vector3.new(x, BOARD_Y, BOARD_Z - 0.1),
		Color3.fromRGB(20, 20, 26), Enum.Material.Metal)
	local board = P(boardsFolder, name, BOARD_SIZE, Vector3.new(x, BOARD_Y, BOARD_Z + 0.2),
		Color3.fromRGB(12, 12, 18), Enum.Material.SmoothPlastic)
	-- Marco neón
	P(boardsFolder, name .. "TrimTop", Vector3.new(37.4, 0.4, 0.5), Vector3.new(x, BOARD_Y + 7.7, BOARD_Z + 0.2), accent, Enum.Material.Neon)
	P(boardsFolder, name .. "TrimBottom", Vector3.new(37.4, 0.4, 0.5), Vector3.new(x, BOARD_Y - 7.7, BOARD_Z + 0.2), accent, Enum.Material.Neon)
	P(boardsFolder, name .. "TrimLeft", Vector3.new(0.4, 15.4, 0.5), Vector3.new(x - 18.7, BOARD_Y, BOARD_Z + 0.2), accent, Enum.Material.Neon)
	P(boardsFolder, name .. "TrimRight", Vector3.new(0.4, 15.4, 0.5), Vector3.new(x + 18.7, BOARD_Y, BOARD_Z + 0.2), accent, Enum.Material.Neon)
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

print(string.format("[LOBBY][BUILD] BLOCK KARTS RACING HQ listo en %s (%dx%dx%d). Matchmaking central 1-4, Kart Lab, Kart Shop y Hall of Fame.",
	tostring(ORIGIN), W, D, H))
