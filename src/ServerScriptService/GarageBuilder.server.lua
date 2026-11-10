-- BLOCK KARTS | UNDERGROUND GARAGE - BLUEPRINT LAYOUT
-- Reorganizes only the lobby geometry. Race track, checkpoints and race logic are untouched.
print("[GARAGE][BOOT] GarageBuilder.server.lua is running.")
local Workspace = game:GetService("Workspace")

local GARAGE_NAME = "BlockKartsGarage"
local GARAGE_ORIGIN = Vector3.new(520, 1, 0)
local existing = Workspace:FindFirstChild(GARAGE_NAME)
if existing then existing:Destroy() end

print("[GARAGE][BUILD] Building 160 x 120 blueprint garage.")
local model = Instance.new("Model")
model.Name = GARAGE_NAME
model:SetAttribute("GeneratedByGarageBuilder", true)
model:SetAttribute("GarageStyle", "UndergroundBlueprint")
model.Parent = Workspace

local function part(name, size, position, color, material, parent, shape)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Position = position
    p.Anchored = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Material = material or Enum.Material.Metal
    p.Color = color
    p.Parent = parent or model
    if shape then p.Shape = shape end
    return p
end

local function neon(name, size, position, color, parent)
    local p = part(name, size, position, color, Enum.Material.Neon, parent)
    p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
    local light = Instance.new("PointLight")
    light.Color, light.Brightness, light.Range = color, 1.15, 22
    light.Parent = p
    return p
end

local function sign(name, text, size, position, faceColor, textColor, parent, face)
    local board = part(name, size, position, faceColor, Enum.Material.DiamondPlate, parent)
    local gui = Instance.new("SurfaceGui")
    gui.Name = "SignFace"
    gui.Face = face or Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 35
    gui.LightInfluence = 0.12
    gui.Parent = board
    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.fromScale(1, 1)
    panel.BackgroundColor3 = Color3.fromRGB(12, 17, 22)
    panel.BorderSizePixel = 0
    panel.Parent = gui
    local stroke = Instance.new("UIStroke")
    stroke.Color, stroke.Thickness = textColor, 3
    stroke.Parent = panel
    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.Size = UDim2.fromScale(0.94, 0.82)
    label.Position = UDim2.fromScale(0.03, 0.09)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = textColor
    label.TextScaled = true
    label.TextWrapped = true
    label.Font = Enum.Font.GothamBold
    label.Parent = panel
    return board
end

local black = Color3.fromRGB(16, 19, 22)
local concrete = Color3.fromRGB(61, 65, 69)
local dark = Color3.fromRGB(29, 33, 37)
local steel = Color3.fromRGB(91, 100, 108)
local steelLight = Color3.fromRGB(139, 148, 153)
local yellow = Color3.fromRGB(244, 184, 55)
local cyan = Color3.fromRGB(35, 205, 220)
local red = Color3.fromRGB(220, 65, 58)
local white = Color3.fromRGB(232, 239, 241)

local x, y, z = GARAGE_ORIGIN.X, GARAGE_ORIGIN.Y, GARAGE_ORIGIN.Z
local width, depth = 160, 120
local halfW, halfD = width/2, depth/2
local floorY = y + 2.25
local wallH, wallT = 28, 3
local ceilingY = floorY + wallH
local frontZ, rearZ = z + halfD - wallT/2, z - halfD + wallT/2

-- Main underground shell. The front-right section is intentionally open for the exit gate.
part("GarageFoundation", Vector3.new(width + 8, 4, depth + 8), Vector3.new(x, y, z), dark, Enum.Material.Concrete)
part("GarageFloor", Vector3.new(width - 4, 0.6, depth - 4), Vector3.new(x, floorY, z), concrete, Enum.Material.Concrete)
local shell = Instance.new("Folder")
shell.Name = "GarageBuilding"
shell.Parent = model
part("RearConcreteWall", Vector3.new(width, wallH, wallT), Vector3.new(x, floorY + wallH/2, rearZ), dark, Enum.Material.Concrete, shell)
part("LeftConcreteWall", Vector3.new(wallT, wallH, depth - wallT*2), Vector3.new(x-halfW+wallT/2, floorY+wallH/2, z), dark, Enum.Material.Concrete, shell)
part("RightConcreteWall", Vector3.new(wallT, wallH, depth - wallT*2), Vector3.new(x+halfW-wallT/2, floorY+wallH/2, z), dark, Enum.Material.Concrete, shell)

