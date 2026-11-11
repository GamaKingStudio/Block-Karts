--[[
	Leaderboards (ModuleScript)
	Ruta Rojo:  src/ServerScriptService/Leaderboards.lua

	Guarda y muestra dos rankings en los tableros del lobby:
	  - "lap"  : MEJOR VUELTA (menor tiempo gana)
	  - "wins" : MÁS CARRERAS GANADAS

	USO DESDE KartService (o donde termines una vuelta / carrera):
		local Leaderboards = require(game.ServerScriptService.Leaderboards)
		Leaderboards.SubmitLap(player, 42.318)   -- tiempo de la vuelta en SEGUNDOS
		Leaderboards.AddWin(player)              -- suma 1 carrera ganada

	IMPORTANTE (para probar en Studio):
		Game Settings > Security > "Enable Studio Access to API Services".
		Si está apagado, el módulo usa una tabla en memoria (solo dura mientras
		el servidor está abierto) para que puedas ver que los tableros funcionan.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Leaderboards = {}

local LAP_STORE_NAME = "BloxyKartz_BestLapMs_v1"
local WINS_STORE_NAME = "BloxyKartz_RaceWins_v1"
local ROWS = 10
local REFRESH_SECONDS = 60

-- ---------------------------------------------------------------------------
-- DataStores
-- ---------------------------------------------------------------------------
local lapStore, winStore
do
	local ok, a, b = pcall(function()
		return DataStoreService:GetOrderedDataStore(LAP_STORE_NAME),
			DataStoreService:GetOrderedDataStore(WINS_STORE_NAME)
	end)
	if ok then
		lapStore, winStore = a, b
	else
		warn("[LEADERBOARDS] No se pudo abrir DataStore; se usará memoria local.")
	end
end

-- Respaldo en memoria (solo para pruebas)
local localLap = {}   -- [userId] = milisegundos
local localWins = {}  -- [userId] = victorias

local function userIdOf(playerOrId)
	if typeof(playerOrId) == "Instance" then
		return playerOrId.UserId
	end
	return tonumber(playerOrId)
end

-- ---------------------------------------------------------------------------
-- Guardar resultados
-- ---------------------------------------------------------------------------
function Leaderboards.SubmitLap(playerOrId, seconds)
	local uid = userIdOf(playerOrId)
	if not uid or type(seconds) ~= "number" or seconds < 1 or seconds > 3600 then return end
	local ms = math.floor(seconds * 1000 + 0.5)
	if localLap[uid] == nil or ms < localLap[uid] then localLap[uid] = ms end
	Leaderboards.RequestRefresh()
end

function Leaderboards.AddWin(playerOrId)
	local uid = userIdOf(playerOrId)
	if not uid then return end
	localWins[uid] = (localWins[uid] or 0) + 1
	Leaderboards.RequestRefresh()
end

-- ---------------------------------------------------------------------------
-- Leer rankings
-- ---------------------------------------------------------------------------
local function fetchTop(kind)
	local store = (kind == "lap") and lapStore or winStore
	local ascending = (kind == "lap") -- vuelta: menor tiempo primero

	if store then
		local ok, result = pcall(function()
			local pages = store:GetSortedAsync(ascending, ROWS)
			return pages:GetCurrentPage()
		end)
		if ok then
			local rows = {}
			for _, entry in ipairs(result) do
				table.insert(rows, { userId = tonumber(entry.key), value = entry.value })
			end
			return rows
		else
			warn("[LEADERBOARDS] No se pudo leer el ranking (" .. kind .. "): " .. tostring(result))
		end
	end

	-- Respaldo local
	local rows = {}
	local src = (kind == "lap") and localLap or localWins
	for uid, value in pairs(src) do
		table.insert(rows, { userId = uid, value = value })
	end
	table.sort(rows, function(a, b)
		if ascending then
			return a.value < b.value
		end
		return a.value > b.value
	end)
	while #rows > ROWS do
		table.remove(rows)
	end
	return rows
end

local nameCache = {}
local function nameOf(uid)
	if nameCache[uid] then
		return nameCache[uid]
	end
	local plr = Players:GetPlayerByUserId(uid)
	if plr then
		nameCache[uid] = plr.Name
		return plr.Name
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(uid)
	end)
	nameCache[uid] = ok and name or ("Jugador" .. tostring(uid))
	return nameCache[uid]
end

local function formatLap(ms)
	local s = ms / 1000
	local m = math.floor(s / 60)
	return string.format("%d:%06.3f", m, s - m * 60)
end

local function formatWins(n)
	return tostring(n)
end

-- ---------------------------------------------------------------------------
-- Tableros en pantalla (SurfaceGui)
-- ---------------------------------------------------------------------------
local boards = {}

local GOLD = Color3.fromRGB(255, 205, 50)
local SILVER = Color3.fromRGB(205, 210, 220)
local BRONZE = Color3.fromRGB(215, 135, 70)
local WHITE = Color3.fromRGB(235, 235, 240)

local function newLabel(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = WHITE
	for k, v in pairs(props) do
		l[k] = v
	end
	l.Parent = parent
	return l
end

--[[
	attachBoard(part, face, kind, title, accentColor)
	  part   : Part donde se dibuja el tablero
	  face   : Enum.NormalId de la cara visible (ej. Enum.NormalId.Back)
	  kind   : "lap" o "wins"
	  title  : texto del título
]]
function Leaderboards.attachBoard(part, face, kind, title, accent)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardDisplay"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = part

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
	bg.BorderSizePixel = 0
	bg.Parent = gui

	newLabel(bg, {
		Size = UDim2.fromScale(0.94, 0.12),
		Position = UDim2.fromScale(0.03, 0.015),
		Text = title,
		Font = Enum.Font.GothamBlack,
		TextColor3 = accent,
	})

	local ui = {}
	for i = 1, ROWS do
		local row = Instance.new("Frame")
		row.Size = UDim2.fromScale(0.94, 0.07)
		row.Position = UDim2.fromScale(0.03, 0.15 + (i - 1) * 0.0755)
		row.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(24, 24, 34) or Color3.fromRGB(18, 18, 26)
		row.BorderSizePixel = 0
		row.Parent = bg

		local rankColor = (i == 1 and GOLD) or (i == 2 and SILVER) or (i == 3 and BRONZE) or WHITE
		local rank = newLabel(row, {
			Size = UDim2.fromScale(0.1, 0.8),
			Position = UDim2.fromScale(0.02, 0.1),
			Text = tostring(i),
			TextColor3 = rankColor,
			Font = Enum.Font.GothamBlack,
		})
		local name = newLabel(row, {
			Size = UDim2.fromScale(0.55, 0.8),
			Position = UDim2.fromScale(0.14, 0.1),
			Text = "---",
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local value = newLabel(row, {
			Size = UDim2.fromScale(0.27, 0.8),
			Position = UDim2.fromScale(0.71, 0.1),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = accent,
		})
		ui[i] = { rank = rank, name = name, value = value }
	end

	newLabel(bg, {
		Size = UDim2.fromScale(0.94, 0.05),
		Position = UDim2.fromScale(0.03, 0.935),
		Text = "Se actualiza cada " .. REFRESH_SECONDS .. " segundos",
		TextColor3 = Color3.fromRGB(120, 120, 140),
		Font = Enum.Font.Gotham,
	})

	table.insert(boards, { kind = kind, ui = ui })
end

function Leaderboards.RefreshAll()
	local cache = {}
	for _, board in ipairs(boards) do
		local rows = cache[board.kind]
		if not rows then
			rows = fetchTop(board.kind)
			cache[board.kind] = rows
		end
		local fmt = (board.kind == "lap") and formatLap or formatWins
		for i = 1, ROWS do
			local entry = rows[i]
			local ui = board.ui[i]
			if entry then
				ui.name.Text = nameOf(entry.userId)
				ui.value.Text = fmt(entry.value)
			else
				ui.name.Text = "---"
				ui.value.Text = ""
			end
		end
	end
end

local pending = false
function Leaderboards.RequestRefresh()
	if pending then
		return
	end
	pending = true
	task.delay(3, function()
		pending = false
		Leaderboards.RefreshAll()
	end)
end

local started = false
function Leaderboards.start()
	if started then
		return
	end
	started = true
	task.spawn(function()
		while true do
			Leaderboards.RefreshAll()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return Leaderboards
