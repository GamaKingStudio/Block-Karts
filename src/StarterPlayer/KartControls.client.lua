local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
print(("[BLOXY-KART][CLIENT][LOCAL-SCRIPT-ENTER] script=%s parent=%s player=%s"):format(
	script:GetFullName(), script.Parent:GetFullName(), player.Name
))
local KartConfig = require(ReplicatedStorage:WaitForChild("KartConfig"))
local typography = require(ReplicatedStorage:WaitForChild("BloxyTypography"))
local raceEvents = ReplicatedStorage:WaitForChild("RaceEvents")
local checkpointPassedRemote = raceEvents:WaitForChild("CheckpointPassed")
local lapCompletedRemote = raceEvents:WaitForChild("LapCompleted")
local wrongWayRemote = raceEvents:WaitForChild("WrongWayStateChanged")
local requestRespawnRemote = raceEvents:WaitForChild("RequestRespawn")
local cameraSelectionRemote = raceEvents:WaitForChild("SelectRaceCamera")
local selectionStateRemote = raceEvents:WaitForChild("RaceSelectionState")
local raceCountdownRemote = raceEvents:WaitForChild("RaceCountdown")

checkpointPassedRemote.OnClientEvent:Connect(function(cpIndex, totalCps)
	print(("[BLOXY-KART][RACE] Checkpoint %d / %d"):format(cpIndex, totalCps))
end)
lapCompletedRemote.OnClientEvent:Connect(function(lap, lapTime, isBest)
	print(("[BLOXY-KART][RACE] Vuelta %d: %.2fs (mejor: %s)"):format(lap, lapTime, tostring(isBest)))
end)
wrongWayRemote.OnClientEvent:Connect(function(isWrongWay)
	if isWrongWay then warn("[BLOXY-KART][RACE] DIRECCIÓN CONTRARIA") end
end)
local function onRespawnAction(_, inputState)
	if inputState == Enum.UserInputState.Begin then requestRespawnRemote:FireServer() end
	return Enum.ContextActionResult.Sink
end

local controlRemote = ReplicatedStorage:WaitForChild("KartControl", 15)
if not controlRemote then
	warn("[BLOXY-KART][CLIENT][REMOTE-MISSING] KartControl no apareció en ReplicatedStorage tras 15 segundos.")
	return
end
if not controlRemote:IsA("RemoteEvent") then
	warn(("[BLOXY-KART][CLIENT][REMOTE-WRONG-CLASS] ReplicatedStorage.KartControl es %s, no RemoteEvent."):format(controlRemote.ClassName))
	return
end
print(("[BLOXY-KART][CLIENT][START] script=%s parent=%s remote=%s class=%s"):format(
	script:GetFullName(), script.Parent:GetFullName(), controlRemote:GetFullName(), controlRemote.ClassName
))
local camera = Workspace.CurrentCamera
local currentSeat
local cameraConnection
local drivingBaseFieldOfView
local shownEnterPrompt
local enterPromptBillboard
local held = { forward = false, reverse = false, left = false, right = false, brake = false }
local mobilePadVector = Vector2.zero
local mobilePadActive = false
local driftHeld = false
local isDrifting = false
local driftStartTime = 0
local miniTurboEndTime = 0
local driveActionName = "BLOXYKartDriveControls"
local driveKeys = {
	Enum.KeyCode.W, Enum.KeyCode.Up,
	Enum.KeyCode.S, Enum.KeyCode.Down,
	Enum.KeyCode.A, Enum.KeyCode.Left,
	Enum.KeyCode.D, Enum.KeyCode.Right,
	Enum.KeyCode.Space, Enum.KeyCode.R, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift,
}
local keyToControl = {
	[Enum.KeyCode.W] = "forward", [Enum.KeyCode.Up] = "forward",
	[Enum.KeyCode.S] = "reverse", [Enum.KeyCode.Down] = "reverse",
	[Enum.KeyCode.A] = "left", [Enum.KeyCode.Left] = "left",
	[Enum.KeyCode.D] = "right", [Enum.KeyCode.Right] = "right",
	[Enum.KeyCode.Space] = "brake",
}

local function getKartFromSeat(seat)
	local model = seat and seat:FindFirstAncestorOfClass("Model")
	if model and model:GetAttribute("OwnerUserId") == player.UserId then
		return model
	end
	return nil
end

local function hideEnterPrompt(prompt)
	if prompt and shownEnterPrompt ~= prompt then
		return
	end
	if enterPromptBillboard then
		enterPromptBillboard:Destroy()
		enterPromptBillboard = nil
	end
	shownEnterPrompt = nil
end

local function showEnterPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") or prompt.Name ~= "EnterKartPrompt" or currentSeat then
		return
	end
	local seat = prompt.Parent
	if not seat or not seat:IsA("VehicleSeat") or seat.Occupant or not getKartFromSeat(seat) then
		return
	end
	hideEnterPrompt()
	shownEnterPrompt = prompt

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BLOXYKartEnterHint"
	billboard.Adornee = seat
	billboard.Size = UDim2.fromOffset(132, 36)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = prompt.MaxActivationDistance
	local frame = Instance.new("Frame")
	frame.Name = "Pill"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(25, 29, 36)
	frame.BackgroundTransparency = 0.12
	frame.Parent = billboard
	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 8)
	frameCorner.Parent = frame
	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.fromRGB(255, 197, 72)
	frameStroke.Thickness = 1
	frameStroke.Transparency = 0.2
	frameStroke.Parent = frame

	local keyBadge = Instance.new("TextLabel")
	keyBadge.Name = "Key"
	keyBadge.Position = UDim2.fromOffset(5, 5)
	keyBadge.Size = UDim2.fromOffset(27, 26)
	keyBadge.BackgroundColor3 = Color3.fromRGB(255, 197, 72)
	keyBadge.Text = "E"
	keyBadge.TextColor3 = Color3.fromRGB(28, 30, 34)
	keyBadge.TextSize = 16
	keyBadge.FontFace = typography.getFont("Bold")
	keyBadge.Parent = frame
	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(0, 5)
	keyCorner.Parent = keyBadge

	local actionLabel = Instance.new("TextLabel")
	actionLabel.Name = "Action"
	actionLabel.Position = UDim2.fromOffset(40, 0)
	actionLabel.Size = UDim2.new(1, -44, 1, 0)
	actionLabel.BackgroundTransparency = 1
	actionLabel.Text = "Conducir"
	actionLabel.TextColor3 = Color3.fromRGB(245, 246, 248)
	actionLabel.TextSize = 14
	actionLabel.TextXAlignment = Enum.TextXAlignment.Left
	actionLabel.FontFace = typography.getFont("Light")
	actionLabel.Parent = frame

	billboard.Parent = player:WaitForChild("PlayerGui")
	enterPromptBillboard = billboard
