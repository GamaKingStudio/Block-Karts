--[[
	LobbyMatchmaking (Script de servidor)
	Ruta Rojo:  src/ServerScriptService/LobbyMatchmaking.server.lua

	Maneja las colas de la zona de matchmaking:
	  cpu = 1 jugador + 1 CPU  (empieza tras la cuenta regresiva)
	  p2  = espera 2 jugadores humanos
	  p3  = espera 3 jugadores humanos
	  p4  = espera 4 jugadores humanos
	Nunca se agregan CPU a las salas de 2, 3 o 4.

	Flujo:
	  1. El jugador entra a la zona (tag "MatchmakingZone") -> el cliente abre el popup.
	  2. Elige un modo -> el servidor lo mete en la cola.
	  3. Cuando la cola está completa -> cuenta regresiva de 5 a 1.
	  4. Si alguien sale de la zona o cancela, la cuenta se detiene y la sala sigue esperando.
	  5. Al llegar a 0 -> se dispara el BindableEvent  ServerStorage.LobbyStartRace

	CÓMO CONECTAR CON TU CARRERA (KartService):
		local startRace = game:GetService("ServerStorage"):WaitForChild("LobbyStartRace")
		startRace.Event:Connect(function(info)
			-- info.players : tabla de jugadores humanos
			-- info.cpus    : cuántas CPU crear (1 en modo solo, 0 en los demás)
			-- info.humans  : cuántos humanos hay
			-- info.mode    : "cpu" | "p2" | "p3" | "p4"
			-- info.course  : "Beach" | "Forest"
			-- ... aquí tu código que lleva a los jugadores a la pista y empieza la carrera
		end)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local COUNTDOWN = 5

local MODES = {
	cpu = { humans = 1, cpus = 1, label = "SOLO vs CPU" },
	p2 = { humans = 2, cpus = 0, label = "2 JUGADORES" },
	p3 = { humans = 3, cpus = 0, label = "3 JUGADORES" },
	p4 = { humans = 4, cpus = 0, label = "4 JUGADORES" },
}

-- ---------------------------------------------------------------------------
-- Remotes y evento de inicio
-- ---------------------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("LobbyRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "LobbyRemotes"
	remotes.Parent = ReplicatedStorage
end

local function getRemote(name)
	local r = remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
	return r
end

local JoinQueue = getRemote("JoinQueue")     -- cliente -> servidor: modo elegido
local LeaveQueue = getRemote("LeaveQueue")   -- cliente -> servidor: cancelar
local QueueState = getRemote("QueueState")   -- servidor -> cliente: estado de la sala

local startEvent = ServerStorage:FindFirstChild("LobbyStartRace")
if not startEvent then
	startEvent = Instance.new("BindableEvent")
	startEvent.Name = "LobbyStartRace"
	startEvent.Parent = ServerStorage
end

-- ---------------------------------------------------------------------------
-- Estado de las colas
-- ---------------------------------------------------------------------------
local queues = {}
for modeId in pairs(MODES) do
	queues[modeId] = { players = {}, state = "idle", seconds = 0, token = 0, course = nil }
end
local lastJoin = {}

local function inZone(player)
	local zone = CollectionService:GetTagged("MatchmakingZone")[1]
	if not zone then
		return false
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	local rel = zone.CFrame:PointToObjectSpace(hrp.Position)
	local half = zone.Size / 2 + Vector3.new(3, 3, 3) -- margen por latencia
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

local function broadcast(modeId)
	local q, mode = queues[modeId], MODES[modeId]
	for _, plr in ipairs(q.players) do
		QueueState:FireClient(plr, {
			state = q.state,
			mode = modeId,
			label = mode.label,
			current = #q.players,
			target = mode.humans,
			seconds = q.seconds,
			course = q.course,
		})
	end
end

local function removeFromQueues(player)
	for modeId, q in pairs(queues) do
		local i = table.find(q.players, player)
		if i then
			table.remove(q.players, i)
			local mode = MODES[modeId]
			if #q.players == 0 then
				q.token += 1
				q.state = "idle"
				q.seconds = 0
				q.course = nil
			elseif q.state == "countdown" and #q.players < mode.humans then
				-- Se fue alguien: se cancela la cuenta y la sala sigue esperando
				q.token += 1
				q.state = "waiting"
				q.seconds = 0
			end
			print(string.format("[LOBBY][QUEUE] %s salió de %s (%d/%d)", player.Name, modeId, #q.players, mode.humans))
			broadcast(modeId)
		end
	end
end

local function launch(modeId, group, courseId)
	local mode = MODES[modeId]
	local alive = {}
	for _, plr in ipairs(group) do
		if plr.Parent == Players then
			table.insert(alive, plr)
		end
	end
	if #alive == 0 then
		return
	end
	for _, plr in ipairs(alive) do
		QueueState:FireClient(plr, { state = "starting", mode = modeId, label = mode.label, course = courseId })
	end
	print(string.format("[LOBBY][START] modo=%s pista=%s humanos=%d cpus=%d", modeId, courseId, #alive, mode.cpus))
	startEvent:Fire({
		mode = modeId,
		players = alive,
		humans = #alive,
		cpus = mode.cpus,
		course = courseId,
	})
end

local function runCountdown(modeId)
	local q, mode = queues[modeId], MODES[modeId]
	local courseId = q.course or "Beach"
	q.token += 1
	local myToken = q.token
	q.state = "countdown"
	print(string.format("[LOBBY][COUNTDOWN] inicio en %s (%d/%d)", modeId, #q.players, mode.humans))

	for s = COUNTDOWN, 1, -1 do
		if q.token ~= myToken then
			print("[LOBBY][COUNTDOWN] cancelado en " .. modeId)
			return
		end
		q.seconds = s
		broadcast(modeId)
		task.wait(1)
	end
	if q.token ~= myToken then
		print("[LOBBY][COUNTDOWN] cancelado en " .. modeId)
		return
	end

	local group = {}
	for i = 1, math.min(mode.humans, #q.players) do
		group[i] = q.players[i]
	end
	q.players = {}
	q.state = "idle"
	q.seconds = 0
	q.course = nil
	launch(modeId, group, courseId)
end

-- ---------------------------------------------------------------------------
-- Eventos del cliente
-- ---------------------------------------------------------------------------
JoinQueue.OnServerEvent:Connect(function(player, modeId, requestedCourse)
	if type(modeId) ~= "string" then
		return
	end
	local mode = MODES[modeId]
	local courseId = requestedCourse == "Forest" and "Forest" or (requestedCourse == "Beach" and "Beach" or nil)
	if not mode or not courseId then
		return
	end

	local now = os.clock()
	if (lastJoin[player] or 0) + 0.4 > now then
		return
	end
	lastJoin[player] = now

	if not inZone(player) then
		QueueState:FireClient(player, { state = "idle" })
		return
	end

	for otherMode, otherQueue in pairs(queues) do
		if otherMode ~= modeId and #otherQueue.players > 0 then
			QueueState:FireClient(player, {
				state = "rejected",
					message = "Ya hay otra sala en preparación. Espera a que termine.",
			})
			return
		end
	end

	local q = queues[modeId]
	if #q.players > 0 and q.course ~= courseId then
		QueueState:FireClient(player, {
			state = "rejected",
			message = "Esa sala ya eligió otra pista. Intenta cuando quede libre.",
		})
		return
	end
	if table.find(q.players, player) then
		return
	end
	if #q.players >= mode.humans then
		QueueState:FireClient(player, {
			state = "rejected",
			message = "Esa sala está llena. Intenta en unos segundos.",
		})
		return
	end

	removeFromQueues(player) -- sale de cualquier otra cola
	table.insert(q.players, player)
	q.course = courseId
	if q.state == "idle" then
		q.state = "waiting"
	end
	print(string.format("[LOBBY][QUEUE] %s entró a %s (%d/%d)", player.Name, modeId, #q.players, mode.humans))
	broadcast(modeId)

	if #q.players >= mode.humans and q.state ~= "countdown" then
		task.spawn(runCountdown, modeId)
	end
end)

LeaveQueue.OnServerEvent:Connect(function(player)
	removeFromQueues(player)
	QueueState:FireClient(player, { state = "idle" })
end)

Players.PlayerRemoving:Connect(function(player)
	removeFromQueues(player)
	lastJoin[player] = nil
end)

-- Si un jugador sale de la zona (o muere/teletransporta), lo saca de la cola
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, q in pairs(queues) do
			for _, plr in ipairs(table.clone(q.players)) do
				if plr.Parent ~= Players or not inZone(plr) then
					removeFromQueues(plr)
					if plr.Parent == Players then
						QueueState:FireClient(plr, { state = "idle" })
					end
				end
			end
		end
	end
end)

print("[LOBBY][BOOT] Matchmaking listo (cpu, p2, p3, p4).")