-- Front wall has a 34-stud vehicle exit on the right, matching the plan.
local gateCenterX = x + 48
local gateWidth = 34
local leftSpan = (gateCenterX - gateWidth/2) - (x-halfW)
local rightStart = gateCenterX + gateWidth/2
local rightSpan = (x+halfW) - rightStart
part("FrontWall_Left", Vector3.new(leftSpan, wallH, wallT),
    Vector3.new((x-halfW + gateCenterX-gateWidth/2)/2, floorY+wallH/2, frontZ), dark, Enum.Material.Concrete, shell)
part("FrontWall_Right", Vector3.new(rightSpan, wallH, wallT),
    Vector3.new((rightStart + x+halfW)/2, floorY+wallH/2, frontZ), dark, Enum.Material.Concrete, shell)
part("ExitGateHeader", Vector3.new(gateWidth, 6, wallT), Vector3.new(gateCenterX, floorY+wallH-3, frontZ), steel, Enum.Material.DiamondPlate, shell)
-- Raised shutter slats leave a clear opening below for karts to pass through.
for i = 1, 10 do
    part("ExitShutterSlat_"..i, Vector3.new(gateWidth-1, 0.28, 0.7),
        Vector3.new(gateCenterX, floorY+wallH-7+(i-1)*0.48, frontZ-0.45), steelLight, Enum.Material.Metal)
end
sign("ExitGateSign", "SALIDA A PISTA", Vector3.new(gateWidth-2, 3.4, 0.5),
    Vector3.new(gateCenterX, floorY+wallH-4.8, frontZ-0.9), black, yellow)

-- Roof and structural girders preserve the industrial underground identity.
part("GarageRoof", Vector3.new(width+6, 4, depth+6), Vector3.new(x, ceilingY+2, z), black, Enum.Material.Concrete, shell)
for _, zOff in ipairs({-42, 0, 42}) do
    part("RoofBeam_Z"..zOff, Vector3.new(width-10, 1.4, 2.2), Vector3.new(x, ceilingY-1, z+zOff), steel, Enum.Material.DiamondPlate, shell)
end
for _, xOff in ipairs({-52, 0, 52}) do
    part("RoofCrossBeam_X"..xOff, Vector3.new(2, 1.4, depth-12), Vector3.new(x+xOff, ceilingY-1.1, z), steel, Enum.Material.DiamondPlate, shell)
end
for _, xOff in ipairs({-70, -35, 35, 70}) do
    for _, zOff in ipairs({-48, 48}) do
        local pillar = part("Pillar_"..xOff.."_"..zOff, Vector3.new(3.2, wallH-1, 3.2),
            Vector3.new(x+xOff, floorY+(wallH-1)/2, z+zOff), Color3.fromRGB(48,53,57), Enum.Material.Concrete)
        part("PillarBand_"..xOff.."_"..zOff, Vector3.new(3.28, 1, 3.28),
            Vector3.new(x+xOff, floorY+2, z+zOff), yellow, Enum.Material.Metal)
    end
end