end

ProximityPromptService.PromptShown:Connect(showEnterPrompt)
ProximityPromptService.PromptHidden:Connect(hideEnterPrompt)

local function stopDrivingCamera()
	local wasDrivingCamera = cameraConnection ~= nil or (camera and camera.CameraType == Enum.CameraType.Scriptable)
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	local activeCamera = Workspace.CurrentCamera
	if activeCamera then
		camera = activeCamera
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			activeCamera.CameraSubject = humanoid
		end
		activeCamera.CameraType = Enum.CameraType.Custom
		if drivingBaseFieldOfView then
			activeCamera.FieldOfView = drivingBaseFieldOfView
			drivingBaseFieldOfView = nil
		end
		if wasDrivingCamera then
			print(("[BLOXY-KART][CLIENT][CAMERA-RESTORE] type=%s subject=%s"):format(
				activeCamera.CameraType.Name, activeCamera.CameraSubject and activeCamera.CameraSubject:GetFullName() or "nil"
			))
		end
	end
end

local function startDrivingCamera(kart)
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end
	camera = Workspace.CurrentCamera
	if not camera then return end

	local mode = player:GetAttribute("RaceCamera") or "Classic"
	-- Keep the two camera styles distinct while framing the kart more prominently.
	local offset = mode == "Isometric" and KartConfig.CameraOffset or Vector3.new(0, 10, 20)
	local ahead = mode == "Isometric" and KartConfig.CameraLookAhead or 6

	camera.CameraType = Enum.CameraType.Scriptable
	drivingBaseFieldOfView = camera.FieldOfView
	local baseFov = camera.FieldOfView
	local smoothFov = baseFov
	local smoothCFrame = camera.CFrame

	cameraConnection = RunService.RenderStepped:Connect(function(dt)
		if not kart.Parent or not kart.PrimaryPart then
			stopDrivingCamera()
			return
		end

		local chassis = kart.PrimaryPart
		local focus = chassis.Position + chassis.CFrame.LookVector * ahead + Vector3.new(0, 1.5, 0)
		local desired = CFrame.lookAt((chassis.CFrame * CFrame.new(offset)).Position, focus)
		smoothCFrame = smoothCFrame:Lerp(desired, 1 - math.exp(-5 * dt))

		local speed = math.abs(chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector))
		local target = baseFov + 2.5 * math.clamp(speed / math.max(KartConfig.MaxForwardSpeed, 1), 0, 1)
		smoothFov += (target - smoothFov) * (1 - math.exp(-3.5 * dt))
		camera.FieldOfView = smoothFov
		camera.CFrame = smoothCFrame
		camera.Focus = CFrame.new(focus)
	end)
end
local selectionGui
local function showCameraSelection()
	local playerGui = player:WaitForChild("PlayerGui")
	-- Remove interfaces left behind by an earlier LocalScript run (for example after Rojo hot reload).
	for _, oldGui in ipairs(playerGui:GetChildren()) do
		if oldGui:IsA("ScreenGui") and oldGui.Name == "BLOXYCameraSelection" then
			oldGui:Destroy()
		end
	end
	if selectionGui then selectionGui:Destroy(); selectionGui = nil end
	local gui = Instance.new("ScreenGui")
	gui.Name = "BLOXYCameraSelection"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Parent = playerGui
	selectionGui = gui

	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(10, 15, 24)
	shade.BackgroundTransparency = 0.48
	shade.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.9, 0, 0, 300)
	panel.BackgroundColor3 = Color3.fromRGB(42, 55, 72)
	panel.Parent = shade
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(570, 300)
	limit.MinSize = Vector2.new(280, 260)
	limit.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = panel

	local heading = Instance.new("TextLabel")
	heading.Position = UDim2.fromOffset(16, 14)
	heading.Size = UDim2.new(1, -32, 0, 42)
	heading.BackgroundTransparency = 1
	heading.Text = "ELIGE TU CÁMARA"
	heading.TextColor3 = Color3.new(1, 1, 1)
	heading.FontFace = typography.getFont("Title")
	heading.TextSize = 27
	heading.Parent = panel

	local cards = Instance.new("Frame")
	cards.Position = UDim2.fromOffset(14, 68)
	cards.Size = UDim2.new(1, -28, 0, 150)
	cards.BackgroundTransparency = 1
	cards.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.Parent = cards

	local status = Instance.new("TextLabel")
	status.Name = "ReadyStatus"
	status.Position = UDim2.fromOffset(14, 236)
	status.Size = UDim2.new(1, -28, 0, 42)
	status.BackgroundTransparency = 1
	status.Text = "Selecciona una opción para continuar"
	status.TextColor3 = Color3.fromRGB(255, 205, 95)
	status.FontFace = typography.getFont("Bold")
	status.TextSize = 15
	status.TextWrapped = true
	status.Parent = panel

	local function addChoice(mode, title)
		local button = Instance.new("TextButton")
		button.Name = mode .. "Choice"
		button.Size = UDim2.new(0.5, -8, 1, 0)
		button.BackgroundColor3 = Color3.fromRGB(57, 75, 96)
		button.Text = ""
		button.AutoButtonColor = true
		button.Parent = cards
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0, 12)
		round.Parent = button
		local outline = Instance.new("UIStroke")
		outline.Color = Color3.fromRGB(105, 124, 148)
		outline.Thickness = 2
		outline.Parent = button

		local preview = Instance.new("ImageLabel")
		preview.Name = "CameraPreview"
		preview.Position = UDim2.fromOffset(10, 8)
		preview.Size = UDim2.new(1, -20, 0, 94)
		preview.BackgroundColor3 = Color3.fromRGB(35, 46, 60)
		preview.BackgroundTransparency = 0
		preview.BorderSizePixel = 0
		preview.Image = mode == "Classic"
			and "rbxassetid://107652293267576"
			or "rbxassetid://134848699353874"
		preview.ScaleType = Enum.ScaleType.Crop
		preview.Parent = button
		local previewCorner = Instance.new("UICorner")
		previewCorner.CornerRadius = UDim.new(0, 9)
		previewCorner.Parent = preview

		local name = Instance.new("TextLabel")
		name.Position = UDim2.fromOffset(6, 108)
		name.Size = UDim2.new(1, -12, 0, 28)
		name.BackgroundTransparency = 1
		name.Text = title
		name.TextColor3 = Color3.new(1, 1, 1)
		name.FontFace = typography.getFont("Bold")
		name.TextSize = 17
		name.Parent = button


		button.Activated:Connect(function()
			cameraSelectionRemote:FireServer(mode)
			status.Text = "Cámara seleccionada. Esperando a los demás..."
			for _, item in ipairs(cards:GetChildren()) do
				if item:IsA("TextButton") then
					local border = item:FindFirstChildOfClass("UIStroke")
					if border then
						border.Color = item == button and Color3.fromRGB(255, 197, 72) or Color3.fromRGB(105, 124, 148)
						border.Thickness = item == button and 4 or 2
					end
				end
			end
		end)
	end

	addChoice("Classic", "CLÁSICA")
	addChoice("Isometric", "ISOMÉTRICA")
