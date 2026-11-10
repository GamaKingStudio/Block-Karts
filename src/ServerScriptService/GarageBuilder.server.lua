-- BLOCK KARTS | PREMIUM PADDOCK GARAGE
-- Garage presentation only. Track geometry, checkpoints and kart physics are untouched.
print("[GARAGE][BOOT] Premium paddock builder running.")

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local GARAGE_NAME = "BlockKartsGarage"
local ORIGIN = Vector3.new(520, 1, 0)
local old = Workspace:FindFirstChild(GARAGE_NAME)
if old then old:Destroy() end

local model = Instance.new("Model")
model.Name = GARAGE_NAME
model:SetAttribute("GeneratedByGarageBuilder", true)
model:SetAttribute("GarageStyle", "PremiumPaddock")
model.Parent = Workspace

local function part(name, size, position, color, material, parent, shape)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    if typeof(position) == "CFrame" then p.CFrame = position else p.Position = position end
    p.Anchored = true
    p.CastShadow = true
    p.CanCollide = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Material = material or Enum.Material.SmoothPlastic
    p.Color = color
    p.Parent = parent or model
    if shape then p.Shape = shape end
    return p
end

local C = {
    floor = Color3.fromRGB(49, 55, 62),
    wall = Color3.fromRGB(65, 71, 78),
    wallDark = Color3.fromRGB(31, 36, 42),
    graphite = Color3.fromRGB(20, 25, 31),
    steel = Color3.fromRGB(104, 116, 126),
    white = Color3.fromRGB(235, 241, 245),
    muted = Color3.fromRGB(158, 171, 181),
    cyan = Color3.fromRGB(49, 190, 210),
    amber = Color3.fromRGB(239, 174, 67),
    red = Color3.fromRGB(207, 75, 67),
    blue = Color3.fromRGB(49, 125, 205),
}

local function lightStrip(name, size, position, color, brightness, range)
    local p = part(name, size, position, color, Enum.Material.Neon)
    p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
    local light = Instance.new("PointLight")
    light.Color = color
    light.Brightness = brightness or 1.3
    light.Range = range or 26
    light.Shadows = false
    light.Parent = p
    return p
end

local function wallSign(name, title, subtitle, size, position, accent, lookAtPosition)
    local board = part(name, size, position, C.graphite, Enum.Material.Metal)
    if lookAtPosition then board.CFrame = CFrame.lookAt(position, lookAtPosition) end
    local gui = Instance.new("SurfaceGui")
    gui.Name = "SignFace"
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 32
    gui.LightInfluence = 0.08
    gui.Parent = board

    local panel = Instance.new("Frame")
    panel.Size = UDim2.fromScale(1, 1)
    panel.BackgroundColor3 = C.graphite
    panel.BorderSizePixel = 0
    panel.Parent = gui

    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0.012, 0, 0.72, 0)
    accentBar.Position = UDim2.new(0.035, 0, 0.14, 0)
    accentBar.BackgroundColor3 = accent or C.cyan
    accentBar.BorderSizePixel = 0
    accentBar.Parent = panel

    local heading = Instance.new("TextLabel")
    heading.Size = UDim2.new(0.88, 0, 0.52, 0)
    heading.Position = UDim2.new(0.09, 0, 0.12, 0)
    heading.BackgroundTransparency = 1
    heading.Text = title
    heading.TextColor3 = C.white
    heading.TextXAlignment = Enum.TextXAlignment.Left
    heading.TextScaled = true
    heading.Font = Enum.Font.GothamBold
    heading.Parent = panel

    local detail = Instance.new("TextLabel")
    detail.Size = UDim2.new(0.88, 0, 0.22, 0)
    detail.Position = UDim2.new(0.09, 0, 0.66, 0)
    detail.BackgroundTransparency = 1
    detail.Text = subtitle or ""
    detail.TextColor3 = accent or C.cyan
    detail.TextXAlignment = Enum.TextXAlignment.Left
    detail.TextScaled = true
    detail.Font = Enum.Font.GothamMedium
    detail.Parent = panel
    return board
end