-- CENTER BACK: physical global ranking + best times, with a central podium.
local function leaderboardBoard(name, title, size, position, accent)
    local board = part(name, size, position, black, Enum.Material.DiamondPlate)
    local gui = Instance.new("SurfaceGui")
    gui.Name, gui.Face = "LeaderboardDisplay", Enum.NormalId.Front
    gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence = Enum.SurfaceGuiSizingMode.PixelsPerStud, 32, 0.1
    gui.Parent = board
    local panel = Instance.new("Frame")
    panel.Name = "Panel"
    panel.Size = UDim2.fromScale(1,1)
    panel.BackgroundColor3 = Color3.fromRGB(10,15,20)
    panel.BorderSizePixel = 0
    panel.Parent = gui
    local stroke = Instance.new("UIStroke")
    stroke.Color, stroke.Thickness = accent, 3
    stroke.Parent = panel
    local heading = Instance.new("TextLabel")
    heading.Name, heading.Size = "Heading", UDim2.fromScale(0.96,0.22)
    heading.Position = UDim2.fromScale(0.02,0.025)
    heading.BackgroundColor3 = Color3.fromRGB(28,36,43)
    heading.BorderSizePixel = 0
    heading.Text, heading.TextColor3 = title, accent
    heading.TextScaled, heading.Font = true, Enum.Font.GothamBlack
    heading.Parent = panel
    local columns = Instance.new("TextLabel")
    columns.Name, columns.Size = "Columns", UDim2.fromScale(0.96,0.12)
    columns.Position = UDim2.fromScale(0.02,0.265)
    columns.BackgroundTransparency = 1
    columns.Text = name == "TimesBoard" and "#   PILOTO                         TIEMPO" or "#   PILOTO                         VICTORIAS"
    columns.TextColor3, columns.TextScaled = Color3.fromRGB(190,205,215), true
    columns.Font, columns.TextXAlignment = Enum.Font.GothamBold, Enum.TextXAlignment.Left
    columns.Parent = panel
    for row = 1,5 do
        local line = Instance.new("TextLabel")
        line.Name = "LeaderboardRow"..row
        line.Size = UDim2.fromScale(0.96,0.105)
        line.Position = UDim2.fromScale(0.02,0.39+(row-1)*0.112)
        line.BackgroundColor3 = row%2==0 and Color3.fromRGB(24,31,37) or Color3.fromRGB(17,23,29)
        line.BorderSizePixel = 0
        line.Text = name == "TimesBoard" and string.format("%d       ---                         --:--.---",row)
            or string.format("%d       ---                         --",row)
        line.TextColor3, line.TextScaled = white, true
        line.Font, line.TextXAlignment = Enum.Font.GothamMedium, Enum.TextXAlignment.Left
        line.Parent = panel
    end
    return board
end

leaderboardBoard("WinsBoard", "RANKING GLOBAL", Vector3.new(27,8,0.8), Vector3.new(x-25, floorY+21, rearZ+2), yellow)
leaderboardBoard("TimesBoard", "MEJORES TIEMPOS", Vector3.new(27,8,0.8), Vector3.new(x+25, floorY+21, rearZ+2), cyan)
sign("PodiumTitle", "PODIO Y CLASIFICACIONES", Vector3.new(42,4,0.7),
    Vector3.new(x, floorY+14, rearZ+3), black, white)
for place = 1,3 do
    local px = x + (place-2)*8
    local h = place==2 and 7 or (place==1 and 5.5 or 4)
    local podium = part("Podium_"..place, Vector3.new(7,h,5), Vector3.new(px,floorY+0.35+h/2,rearZ+12),
        place==2 and yellow or steel, Enum.Material.Metal)
    sign("PodiumNumber_"..place, tostring(place), Vector3.new(6,3,0.3),
        Vector3.new(px,floorY+h+1,rearZ+9), black, white)
end

-- LEFT SIDE: personalization workshop, benches, toolboards and tire racks.
sign("WorkshopTitle", "TALLER DE PERSONALIZACIÓN", Vector3.new(28,5,0.7),
    Vector3.new(x-64,floorY+13,z-4), black, yellow)