end
selectionStateRemote.OnClientEvent:Connect(function(ready, total, chosen)
	if chosen then
		-- La selección fue confirmada por el servidor: cerrar el selector
		-- y dejar visible únicamente la cámara de conducción.
		if selectionGui then
			selectionGui:Destroy()
			selectionGui = nil
		end

		if currentSeat then
			local kart = getKartFromSeat(currentSeat)
			if kart then
				startDrivingCamera(kart)
			end
		end
	elseif selectionGui then
		local status = selectionGui:FindFirstChild("ReadyStatus", true)
		if status then
			status.Text = "Esperando selección " .. ready .. " / " .. total .. " jugadores"
		end
	end
end)
-- La cuenta regresiva visual pertenece exclusivamente a RaceHUD.client.lua.
local function formatVector(vector)
	if not vector then
		return "nil"
	end
	return string.format("(%.2f,%.2f,%.2f)", vector.X, vector.Y, vector.Z)
end

local function describePartVisibility(part)
	if not part then
		return "missing"
	end
	return string.format("%s(t=%.2f,ltm=%.2f)", part.Name, part.Transparency, part.LocalTransparencyModifier)
end

local function describePartGeometry(part)
	if not part then
		return "missing"
	end
	if part:IsA("MeshPart") then
		return string.format("MeshPart(mesh=%s,texture=%s)", part.MeshId, part.TextureID)
	end
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		return string.format("%s/SpecialMesh(mesh=%s,texture=%s)", part.ClassName, mesh.MeshId, mesh.TextureId)
	end
	return part.ClassName
end

local function describeViewportPoint(camera, part)
	if not camera or not part then
		return "unavailable"
	end
	local point, insideViewport = camera:WorldToViewportPoint(part.Position)
	return string.format("inside=%s(x=%.0f,y=%.0f,z=%.2f)", tostring(insideViewport), point.X, point.Y, point.Z)
end