local function displayKart(name, center, bodyColor)
    local display = Instance.new("Model")
    display.Name = name
    display.Parent = model

    local function piece(partName, size, offset, color, material, shape)
        local p = part(partName, size, center + offset, color, material, display, shape)
        p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
        return p
    end

    piece("MainBody", Vector3.new(4.5, 0.55, 6.2), Vector3.new(0, 0.1, 0), bodyColor, Enum.Material.SmoothPlastic)
    piece("FrontNose", Vector3.new(2.7, 0.32, 1.8), Vector3.new(0, 0.28, 3.35), bodyColor, Enum.Material.SmoothPlastic)
    piece("RearDeck", Vector3.new(4.1, 0.28, 1.3), Vector3.new(0, 0.42, -2.25), C.graphite, Enum.Material.Metal)
    piece("Seat", Vector3.new(1.55, 0.8, 1.5), Vector3.new(0, 0.72, -0.55), C.graphite, Enum.Material.SmoothPlastic)
    -- Sin columnas verticales expuestas en los karts decorativos junto al spawn.

    for side = -1, 1, 2 do
        for axle = -1, 1, 2 do
            local wheel = piece("Tyre_"..side.."_"..axle, Vector3.new(1.2, 1.2, 0.72),
                Vector3.new(side * 2.35, -0.08, axle * 2.05), C.graphite, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
            wheel.Orientation = Vector3.new(0, 0, 90)
            local hub = piece("Hub_"..side.."_"..axle, Vector3.new(0.42, 0.42, 0.75),
                Vector3.new(side * 2.38, -0.08, axle * 2.05), C.steel, Enum.Material.Metal, Enum.PartType.Cylinder)
            hub.Orientation = Vector3.new(0, 0, 90)
        end
    end
    return display
end

local x, y, z = ORIGIN.X, ORIGIN.Y, ORIGIN.Z
local width, depth, wallHeight = 120, 160, 30
local halfW, halfD = width / 2, depth / 2
local floorY = y + 2.25
local ceilingY = floorY + wallHeight
local wallT = 4
local frontZ = z + halfD - wallT / 2
local rearZ = z - halfD + wallT / 2

-- Restrained global lighting: the integrated garage lights do most of the work.
-- Mantener luz de día en todo el circuito: este script corre junto al constructor de pista.
Lighting.Ambient = Color3.fromRGB(145, 153, 165)
Lighting.OutdoorAmbient = Color3.fromRGB(170, 180, 194)
Lighting.Brightness = 2.75
Lighting.ExposureCompensation = -0.12
Lighting.ClockTime = 13.6
Lighting.GlobalShadows = true
local atmosphere = Lighting:FindFirstChild("BloxyBeachAtmosphere") or Instance.new("Atmosphere")
atmosphere.Name = "BloxyBeachAtmosphere"
atmosphere.Density = 0.055
atmosphere.Glare = 0.015
atmosphere.Haze = 0.2
atmosphere.Offset = 0.05
atmosphere.Color = Color3.fromRGB(199, 225, 255)
atmosphere.Decay = Color3.fromRGB(112, 151, 185)
atmosphere.Parent = Lighting

-- Closed concrete shell and clean polished floor.
part("GarageFoundation", Vector3.new(width + 8, 4, depth + 8), Vector3.new(x, y, z), C.wallDark, Enum.Material.Concrete)
part("GarageFloor", Vector3.new(width - 4, 0.6, depth - 4), Vector3.new(x, floorY, z), C.floor, Enum.Material.Concrete)

local shell = Instance.new("Folder")
shell.Name = "GarageBuilding"
shell.Parent = model

part("RearConcreteWall", Vector3.new(width, wallHeight, wallT), Vector3.new(x, floorY + wallHeight/2, rearZ), C.wall, Enum.Material.Concrete, shell)
local gateWidth = 34
local sideWidth = (width - gateWidth) / 2
part("FrontWallLeft", Vector3.new(sideWidth, wallHeight, wallT), Vector3.new(x - gateWidth/2 - sideWidth/2, floorY + wallHeight/2, frontZ), C.wall, Enum.Material.Concrete, shell)
part("FrontWallRight", Vector3.new(sideWidth, wallHeight, wallT), Vector3.new(x + gateWidth/2 + sideWidth/2, floorY + wallHeight/2, frontZ), C.wall, Enum.Material.Concrete, shell)
part("FrontWallLintel", Vector3.new(gateWidth, 2, wallT), Vector3.new(x, floorY + wallHeight - 1, frontZ), C.wall, Enum.Material.Concrete, shell)
part("FrontWallSill", Vector3.new(gateWidth, 2, wallT), Vector3.new(x, floorY + 1, frontZ), C.wall, Enum.Material.Concrete, shell)
part("LeftConcreteWall", Vector3.new(wallT, wallHeight, depth - wallT*2), Vector3.new(x - halfW + wallT/2, floorY + wallHeight/2, z), C.wall, Enum.Material.Concrete, shell)
part("RightConcreteWall", Vector3.new(wallT, wallHeight, depth - wallT*2), Vector3.new(x + halfW - wallT/2, floorY + wallHeight/2, z), C.wall, Enum.Material.Concrete, shell)

-- Closed roller shutter and flush metal framing.
part("GateFrameLeft", Vector3.new(2, wallHeight - 2, 2), Vector3.new(x - gateWidth/2 - 1, floorY + wallHeight/2, frontZ - 1), C.steel, Enum.Material.Metal, shell)
part("GateFrameRight", Vector3.new(2, wallHeight - 2, 2), Vector3.new(x + gateWidth/2 + 1, floorY + wallHeight/2, frontZ - 1), C.steel, Enum.Material.Metal, shell)
local shutter = part("ExitGateShutter", Vector3.new(gateWidth, wallHeight - 4, 1.1),
    Vector3.new(x, floorY + wallHeight/2, frontZ - 2), C.graphite, Enum.Material.Metal, shell)
-- Lamas horizontales uniformes, sin solapamientos ni separaciones exageradas.
for i = 0, 21 do
    local slat = part("ShutterSlat_"..(i + 1), Vector3.new(gateWidth - 0.8, 0.34, 0.12),
        Vector3.new(x, floorY + 2.8 + i * 1.08, frontZ - 2.62),
        i % 2 == 0 and Color3.fromRGB(67, 74, 82) or Color3.fromRGB(52, 59, 67),
        Enum.Material.Metal, shell)
    slat.CanCollide = false
    slat.CanTouch = false
    slat.CanQuery = false
end

-- Vinilo de clausura: bandas diagonales y placa central en el mismo plano visual.
local tapeSurfaceZ = frontZ - 3.22 -- delante de la placa, visible desde el interior
for index, angle in ipairs({-32, 32}) do
    local tape = part("UndergroundClosureTape_"..index, Vector3.new(31, 1.2, 0.12),
        CFrame.new(x, floorY + wallHeight/2, tapeSurfaceZ) * CFrame.Angles(0, 0, math.rad(angle)),
        Color3.fromRGB(218, 39, 45), Enum.Material.SmoothPlastic, shell)
    tape.CanCollide = false
    tape.CanTouch = false
    tape.CanQuery = false
end
local closurePlate = part("UndergroundGarageVinyl", Vector3.new(23, 3.6, 0.18),
    Vector3.new(x, floorY + wallHeight/2, frontZ - 2.98),
    Color3.fromRGB(25, 29, 35), Enum.Material.SmoothPlastic, shell)
closurePlate.CanCollide = false
closurePlate.CanTouch = false
closurePlate.CanQuery = false
local closureGui = Instance.new("SurfaceGui")
closureGui.Name = "UndergroundGarageDisplay"
closureGui.Face = Enum.NormalId.Front
closureGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
closureGui.PixelsPerStud = 20
closureGui.LightInfluence = 0
closureGui.AlwaysOnTop = false
closureGui.Parent = closurePlate
local closureText = Instance.new("TextLabel")
closureText.Name = "UndergroundGarageText"
closureText.Size = UDim2.fromScale(1, 1)
closureText.BackgroundTransparency = 1
closureText.BorderSizePixel = 0
closureText.Text = "UNDERGROUND GARAGE"
closureText.TextColor3 = Color3.fromRGB(255, 238, 205)
closureText.TextScaled = true
closureText.TextWrapped = true
closureText.Font = Enum.Font.GothamBlack
closureText.Parent = closureGui
wallSign("ExitGateSign", "TRACK ACCESS", "SALIDA A PISTA", Vector3.new(25, 3.5, 0.7),
    Vector3.new(x, floorY + wallHeight - 3.2, frontZ - 3), C.amber, Vector3.new(x, floorY + 12, z))

-- Structural columns: continuous side bays plus a symmetric exposed rear frame.
for _, xOff in ipairs({-56, -28, 0, 28, 56}) do
    for _, zOff in ipairs({-76, 0, 76}) do
        if not (xOff == 0 and (zOff == 0 or zOff == 76 or zOff == -76)) then
            part("StructuralColumn_"..xOff.."_"..zOff, Vector3.new(3, wallHeight, 3),
                Vector3.new(x + xOff, floorY + wallHeight/2, z + zOff), C.wallDark, Enum.Material.Concrete, shell)
        end
    end
end

-- Exposed steel portal frame on the rear wall, mirrored left/right.
local rearFrameZ = rearZ + 2.45
for _, xOff in ipairs({-56, -28, 0, 28, 56}) do
    part("RearSteelColumn_"..xOff, Vector3.new(0.85, wallHeight - 2, 0.9),
        Vector3.new(x + xOff, floorY + wallHeight/2, rearFrameZ), C.steel, Enum.Material.Metal, shell)
end
for _, heightOff in ipairs({4, 26}) do
    part("RearSteelCrossBeam_"..heightOff, Vector3.new(width - 8, 0.9, 0.9),
        Vector3.new(x, floorY + heightOff, rearFrameZ), C.steel, Enum.Material.Metal, shell)
end
-- Short matching braces make the rear structure read as a warehouse truss.
for _, side in ipairs({-1, 1}) do
    for _, level in ipairs({-1, 1}) do
        local startX = x + side * 56
        local endX = x + side * 28
        local startY = floorY + (level == -1 and 4 or 26)
        local endY = floorY + (level == -1 and 26 or 4)
        local mid = Vector3.new((startX + endX)/2, (startY + endY)/2, rearFrameZ)
        local length = math.sqrt((endX - startX)^2 + (endY - startY)^2)
        local angle = math.atan2(endY - startY, endX - startX)
        part("RearSteelBrace_"..side.."_"..level, Vector3.new(length, 0.65, 0.75),
            CFrame.new(mid) * CFrame.Angles(0, 0, angle), C.steel, Enum.Material.Metal, shell)
    end
end

part("GarageRoof", Vector3.new(width + 6, 4, depth + 6), Vector3.new(x, ceilingY + 2, z), C.graphite, Enum.Material.Concrete, shell)
for _, zOff in ipairs({-64, -32, 0, 32, 64}) do
    part("RoofBeam_"..zOff, Vector3.new(width - 8, 1.35, 1.8),
        Vector3.new(x, ceilingY - 1.1, z + zOff), C.steel, Enum.Material.Metal, shell)
end
for _, xOff in ipairs({-40, 0, 40}) do
    part("CrossBeam_"..xOff, Vector3.new(1.8, 1.35, depth - 12),
        Vector3.new(x + xOff, ceilingY - 1.1, z), C.steel, Enum.Material.Metal, shell)
end

-- Integrated white ceiling strips and soft cyan perimeter lighting.
for row, zOff in ipairs({-48, 0, 48}) do
    for col, xOff in ipairs({-42, 0, 42}) do
        lightStrip("CeilingLinearLight_"..row.."_"..col, Vector3.new(18, 0.18, 0.55),
            Vector3.new(x + xOff, ceilingY - 2.8, z + zOff), C.white, 1.1, 30)
    end
end
for _, side in ipairs({-1, 1}) do
    lightStrip("WallGuideLight_"..side, Vector3.new(0.18, 0.35, 110),
        Vector3.new(x + side * (halfW - 3), floorY + 10, z), C.cyan, 0.8, 18)
end

-- Back wall: permanent identity and live leaderboard panels.
wallSign("ReceptionSign", "BLOXY KARTS", "COMPETITION PADDOCK", Vector3.new(38, 5, 0.8),
    Vector3.new(x, floorY + wallHeight - 7, rearZ + 2), C.cyan, Vector3.new(x, floorY + 12, z))

local function leaderboardBoard(name, title, position, accent)
    local board = part(name, Vector3.new(20, 7, 0.8), position, C.graphite, Enum.Material.Metal)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "LeaderboardDisplay"
    gui.Face = Enum.NormalId.Back
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 30
    gui.LightInfluence = 0.08
    gui.Parent = board
    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.fromScale(1, 1)
    panel.BackgroundColor3 = C.graphite
    panel.BorderSizePixel = 0
    panel.Parent = gui
    local heading = Instance.new("TextLabel")
    heading.Name = "Heading"
    heading.Size = UDim2.new(0.94, 0, 0.2, 0)
    heading.Position = UDim2.new(0.03, 0, 0.04, 0)
    heading.BackgroundTransparency = 1
    heading.Text = title
    heading.TextColor3 = accent
    heading.TextScaled = true
    heading.Font = Enum.Font.GothamBold
    heading.Parent = panel
    for row = 1, 5 do
        local label = Instance.new("TextLabel")
        label.Name = "LeaderboardRow"..row
        label.Size = UDim2.new(0.94, 0, 0.12, 0)
        label.Position = UDim2.new(0.03, 0, 0.27 + (row - 1) * 0.14, 0)
        label.BackgroundColor3 = row % 2 == 0 and Color3.fromRGB(29, 36, 43) or Color3.fromRGB(23, 29, 35)
        label.BorderSizePixel = 0
        label.Text = string.format("%d    ---", row)
        label.TextColor3 = C.white
        label.TextScaled = true
        label.Font = Enum.Font.GothamMedium
        label.Parent = panel
    end
    return board
end
-- Los tableros quedan centrados en los dos vanos exteriores, sin tapar las columnas.
leaderboardBoard("WinsBoard", "MOST WINS", Vector3.new(x - 42, floorY + 18, rearZ + 3.1), C.cyan)
leaderboardBoard("TimesBoard", "BEST LAP TIMES", Vector3.new(x + 42, floorY + 18, rearZ + 3.1), C.amber)

-- Player gathering area: keep the ten invisible spawn points, without visible floor discs.
for row = 1, 2 do
    for col = 1, 5 do
        local sx = x + (col - 3) * 10
        local sz = z - 57 + (row - 1) * 13
        local spawn = Instance.new("SpawnLocation")
        spawn.Name = "PlayerSpawn_"..row.."_"..col
        spawn.Size = Vector3.new(5, 0.3, 5)
        spawn.Position = Vector3.new(sx, floorY + 0.72, sz)
        spawn.Anchored = true
        spawn.Neutral = true
        spawn.Transparency = 1
        spawn.CanCollide = false
        spawn.Parent = model
    end
end
local gathering = part("SpawnZoneBase", Vector3.new(74, 0.1, 16), Vector3.new(x, floorY + 0.34, z - 22), C.wallDark, Enum.Material.Asphalt)
gathering.CanCollide = false
wallSign("SpawnZoneTitle", "DRIVER LOUNGE", "PUNTO DE ENCUENTRO", Vector3.new(25, 3, 0.6),
    Vector3.new(x, floorY + 4, z - 12), C.white, Vector3.new(x, floorY + 4, z + 24))

-- Left wing: two clean service bays with lifts; no loose barrels or clutter.
wallSign("WorkshopTitle", "RACE WORKSHOP", "AJUSTES Y MANTENIMIENTO", Vector3.new(27, 4, 0.7),
    Vector3.new(x - 43, floorY + 16, z - 5), C.amber, Vector3.new(x, floorY + 16, z - 5))
for bay = 1, 2 do
    local bx = x - 43 + (bay - 1) * 19
    -- Se retiran los postes del elevador: se veían como palitos en la zona de aparición.
    part("LiftPlatform_"..bay, Vector3.new(12, 0.45, 7),
        Vector3.new(bx, floorY + 1.3, z + 5), C.graphite, Enum.Material.Metal)
    displayKart("WorkshopKart_"..bay, Vector3.new(bx, floorY + 2.05, z + 5),
        bay == 1 and C.red or C.blue)
end
for station, zOff in ipairs({-34, 0, 34}) do
    part("WorkshopBench_"..station, Vector3.new(10, 1, 4),
        Vector3.new(x - 50, floorY + 1.1, z + zOff), C.graphite, Enum.Material.Metal)
    part("WorkshopCabinet_"..station, Vector3.new(10, 3, 1.2),
        Vector3.new(x - 50, floorY + 2.8, z + zOff - 3), C.wallDark, Enum.Material.Metal)
end

-- Center: four flush matchmaking stations, each selecting a human-player count.
local padPositions = {{x - 27, z + 24}, {x - 9, z + 24}, {x + 9, z + 24}, {x + 27, z + 24}}
for i, pos in ipairs(padPositions) do
    local px, pz = pos[1], pos[2]
    local padName = i == 1 and "RoomEntryPad_1vCPU" or ("MatchmakingPad_"..i)
    local trim = part(padName.."_Frame", Vector3.new(15, 0.32, 15),
        Vector3.new(px, floorY + 0.42, pz), C.graphite, Enum.Material.Metal)
    trim.CanCollide = true
    local pad = part(padName, Vector3.new(13.8, 0.16, 13.8),
        Vector3.new(px, floorY + 0.64, pz), i % 2 == 0 and C.cyan or C.amber, Enum.Material.SmoothPlastic)
    pad:SetAttribute("LobbyRoomType", "HumanMatchmaking")
    pad:SetAttribute("RoomCapacity", i)
    pad:SetAttribute("RequiredPlayers", i)
    pad:SetAttribute("PadIndex", i)
    pad.CanCollide = true
    pad.CanTouch = true

    local gui = Instance.new("SurfaceGui")
    gui.Name = "QueueStatus"
    gui.Face = Enum.NormalId.Top
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 40
    gui.LightInfluence = 0.05
    gui.AlwaysOnTop = false
    gui.Parent = pad

    local panel = Instance.new("Frame")
    panel.Name = "StencilPanel"
    panel.Size = UDim2.fromScale(1, 1)
    panel.BackgroundColor3 = C.graphite
    panel.BackgroundTransparency = 0.08
    panel.BorderSizePixel = 0
    panel.Parent = gui

    local title = Instance.new("TextLabel")
    title.Name = "QueueLabel"
    title.Size = UDim2.new(0.92, 0, 0.48, 0)
    title.Position = UDim2.new(0.04, 0, 0.12, 0)
    title.BackgroundTransparency = 1
    title.Text = i == 1 and "SOLO" or (tostring(i).." PILOTOS")
    title.TextColor3 = C.white
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = panel

    local count = Instance.new("TextLabel")
    count.Name = "QueueCount"
    count.Size = UDim2.new(0.92, 0, 0.24, 0)
    count.Position = UDim2.new(0.04, 0, 0.65, 0)
    count.BackgroundTransparency = 1
    count.Text = "0/"..tostring(i)
    count.TextColor3 = i % 2 == 0 and C.cyan or C.amber
    count.TextScaled = true
    count.Font = Enum.Font.GothamMedium
    count.Parent = panel
end

-- Right wing: compact showroom plinths with consistent spacing.
wallSign("VehicleStoreTitle", "KART COLLECTION", "VEHÍCULOS DESTACADOS", Vector3.new(27, 4, 0.7),
    Vector3.new(x + 43, floorY + 17, z - 5), C.cyan, Vector3.new(x, floorY + 17, z - 5))
local displayColors = {C.red, C.blue, C.amber, Color3.fromRGB(65, 170, 125)}
for i, zOff in ipairs({-43, -7, 29, 65}) do
    local px, pz = x + 42, z + zOff
    local plinth = part("KartDisplay_"..i, Vector3.new(11, 0.5, 11),
        Vector3.new(px, floorY + 0.65, pz), C.graphite, Enum.Material.Metal, nil, Enum.PartType.Cylinder)
    plinth.Orientation = Vector3.new(0, 0, 90)
    plinth.CanCollide = false
    local ring = part("DisplayAccent_"..i, Vector3.new(11.5, 0.12, 11.5),
        Vector3.new(px, floorY + 0.96, pz), C.cyan, Enum.Material.Neon, nil, Enum.PartType.Cylinder)
    ring.Orientation = Vector3.new(0, 0, 90)
    ring.CanCollide = false
    displayKart("ShowroomKart_"..i, Vector3.new(px, floorY + 1.42, pz), displayColors[i])
end

-- Clear exit lane with subtle guidance; the shutter remains closed until race departure.
local lane = part("ExitDriveLane", Vector3.new(18, 0.1, 30),
    Vector3.new(x, floorY + 0.38, z + 63), C.wallDark, Enum.Material.Asphalt)
lane.CanCollide = false
for _, side in ipairs({-1, 1}) do
    local line = part("ExitLaneLine_"..side, Vector3.new(0.16, 0.06, 30),
        Vector3.new(x + side * 9.5, floorY + 0.45, z + 63), C.amber, Enum.Material.SmoothPlastic)
    line.CanCollide = false
end

-- Stable locator name used by the existing spawn and return flow.
local locator = part("GarageLocator", Vector3.new(2, 2, 2),
    Vector3.new(x, floorY + 2, z + 37), C.cyan, Enum.Material.Neon)
locator.Transparency = 1
locator.CanCollide, locator.CanTouch, locator.CanQuery = false, false, false
model.PrimaryPart = locator

print(("[GARAGE][BUILD] Premium paddock generated at %s (%d x %d x %d); matchmaking pads 1-4 enabled; track untouched.")
    :format(tostring(ORIGIN), width, depth, wallHeight))