for station, zOff in ipairs({-34, 0, 34}) do
    local sx = x-65
    part("WorkshopBench_"..station, Vector3.new(22,1.2,7), Vector3.new(sx,floorY+4,z+zOff), Color3.fromRGB(102,77,53), Enum.Material.Wood)
    part("WorkshopCabinet_"..station, Vector3.new(20,5,2), Vector3.new(sx,floorY+2.8,z+zOff-5), steel, Enum.Material.DiamondPlate)
    for tool = 1,4 do
        part("WorkshopTool_"..station.."_"..tool, Vector3.new(0.45,3.2,0.35),
            Vector3.new(sx-8+(tool-1)*5.2,floorY+8,z+zOff-5.9), yellow, Enum.Material.Metal)
    end
end
for rack = 1,3 do
    local rz = z-43+(rack-1)*12
    for tire = 1,3 do
        local wheel = part("WorkshopTire_"..rack.."_"..tire, Vector3.new(4.5,1.4,4.5),
            Vector3.new(x-45,floorY+1.1+(tire-1)*1.65,rz), black, Enum.Material.Rubber, nil, Enum.PartType.Cylinder)
        wheel.Orientation = Vector3.new(0,0,90)
    end
end

-- CENTER: four matchmaking floor pads. Pad 1 retains the exact live 1vCPU name/attribute.
local padPositions = {-24, -8, 8, 24}
local padLabels = {"MATCHMAKING 1","MATCHMAKING 2","MATCHMAKING 3","MATCHMAKING 4"}
for i, xOff in ipairs(padPositions) do
    local px, pz = x+xOff, z-10
    local padName = i==1 and "RoomEntryPad_1vCPU" or (i==2 and "RoomEntryPad_1vUser" or "MatchmakingPad_"..i)
    local pad = part(padName, Vector3.new(12,0.65,24), Vector3.new(px,floorY+0.55,pz),
        i%2==0 and red or cyan, Enum.Material.Neon)
    pad:SetAttribute("LobbyRoomType", i==1 and "1vCPU" or (i==2 and "1vUser" or "FutureMatchmaking"))
    pad:SetAttribute("RoomCapacity", 1)
    pad.CanTouch = i==1 -- only the already implemented 1vCPU entry is active
    pad.CanCollide = true
    local trim = part(padName.."_Trim", Vector3.new(12.8,0.18,24.8), Vector3.new(px,floorY+0.25,pz), yellow, Enum.Material.Metal)
    trim.CanCollide, trim.CanTouch = false, false
    sign(padName.."_Sign", padLabels[i], Vector3.new(11.5,3.2,0.5),
        Vector3.new(px,floorY+3.2,pz-13), black, white)
    neon("PadArrow_"..i, Vector3.new(2.5,0.25,0.35), Vector3.new(px,floorY+0.95,pz+8), white)
end

-- LOWER CENTER: open spawn / gathering zone with a semicircular floor marking.
local spawnCenter = Vector3.new(x, floorY+0.42, z+39)
local spawnBase = part("SpawnZoneBase", Vector3.new(68,0.12,23), spawnCenter, Color3.fromRGB(48,53,57), Enum.Material.Asphalt)
spawnBase.CanCollide = false
for _, xOff in ipairs({-23,-8,8,23}) do
    local ring = part("SpawnMarker_"..xOff, Vector3.new(7,0.16,7),
        Vector3.new(x+xOff,floorY+0.55,z+37), xOff%2==0 and cyan or yellow, Enum.Material.Neon, nil, Enum.PartType.Cylinder)
    ring.Orientation = Vector3.new(90,0,0)
    ring.CanCollide = false
end
sign("SpawnZoneTitle", "ZONA DE APARICIÓN", Vector3.new(34,3.8,0.6),
    Vector3.new(x,floorY+3,z+49), black, white)

-- RIGHT SIDE: six vehicle display pads in a 2 x 3 showroom.
sign("VehicleStoreTitle", "TIENDA DE VEHÍCULOS / TIENDA", Vector3.new(39,5,0.7),
    Vector3.new(x+59,floorY+17,z-9), black, cyan)