local function logSeatedAvatar(humanoid, seat)
	local character = humanoid.Parent
	if not character then
		return
	end
	local kart = getKartFromSeat(seat)
	local chassis = kart and kart.PrimaryPart

	-- Roblox may apply a local transparency modifier while the player is seated.
	-- Restore opacity on the imported kart body for its actual driver only.
	if character == player.Character then
		local customBody = kart and kart:FindFirstChild("CustomKartBody")
		if customBody then
			local restoredParts = 0
			for _, item in ipairs(customBody:GetDescendants()) do
				if item:IsA("BasePart") then
					item.LocalTransparencyModifier = 0
					item.Transparency = 0
					restoredParts += 1
				elseif item:IsA("Decal") or item:IsA("Texture") then
					item.Transparency = 0
				end
			end
			local inspected = 0
			for _, item in ipairs(customBody:GetDescendants()) do
				if item:IsA("BasePart") and inspected < 12 then
					inspected += 1
					local surfaceAppearance = item:FindFirstChildOfClass("SurfaceAppearance")
					print(("[BLOXY-KART][CLIENT][KART-PART] name=%s class=%s transparency=%.2f localTransparency=%.2f texture=%s surfaceAlpha=%s"):format(
						item.Name,
						item.ClassName,
						item.Transparency,
						item.LocalTransparencyModifier,
						item:IsA("MeshPart") and item.TextureID or "n/a",
						surfaceAppearance and surfaceAppearance.AlphaMode.Name or "none"
					))
				end
			end
			print(("[BLOXY-KART][CLIENT][KART-VISIBILITY] restored=%d imported body parts"):format(restoredParts))
		else
			warn("[BLOXY-KART][CLIENT][KART-VISIBILITY] Kart model not found on the seated kart.")
		end
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local visibleParts = 0
	local totalParts = 0
	local accessoryCount = 0
	local hiddenParts = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Accessory") then
			accessoryCount = accessoryCount + 1
		elseif descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			totalParts = totalParts + 1
			if descendant.Transparency < 1 and descendant.LocalTransparencyModifier < 1 then
				visibleParts = visibleParts + 1
			elseif #hiddenParts < 8 then
				table.insert(hiddenParts, string.format("%s(t=%.2f,ltm=%.2f)", descendant.Name, descendant.Transparency, descendant.LocalTransparencyModifier))
			end
		end
	end
	local seatWeld = seat:FindFirstChild("SeatWeld")
	local rootSeatOffset = root and seat.CFrame:PointToObjectSpace(root.Position)
	local rootChassisOffset = root and chassis and chassis.CFrame:PointToObjectSpace(root.Position)
	local seatChassisOffset = chassis and chassis.CFrame:PointToObjectSpace(seat.Position)
	local facingDot = chassis and seat.CFrame.LookVector:Dot(chassis.CFrame.LookVector) or 0
	local occupant = seat.Occupant
	local camera = Workspace.CurrentCamera
	local function getCameraBlocker(targetPart)
		if not camera or not targetPart then
			return "unavailable", false
		end
		local direction = targetPart.Position - camera.CFrame.Position
		if direction.Magnitude < 0.001 then
			return "camera-at-target", false
		end
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { character }
		local result = Workspace:Raycast(camera.CFrame.Position, direction, raycastParams)
		if result then
			return result.Instance:GetFullName(), kart ~= nil and result.Instance:IsDescendantOf(kart)
		end
		return "none", false
	end
	local headBlocker, headBlockedByKart = getCameraBlocker(head)
	local torsoBlocker, torsoBlockedByKart = getCameraBlocker(torso)
	local headVisible = head ~= nil and head.Transparency < 1 and head.LocalTransparencyModifier < 1
	local torsoVisible = torso ~= nil and torso.Transparency < 1 and torso.LocalTransparencyModifier < 1
	print(("[BLOXY-KART][CLIENT][AVATAR-SEATED] humanoidSit=%s occupant=%s seatWeld=%s seatKartOffset=%s facingDot=%.2f rootSeatOffset=%s rootChassisOffset=%s root=%s head=%s headVisible=%s torso=%s torsoVisible=%s visibleParts=%d/%d accessories=%d hiddenParts=%s headBlocker=%s headBlockedByKart=%s torsoBlocker=%s torsoBlockedByKart=%s"):format(
		tostring(humanoid.Sit), occupant and occupant.Parent and occupant.Parent.Name or "nil", tostring(seatWeld ~= nil),
		formatVector(seatChassisOffset), facingDot, formatVector(rootSeatOffset), formatVector(rootChassisOffset),
		describePartVisibility(root), describePartVisibility(head), tostring(headVisible), describePartVisibility(torso), tostring(torsoVisible),
		visibleParts, totalParts, accessoryCount, #hiddenParts == 0 and "none" or table.concat(hiddenParts, ";"),
		headBlocker, tostring(headBlockedByKart), torsoBlocker, tostring(torsoBlockedByKart)
	))
	local characterParent = character.Parent
	local cameraSubject = camera and camera.CameraSubject
	print(("[BLOXY-KART][CLIENT][AVATAR-RENDER] character=%s parent=%s characterInWorkspace=%s isLocalCharacter=%s rootInWorkspace=%s headInWorkspace=%s torsoInWorkspace=%s rig=%s state=%s health=%.1f platformStand=%s cameraType=%s cameraSubject=%s cameraPos=%s cameraLook=%s cameraFocus=%s viewport=(%.0f,%.0f) fov=%.1f headWorld=%s headScreen=%s headGeometry=%s torsoWorld=%s torsoScreen=%s torsoGeometry=%s"):format(
		character:GetFullName(), characterParent and characterParent:GetFullName() or "nil", tostring(character:IsDescendantOf(Workspace)),
		tostring(player.Character == character), tostring(root ~= nil and root:IsDescendantOf(Workspace)),
		tostring(head ~= nil and head:IsDescendantOf(Workspace)), tostring(torso ~= nil and torso:IsDescendantOf(Workspace)),
		humanoid.RigType.Name, humanoid:GetState().Name, humanoid.Health, tostring(humanoid.PlatformStand),
		camera and camera.CameraType.Name or "missing", cameraSubject and cameraSubject:GetFullName() or "nil",
		formatVector(camera and camera.CFrame.Position), formatVector(camera and camera.CFrame.LookVector),
		formatVector(camera and camera.Focus.Position), camera and camera.ViewportSize.X or 0, camera and camera.ViewportSize.Y or 0,
		camera and camera.FieldOfView or 0, formatVector(head and head.Position), describeViewportPoint(camera, head), describePartGeometry(head),
		formatVector(torso and torso.Position), describeViewportPoint(camera, torso), describePartGeometry(torso)
	))
end

-- Controles móviles estilo kart arcade: aceleración automática, giro por deslizamiento,
-- derrape independiente y freno/reversa en un botón separado.
local mobileControlsGui
local sendDriveInput
local mobileReverseHeld = false
local mobileDriftHeld = false

local function getDriveAxes(canDrive)
	if not canDrive then
		return 0, 0
	end
	if UserInputService.TouchEnabled then
		-- El kart acelera solo. Mantener REVERSA frena y luego marcha atrás.
		local throttle = mobileReverseHeld and -1 or 1
		local steering = mobilePadActive and mobilePadVector.X or 0
		if math.abs(steering) < 0.10 then steering = 0 end
		return throttle, math.clamp(steering, -1, 1)
	end
	local throttle = (held.forward and 1 or 0) - (held.reverse and 1 or 0)
	local steering = (held.right and 1 or 0) - (held.left and 1 or 0)
	return throttle, steering
end

