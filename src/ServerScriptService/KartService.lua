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
local matchmakingEntryCountdownRemote = getOrCreateRemote("MatchmakingEntryCountdown")

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
 local boundGarage = nil
 local boundPads = {}
 local lastPadByPlayer = {}
 local allPadsLogged = false

 -- El constructor puede reemplazar BlockKartsGarage después de iniciar este
 -- servicio. Buscamos el modelo y sus pads continuamente, no una sola vez.
 while true do
  local garage = Workspace:FindFirstChild("BlockKartsGarage")
  if garage ~= boundGarage then
   boundGarage = garage
   boundPads = {}
   lastPadByPlayer = {}
   allPadsLogged = false
   if garage then
    print("[MATCHMAKING] Detectado garage nuevo; conectando sus plataformas.")
   end
  end

  if garage then
   local connectedCount = 0
   local padNames = {"RoomEntryPad_1vCPU", "MatchmakingPad_2", "MatchmakingPad_3", "MatchmakingPad_4"}
   for index, padName in ipairs(padNames) do
    local pad = garage:FindFirstChild(padName)
    if pad and pad:IsA("BasePart") then
     connectedCount += 1
     if boundPads[index] ~= pad then
      boundPads[index] = pad
      pad.CanTouch = true
      pad.Touched:Connect(function(hit)
       local character = hit and hit:FindFirstAncestorOfClass("Model")
       local player = character and Players:GetPlayerFromCharacter(character)
       if not player then return end
       print(("[MATCHMAKING][TOUCH] %s tocó %s"):format(player.Name, pad.Name))
       beginMatchmakingEntry(player, pad,
        pad:GetAttribute("RequiredPlayers") or pad:GetAttribute("PadIndex") or index)
      end)
      print("[MATCHMAKING] Conectada plataforma " .. padName)
     end
    else
     boundPads[index] = nil
    end
   end

   if connectedCount == 4 and not allPadsLogged then
    allPadsLogged = true
    print("[MATCHMAKING] Las 4 plataformas del garage actual están conectadas.")
   end

   -- Detección por posición: no depende de que Touched se dispare.
   for _, player in ipairs(Players:GetPlayers()) do
    local standingPad, standingIndex = nil, nil
    for index = 1, 4 do
     local pad = boundPads[index]
     if pad and pad.Parent == garage and isPlayerStandingOnPad(player, pad) then
      standingPad, standingIndex = pad, index
      break
     end
    end

    if standingPad then
     if lastPadByPlayer[player] ~= standingPad then
      lastPadByPlayer[player] = standingPad
      print(("[MATCHMAKING][PROXIMITY] %s detectado sobre %s; InGarage=%s"):format(
       player.Name, standingPad.Name, tostring(player:GetAttribute("InGarage"))))
      beginMatchmakingEntry(player, standingPad,
       standingPad:GetAttribute("RequiredPlayers") or standingPad:GetAttribute("PadIndex") or standingIndex)
     end
    else
     lastPadByPlayer[player] = nil
    end
   end
  end

  task.wait(0.15)
 end
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
 cancelMatchmakingEntry(player)
 entryCountdowns[player] = nil
 local wasInRoom = roomPlayers[player] == true
 local kart = activeKarts[player]
 if kart then kart.model:Destroy() end
 activeKarts[player] = nil
 roomPlayers[player] = nil
 anotherRaceRequests[player] = nil
 anotherRaceRequests = {}
 selectedCameras[player] = nil
 driverInputs[player] = nil
 raceData[player] = nil
 finishCruiseStates[player] = nil

 if wasInRoom and not raceHasStarted then
  raceInProgress = false
  countdownToken += 1
 end

 local remaining = getRacePlayers()
 if #remaining == 0 then
  if cpuKart and cpuKart.model then cpuKart.model:Destroy() end
  cpuKart = nil
  cpuRace = nil
  roomTargetPlayers = 0
  raceInProgress = false
  raceHasStarted = false
  anotherRaceRequests = {}
  roomFinishTimes = {}
  countdownToken += 1
 elseif raceHasStarted then
  roomTargetPlayers = #remaining
 else
  for _, participant in ipairs(remaining) do
   participant:SetAttribute("RoomStatus", string.format("ESPERANDO PILOTOS %d/%d", #remaining, roomTargetPlayers))
  end
 end

 task.defer(function()
  publishSelectionState()
  if not raceHasStarted then tryStartRace() end
 end)
end)

return true