local displayIndex = 0
for _, zOff in ipairs({-35,-8,19}) do
    for _, xOff in ipairs({43,70}) do
        displayIndex += 1
        local px, pz = x+xOff, z+zOff
        local base = part("KartDisplay_"..displayIndex, Vector3.new(22,1,17),
            Vector3.new(px,floorY+0.8,pz), black, Enum.Material.Metal)
        part("DisplayEdge_"..displayIndex, Vector3.new(22.5,0.22,17.5),
            Vector3.new(px,floorY+1.38,pz), displayIndex%2==0 and cyan or yellow, Enum.Material.DiamondPlate)
        part("DisplayTop_"..displayIndex, Vector3.new(20.5,0.12,15.5),
            Vector3.new(px,floorY+1.55,pz), steel, Enum.Material.Metal)
        sign("DisplayLabel_"..displayIndex, "VEHÍCULO "..displayIndex, Vector3.new(17,2.3,0.4),
            Vector3.new(px,floorY+3.2,pz-8.5), black, white)
    end
end

-- Drive lane from spawn zone to the open exit gate.
local lane = part("ExitDriveLane", Vector3.new(22,0.1,depth-18),
    Vector3.new(gateCenterX,floorY+0.38,z+2), Color3.fromRGB(48,52,55), Enum.Material.Asphalt)
lane.CanCollide = false
for _, side in ipairs({-1,1}) do
    part("ExitLaneLine_"..side, Vector3.new(0.3,0.08,depth-22),
        Vector3.new(gateCenterX+side*11.5,floorY+0.45,z+2), yellow, Enum.Material.SmoothPlastic)
end
for i = 1,4 do
    neon("ExitArrow_"..i, Vector3.new(3,0.2,0.45),
        Vector3.new(gateCenterX,floorY+0.55,frontZ-9+(i-1)*5), cyan)
end

-- Garage identity sign stays physical and mounted; race entry logic is unchanged.
sign("ReceptionSign", "BLOXY KARTS  |  UNDERGROUND", Vector3.new(48,4,0.7),
    Vector3.new(x,floorY+wallH-7,rearZ+2), black, yellow)

-- Ceiling neon: cyan/yellow strips and a few deliberately flickering sections.
for row, zOff in ipairs({-43,0,43}) do
    for col, xOff in ipairs({-50,-17,17,50}) do
        local color = (row+col)%3==0 and yellow or cyan
        local tube = neon("CeilingNeon_"..row.."_"..col, Vector3.new(22,0.32,0.8),
            Vector3.new(x+xOff,ceilingY-2.8,z+zOff), color)
        if (row*3+col)%5==0 then
            task.spawn(function()
                while tube.Parent and model.Parent do
                    task.wait(math.random(25,65)/10)
                    tube.Transparency = 0.78
                    task.wait(0.08)
                    tube.Transparency = 0
                end
            end)
        end
    end
end
for _, zOff in ipairs({-42,0,42}) do
    for _, xOff in ipairs({-48,0,48}) do
        local lamp = neon("CeilingLamp_"..xOff.."_"..zOff, Vector3.new(12,0.35,2.5),
            Vector3.new(x+xOff,ceilingY-3.2,z+zOff), white)
        local light = lamp:FindFirstChildOfClass("PointLight")
        if light then light.Brightness, light.Range = 1.5, 28 end
    end
end

-- Exact locator name is consumed by the existing spawn/return logic.
local marker = part("GarageLocator", Vector3.new(2,2,2),
    Vector3.new(x, floorY+2, z+37), yellow, Enum.Material.Neon)
marker.Transparency = 1
marker.CanCollide, marker.CanTouch, marker.CanQuery = false, false, false
model.PrimaryPart = marker

print(("[GARAGE] Blueprint garage built at %s (%d x %d). Existing 1vCPU pad and leaderboard IDs preserved; race track untouched.")
    :format(tostring(GARAGE_ORIGIN), width, depth))