local function createMobileControls()
	if not UserInputService.TouchEnabled then return end
	local playerGui = player:WaitForChild("PlayerGui")
	local oldGui = playerGui:FindFirstChild("BLOXYMobileKartControls")
	if oldGui then oldGui:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "BLOXYMobileKartControls"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 120
	gui.Enabled = false
	gui.Parent = playerGui
	mobileControlsGui = gui

	-- Joystick visible y real: la dirección se calcula desde su centro.
	local joystick = Instance.new("TextButton")
	joystick.Name = "SteeringJoystick"
	joystick.AnchorPoint = Vector2.new(0.5, 0.5)
	joystick.Position = UDim2.new(0.15, 0, 0.82, 0)
	joystick.Size = UDim2.fromOffset(142, 142)
	joystick.BackgroundColor3 = Color3.fromRGB(20, 29, 42)
	joystick.BackgroundTransparency = 0.22
	joystick.BorderSizePixel = 0
	joystick.Text = ""
	joystick.AutoButtonColor = false
	joystick.Parent = gui
	local jc = Instance.new("UICorner"); jc.CornerRadius = UDim.new(1, 0); jc.Parent = joystick
	local js = Instance.new("UIStroke"); js.Color = Color3.fromRGB(235, 241, 250); js.Transparency = 0.25; js.Thickness = 3; js.Parent = joystick
	local thumb = Instance.new("Frame")
	thumb.Name = "JoystickThumb"
	thumb.AnchorPoint = Vector2.new(0.5, 0.5)
	thumb.Position = UDim2.fromScale(0.5, 0.5)
	thumb.Size = UDim2.fromOffset(58, 58)
	thumb.BackgroundColor3 = Color3.fromRGB(255, 197, 72)
	thumb.BorderSizePixel = 0
	thumb.Parent = joystick
	local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(1, 0); tc.Parent = thumb
	local ts = Instance.new("UIStroke"); ts.Color = Color3.new(1,1,1); ts.Thickness = 2; ts.Parent = thumb

	local steerInput
	local function updateSteering(screenPosition)
		local center = joystick.AbsolutePosition + joystick.AbsoluteSize / 2
		local vector = Vector2.new(screenPosition.X - center.X, screenPosition.Y - center.Y)
		local radius = 43
		if vector.Magnitude > radius then vector = vector.Unit * radius end
		thumb.Position = UDim2.new(0.5, vector.X, 0.5, vector.Y)
		mobilePadVector = Vector2.new(math.clamp(vector.X / radius, -1, 1), 0)
		mobilePadActive = true
		if sendDriveInput then sendDriveInput() end
	end
	local function resetSteering()
		steerInput = nil
		mobilePadActive = false
		mobilePadVector = Vector2.zero
		thumb.Position = UDim2.fromScale(0.5, 0.5)
		if sendDriveInput then sendDriveInput() end
	end
	joystick.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			steerInput = input
			updateSteering(input.Position)
		end
	end)
	UserInputService.TouchMoved:Connect(function(input)
		if steerInput and input.UserInputType == Enum.UserInputType.Touch then updateSteering(input.Position) end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if steerInput and input.UserInputType == Enum.UserInputType.MouseMovement then updateSteering(input.Position) end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if steerInput and (input == steerInput or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
			resetSteering()
		end
	end)

	local function makeActionButton(name, title, glyph, position, size, color, action)
		local button = Instance.new("TextButton")
		button.Name = name
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = position
		button.Size = UDim2.fromOffset(size, size)
		button.BackgroundColor3 = color
		button.BackgroundTransparency = 0.05
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.Parent = gui
		local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1, 0); corner.Parent = button
		local stroke = Instance.new("UIStroke"); stroke.Color = Color3.new(1,1,1); stroke.Transparency = 0.12; stroke.Thickness = 2; stroke.Parent = button
		local icon = Instance.new("TextLabel")
		icon.AnchorPoint = Vector2.new(0.5, 0.5); icon.Position = UDim2.new(0.5,0,0.38,0)
		icon.Size = UDim2.fromScale(0.54,0.48); icon.BackgroundTransparency = 1
		icon.Text = glyph; icon.TextColor3 = Color3.new(1,1,1); icon.TextScaled = true
		icon.Font = Enum.Font.GothamBlack; icon.Parent = button
		local caption = Instance.new("TextLabel")
		caption.AnchorPoint = Vector2.new(0.5,0.5); caption.Position = UDim2.new(0.5,0,0.77,0)
		caption.Size = UDim2.new(0.9,0,0.2,0); caption.BackgroundTransparency = 1
		caption.Text = title; caption.TextColor3 = Color3.new(1,1,1); caption.TextScaled = true
		caption.Font = Enum.Font.GothamBold; caption.Parent = button
		local activeInput
		local function pressed(value)
			if action == "drift" then mobileDriftHeld = value; driftHeld = value else mobileReverseHeld = value end
			button.BackgroundTransparency = value and 0.24 or 0.05
			if sendDriveInput then sendDriveInput() end
		end
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				activeInput = input; pressed(true)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if activeInput and (input == activeInput or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
				activeInput = nil; pressed(false)
			end
		end)
	end
	-- Reversa y drift juntos bajo el pulgar derecho.
	makeActionButton("ReverseButton", "FRENO", "▼", UDim2.new(0.76,0,0.82,0), 82, Color3.fromRGB(65,91,118), "reverse")
	makeActionButton("DriftButton", "DRIFT", "↗", UDim2.new(0.91,0,0.82,0), 94, Color3.fromRGB(205,128,35), "drift")
	local autoLabel = Instance.new("TextLabel")
	autoLabel.Name = "AutoAccelerateLabel"; autoLabel.AnchorPoint = Vector2.new(1,1)
	autoLabel.Position = UDim2.new(1,-24,1,-18); autoLabel.Size = UDim2.fromOffset(92,24)
	autoLabel.BackgroundTransparency = 1; autoLabel.Text = "AUTO GAS"
	autoLabel.TextColor3 = Color3.new(1,1,1); autoLabel.TextTransparency = 0.15
	autoLabel.TextSize = 13; autoLabel.Font = Enum.Font.GothamBold; autoLabel.Parent = gui
end

local function setMobileControlsVisible(visible)
	if mobileControlsGui then
		mobileControlsGui.Enabled = visible and currentSeat ~= nil
	end
end

if UserInputService.TouchEnabled then
	createMobileControls()
end

sendDriveInput = function()
	if not currentSeat then return end
	local throttle, steering = getDriveAxes(player:GetAttribute("RaceStarted") == true)
	controlRemote:FireServer(throttle, steering, held.brake)
end

-- ===== Vida visual de los karts (solo cliente) =====
-- Giro de las cuatro ruedas segun la velocidad real y humo de derrape en las
-- ruedas traseras. Funciona para todos los karts de la pista, no solo el propio.
local smokeByKart = setmetatable({}, { __mode = "k" })
local wheelSpinByKart = setmetatable({}, { __mode = "k" })

-- Reaplica la opacidad del kart del jugador mientras conduce. Roblox puede
-- cambiar LocalTransparencyModifier al resolver la oclusión de cámara.
RunService:BindToRenderStep("BLOXYKartRestoreBodyVisibility", Enum.RenderPriority.Last.Value, function()
	if not currentSeat or not currentSeat.Parent then return end
	local kart = getKartFromSeat(currentSeat)
	-- En móvil la cámara puede aplicar transparencia local a piezas fuera de
	-- CustomKartBody. Restauramos el modelo completo del kart del jugador.
	-- No restaurar el modelo completo: eso vuelve visible el kart procedural
	-- de respaldo que debe permanecer oculto cuando existe CustomKartBody.
	local body = kart and kart:FindFirstChild("CustomKartBody")
	if not body then return end

	local function restoreVisible(item)
		if item:IsA("BasePart") then
			if item.Transparency ~= 0 then item.Transparency = 0 end
			if item.LocalTransparencyModifier ~= 0 then item.LocalTransparencyModifier = 0 end
			if not item.CastShadow then item.CastShadow = true end
			if item:IsA("MeshPart") then
				if not item.DoubleSided then item.DoubleSided = true end
				local surfaceAppearance = item:FindFirstChildOfClass("SurfaceAppearance")
				if surfaceAppearance and surfaceAppearance.AlphaMode ~= Enum.AlphaMode.Overlay then
					surfaceAppearance.AlphaMode = Enum.AlphaMode.Overlay
				end
			end
		elseif item:IsA("Decal") or item:IsA("Texture") then
			if item.Transparency ~= 0 then item.Transparency = 0 end
		end
	end

	-- Ejecuta al final del frame, después de la oclusión de cámara de Roblox,
	-- que puede volver a ocultar localmente la carrocería al sentarse.
	restoreVisible(body)
	for _, item in ipairs(body:GetDescendants()) do
		restoreVisible(item)
	end
end)

local function createSmokeEmitters(kart)
	local emitters = {}
	for _, markerName in ipairs({ "Wheel_RearL", "Wheel_RearR" }) do
		local marker = kart:FindFirstChild(markerName, true)
		if marker and marker:IsA("BasePart") then
			local attachment = Instance.new("Attachment")
			attachment.Name = "LocalDriftSmokeAttachment"
			attachment.Parent = marker
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "LocalDriftSmoke"
			emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
			emitter.Enabled = false
			emitter.Rate = 120
			emitter.Lifetime = NumberRange.new(0.9, 1.5)
			emitter.Speed = NumberRange.new(2, 5)
			emitter.SpreadAngle = Vector2.new(35, 35)
			emitter.EmissionDirection = Enum.NormalId.Top
			emitter.Acceleration = Vector3.new(0, 2.5, 0)
			emitter.Drag = 2.5
			emitter.Rotation = NumberRange.new(0, 360)
			emitter.RotSpeed = NumberRange.new(-35, 35)
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 2.4),
				NumberSequenceKeypoint.new(0.4, 5),
				NumberSequenceKeypoint.new(1, 8),
			})
			emitter.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(0.6, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			})
			emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(235, 238, 242))
			emitter.LightEmission = 0.25
			emitter.LightInfluence = 0.2
			emitter.VelocityInheritance = 0.1
			emitter.Parent = attachment
			table.insert(emitters, emitter)
		end
	end
	return emitters
end

local function clearDriftSmoke()
	for _, data in pairs(smokeByKart) do
		for _, emitter in ipairs(data.emitters) do
			emitter.Enabled = false
		end
	end
end

-- Kart propio: estado real del drift. Karts de otros jugadores: se deduce por
-- el derrape lateral (su drift lo calcula su propio cliente).
local function isKartDrifting(kart, chassis, forwardSpeed)
	if kart:GetAttribute("OwnerUserId") == player.UserId then
		return isDrifting
	end
	local lateralSpeed = chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.RightVector)
	return math.abs(forwardSpeed) > (KartConfig.DriftMinSpeed or 8) + 4
		and math.abs(lateralSpeed) > math.max(4, math.abs(forwardSpeed) * 0.12)
end

RunService.RenderStepped:Connect(function(dt)
	local kartsFolder = Workspace:FindFirstChild("PlayerKarts")
	if not kartsFolder then return end
	local now = os.clock()
	for _, kart in ipairs(kartsFolder:GetChildren()) do
		local chassis = kart:IsA("Model") and (kart.PrimaryPart or kart:FindFirstChild("Chassis"))
		if chassis then
			local forwardSpeed = chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)

			-- Giro de ruedas: motores "WheelSpin_*" creados por el servidor.
			local spin = wheelSpinByKart[kart]
			if not spin or (#spin.motors == 0 and now >= spin.nextScan) then
				spin = { motors = {}, angles = {}, nextScan = now + 1 }
				for _, descendant in ipairs(kart:GetDescendants()) do
					if descendant:IsA("Motor6D") and string.sub(descendant.Name, 1, 10) == "WheelSpin_" then
						table.insert(spin.motors, descendant)
						spin.angles[descendant] = 0
					end
				end
				wheelSpinByKart[kart] = spin
			end
			for _, motor in ipairs(spin.motors) do
				if motor.Parent then
					local radius = motor:GetAttribute("WheelRadius") or 1.5
					local angle = (spin.angles[motor] - forwardSpeed * dt / radius) % (2 * math.pi)
					spin.angles[motor] = angle
					motor.Transform = CFrame.Angles(angle, 0, 0)
				end
			end

			-- Humo de derrape continuo; mas denso a mas velocidad.
			local smoke = smokeByKart[kart]
			if not smoke or (#smoke.emitters == 0 and now >= smoke.nextScan) then
				smoke = { emitters = createSmokeEmitters(kart), nextScan = now + 1 }
				smokeByKart[kart] = smoke
			end
			local drifting = isKartDrifting(kart, chassis, forwardSpeed)
			local speedAlpha = math.clamp(math.abs(forwardSpeed) / KartConfig.MaxForwardSpeed, 0, 1)
			for _, emitter in ipairs(smoke.emitters) do
				emitter.Rate = 70 + 110 * speedAlpha
				emitter.Enabled = drifting
			end
		end
	end
end)

local physicsDiagnosticNext = 0
local lastPhysicsPosition = {}
-- La dirección y el giro ganan velocidad gradualmente para evitar una respuesta rígida.
local smoothedSteering = 0
local smoothedYawRate = 0
local function simulateOwnedKart(deltaTime)
	if not currentSeat then
		return
	end
	local kart = getKartFromSeat(currentSeat)
	if not kart or kart:GetAttribute("NetworkOwnerUserId") ~= player.UserId then
		return
	end
	local chassis = kart and kart.PrimaryPart
	local driveForce = chassis and chassis:FindFirstChild("ArcadeDriveForce")
	if not chassis or not driveForce or not driveForce:IsA("VectorForce") then
		warn(("[BLOXY-KART][CLIENT][PHYSICS-MISSING] seat=%s kart=%s chassis=%s force=%s"):format(
			currentSeat:GetFullName(), kart and kart:GetFullName() or "nil",
			chassis and chassis:GetFullName() or "nil", driveForce and driveForce:GetFullName() or "nil"
		))
		return
	end
	if not driveForce.Attachment0 then
		warn(("[BLOXY-KART][CLIENT][FORCE-ATTACHMENT-MISSING] force=%s"):format(driveForce:GetFullName()))
		return
	end

	local velocity = chassis.AssemblyLinearVelocity
	local lookVector = chassis.CFrame.LookVector
	local forward = Vector3.new(lookVector.X, 0, lookVector.Z)
	if forward.Magnitude > 0.001 then
		forward = forward.Unit
	else
		forward = Vector3.new(0, 0, -1)
	end
	local rightVector = chassis.CFrame.RightVector
	local right = Vector3.new(rightVector.X, 0, rightVector.Z)
	if right.Magnitude > 0.001 then
		right = right.Unit
	else
		right = Vector3.new(1, 0, 0)
	end
	local forwardSpeed = velocity:Dot(forward)
	local lateralSpeed = velocity:Dot(right)
	local canDrive = player:GetAttribute("RaceStarted") == true
	local throttle, steering = getDriveAxes(canDrive)
	local dt = math.clamp(deltaTime or 1 / 60, 1 / 240, 1 / 20)
	local steeringResponse = KartConfig.SteeringInputResponsiveness or 9
	local steeringAlpha = 1 - math.exp(-steeringResponse * dt)
	smoothedSteering += (steering - smoothedSteering) * steeringAlpha
	local speedForSteering = math.max(math.abs(forwardSpeed) - (KartConfig.MinimumSteeringSpeed or 1.5), 0)
	local steeringFactor = math.clamp(speedForSteering / 10, 0, 1)
	local speedRatio = math.clamp(math.abs(forwardSpeed) / math.max(KartConfig.MaxForwardSpeed, 1), 0, 1)
	local highSpeedSteering = 1 - speedRatio * (KartConfig.SteeringHighSpeedReduction or 0.22)
	local travelDirection = forwardSpeed >= 0 and 1 or -1
	local driftYawMultiplier = isDrifting and (KartConfig.DriftYawMultiplier or 1.38) or 1
	local targetYawRate = -smoothedSteering * KartConfig.SteeringRate * steeringFactor * highSpeedSteering * travelDirection * driftYawMultiplier
	local yawResponse = KartConfig.SteeringYawResponsiveness or 7
	local yawAlpha = 1 - math.exp(-yawResponse * dt)
	smoothedYawRate += (targetYawRate - smoothedYawRate) * yawAlpha
	chassis.AssemblyAngularVelocity = Vector3.new(0, smoothedYawRate, 0)

	local now = os.clock()
	local driftMinSpeed = KartConfig.DriftMinSpeed or 8
	if driftHeld and math.abs(forwardSpeed) > driftMinSpeed and not isDrifting then
		isDrifting = true
		driftStartTime = now
	elseif not driftHeld and isDrifting then
		local driftDuration = now - driftStartTime
		isDrifting = false
		if driftDuration >= (KartConfig.DriftMinDuration or 0.8) then
			miniTurboEndTime = now + (KartConfig.MiniTurboDuration or 0.75)
		end
	end
	local miniTurboActive = now < miniTurboEndTime

	local acceleration = 0
	if held.brake then
		acceleration = -math.sign(forwardSpeed) * KartConfig.BrakeDeceleration
	elseif throttle > 0 then
		local turboMultiplier = miniTurboActive and (KartConfig.MiniTurboAccelerationMultiplier or 1.45) or 1
		acceleration = KartConfig.ForwardAcceleration * turboMultiplier
	elseif throttle < 0 then
		if forwardSpeed > 2 then
			acceleration = -KartConfig.BrakeDeceleration * 0.65
		else
			acceleration = -KartConfig.ReverseAcceleration
		end
	end

	local drag = -forwardSpeed * KartConfig.CoastDrag
	local lateralForce
	if isDrifting then
		local gripMultiplier = KartConfig.DriftGripMultiplier or 0.32
		local lateralSpeedRatio = KartConfig.DriftLateralSpeedRatio or 0.28
		local targetLateralSpeed = steering * math.abs(forwardSpeed) * lateralSpeedRatio
		lateralForce = (targetLateralSpeed - lateralSpeed) * KartConfig.LateralGrip * gripMultiplier
	else
		lateralForce = -lateralSpeed * KartConfig.LateralGrip
	end
	driveForce.Force = forward * ((acceleration + drag) * chassis.AssemblyMass)
		+ right * (lateralForce * chassis.AssemblyMass)

	local normalMaxSpeed = (throttle < 0 and forwardSpeed <= 2) and KartConfig.MaxReverseSpeed or KartConfig.MaxForwardSpeed
	local maxSpeed = miniTurboActive and throttle > 0 and normalMaxSpeed * (KartConfig.MiniTurboMaxSpeedMultiplier or 1.25) or normalMaxSpeed
	if math.abs(forwardSpeed) > maxSpeed then
		local clamped = math.sign(forwardSpeed) * maxSpeed
		chassis.AssemblyLinearVelocity = forward * clamped + right * lateralSpeed + Vector3.new(0, velocity.Y, 0)
	end

	if false and os.clock() >= physicsDiagnosticNext then
		physicsDiagnosticNext = os.clock() + 2
		local root = chassis.AssemblyRootPart or chassis
		local characterRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local sharesAssembly = characterRoot ~= nil and characterRoot.AssemblyRootPart == root
		local seatWeld = currentSeat:FindFirstChild("SeatWeld")
		local chassisProperties = chassis.CurrentPhysicalProperties
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = { kart, player.Character }
		local groundHit = Workspace:Raycast(chassis.Position, Vector3.new(0, -(chassis.Size.Y * 0.5 + 2), 0), raycastParams)
		local ground = groundHit and groundHit.Instance
		local groundProperties = ground and ground:IsA("BasePart") and ground.CurrentPhysicalProperties or nil
		local combinedFriction = -1
		if groundProperties then
			local totalFrictionWeight = chassisProperties.FrictionWeight + groundProperties.FrictionWeight
			if totalFrictionWeight > 0 then
				combinedFriction = (chassisProperties.Friction * chassisProperties.FrictionWeight
					+ groundProperties.Friction * groundProperties.FrictionWeight) / totalFrictionWeight
			end
		end
		local estimatedFrictionAccelerationLimit = combinedFriction >= 0 and combinedFriction * Workspace.Gravity or -1
		local forwardAcceleration = driveForce.Force:Dot(forward) / math.max(chassis.AssemblyMass, 0.001)
		local previousPosition = lastPhysicsPosition[kart] or chassis.Position
		local distance = (chassis.Position - previousPosition).Magnitude
		lastPhysicsPosition[kart] = chassis.Position
		local anchoredParts = {}
		for _, part in ipairs(kart:GetDescendants()) do
			if part:IsA("BasePart") and part.AssemblyRootPart == root and part.Anchored then
				table.insert(anchoredParts, part.Name)
			end
		end
		print(("[BLOXY-KART][CLIENT][PHYSICS] input=(%.0f,%.0f,%s) chassis=%s chassisAnchored=%s root=%s rootAnchored=%s characterRoot=%s sharesAssembly=%s seatWeld=%s anchoredAssemblyParts=%s mass=%.2f forward=(%.2f,%.2f,%.2f) forwardSpeed=%.2f force=(%.1f,%.1f,%.1f) forceMagnitude=%.1f forwardAcceleration=%.2f forceEnabled=%s attachment=%s applyAtCenter=%s chassisFriction=%.3f chassisFrictionWeight=%.2f ground=%s groundMaterial=%s groundFriction=%.3f groundFrictionWeight=%.2f estimatedFrictionAccelerationLimit=%.2f gravity=%.1f speed=%.2f distance2s=%.2f angular=(%.2f,%.2f,%.2f)"):format(
			throttle, steering, tostring(held.brake), chassis:GetFullName(), tostring(chassis.Anchored),
			root:GetFullName(), tostring(root.Anchored), characterRoot and characterRoot:GetFullName() or "nil",
			tostring(sharesAssembly), tostring(seatWeld ~= nil), #anchoredParts > 0 and table.concat(anchoredParts, ",") or "none",
			chassis.AssemblyMass, forward.X, forward.Y, forward.Z, forwardSpeed,
			driveForce.Force.X, driveForce.Force.Y, driveForce.Force.Z, driveForce.Force.Magnitude,
			forwardAcceleration, tostring(driveForce.Enabled),
			driveForce.Attachment0:GetFullName(), tostring(driveForce.ApplyAtCenterOfMass),
			chassisProperties.Friction, chassisProperties.FrictionWeight,
			ground and ground:GetFullName() or "none", groundHit and groundHit.Material.Name or "none",
			groundProperties and groundProperties.Friction or -1,
			groundProperties and groundProperties.FrictionWeight or -1,
			estimatedFrictionAccelerationLimit, Workspace.Gravity, chassis.AssemblyLinearVelocity.Magnitude, distance,
			chassis.AssemblyAngularVelocity.X,
			chassis.AssemblyAngularVelocity.Y, chassis.AssemblyAngularVelocity.Z
		))
	end
end

RunService.Heartbeat:Connect(simulateOwnedKart)

local function onDriveAction(_, inputState, inputObject)
	if inputObject.KeyCode == Enum.KeyCode.R and inputState == Enum.UserInputState.Begin then
		requestRespawnRemote:FireServer()
		return Enum.ContextActionResult.Sink
	end
	if inputObject.KeyCode == Enum.KeyCode.LeftShift or inputObject.KeyCode == Enum.KeyCode.RightShift then
		if inputState == Enum.UserInputState.Begin then
			driftHeld = true
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			driftHeld = false
		end
		return Enum.ContextActionResult.Sink
	end
	local control = keyToControl[inputObject.KeyCode]
	if control then
		if inputState == Enum.UserInputState.Begin then
			held[control] = true
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			held[control] = false
		end
		sendDriveInput()
	end
	return Enum.ContextActionResult.Sink
end

local function clearDriveInput()
	clearDriftSmoke()
	mobilePadActive = false
	mobilePadVector = Vector2.zero
	mobileAccelerateHeld = false
	mobileDriftHeld = false
	for key in pairs(held) do
		held[key] = false
	end
	driftHeld = false
	isDrifting = false
	driftStartTime = 0
	miniTurboEndTime = 0
	smoothedSteering = 0
	smoothedYawRate = 0
	if currentSeat then
		controlRemote:FireServer(0, 0, false)
	end
	ContextActionService:UnbindAction(driveActionName)
end

local function bindCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	local playerGui = player:WaitForChild("PlayerGui")
	local function hideMobileJumpButton(instance)
		if instance.Name == "JumpButton" and (instance:IsA("ImageButton") or instance:IsA("TextButton")) then
			instance.Visible = false
			instance.Active = false
			instance.AutoButtonColor = false
		end
	end
	for _, descendant in ipairs(playerGui:GetDescendants()) do hideMobileJumpButton(descendant) end
	playerGui.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "JumpButton" then task.defer(hideMobileJumpButton, descendant) end
	end)
	local function updateDrivingState()
		local seat = humanoid.SeatPart
		local kart = getKartFromSeat(seat)
		if seat and seat:IsA("VehicleSeat") and kart then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
			if currentSeat == seat then
				return
			end
			print(("[BLOXY-KART][CLIENT][SEAT] seated=true seat=%s kart=%s ownerAttribute=%s"):format(
				seat:GetFullName(), kart:GetFullName(), tostring(kart:GetAttribute("OwnerUserId"))
			))
			hideEnterPrompt()
			clearDriveInput()
			currentSeat = seat
			setMobileControlsVisible(true)
			ContextActionService:BindActionAtPriority(
				driveActionName,
				onDriveAction,
				false,
				Enum.ContextActionPriority.High.Value,
				table.unpack(driveKeys)
			)
			print(("[BLOXY-KART][CLIENT][BIND] action=%s keys=W,A,S,D,Up,Down,Left,Right,Space"):format(driveActionName))
			sendDriveInput()
			if player:GetAttribute("RaceCamera") then startDrivingCamera(kart) else stopDrivingCamera(); showCameraSelection() end
			task.delay(0.4, function()
				if currentSeat == seat and humanoid.Parent == character then
					logSeatedAvatar(humanoid, seat)
				end
			end)
		else
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			print(("[BLOXY-KART][CLIENT][SEAT] seated=false seatPart=%s"):format(
				humanoid.SeatPart and humanoid.SeatPart:GetFullName() or "nil"
			))
			clearDriveInput()
			currentSeat = nil
			setMobileControlsVisible(false)
			if selectionGui then selectionGui:Destroy(); selectionGui=nil end
			stopDrivingCamera()
		end
	end

	humanoid.Seated:Connect(updateDrivingState)
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(updateDrivingState)
	task.defer(updateDrivingState)
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then
	task.spawn(bindCharacter, player.Character)
end
