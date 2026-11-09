-- BLOCK KARTS | INDUSTRIAL GARAGE LOBBY
-- Builds the enclosed industrial garage beside Pista 1 (Playa).
-- This script only creates the lobby environment and physical room-entry pads.
-- It does not edit KartTestCourse, CourseCheckpoints, track geometry, cameras or kart handling.

local Workspace = game:GetService("Workspace")

local COURSE_NAME = "KartTestCourse"
local GARAGE_NAME = "BlockKartsGarage"
local GARAGE_ORIGIN = Vector3.new(520, 1, 0)

local existing = Workspace:FindFirstChild(GARAGE_NAME)
if existing then existing:Destroy() end

local course = Workspace:WaitForChild(COURSE_NAME, 120)
if not course then
    warn("[GARAGE] KartTestCourse was not found; garage was not built.")
    return
end

local model = Instance.new("Model")
model.Name = GARAGE_NAME
model:SetAttribute("GeneratedByGarageBuilder", true)
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

local function sign(name, text, size, position, faceColor, textColor, parent)
    local board = part(name, size, position, faceColor, Enum.Material.Metal, parent)
    board.CanCollide = false
    board.CanTouch = false
    local gui = Instance.new("SurfaceGui")
    gui.Name = "SignSurface"
    gui.Face = Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 45
    gui.Parent = board

    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = textColor
    label.TextScaled = true
    label.Font = Enum.Font.LondrinaSolid
    label.TextStrokeTransparency = 0.35
    label.Parent = gui
    return board
end

local baseX, baseY, baseZ = GARAGE_ORIGIN.X, GARAGE_ORIGIN.Y, GARAGE_ORIGIN.Z
local floorY = baseY + 2.25

local concrete = Color3.fromRGB(65, 67, 69)
local concreteDark = Color3.fromRGB(39, 42, 45)
local steel = Color3.fromRGB(83, 89, 94)
local steelLight = Color3.fromRGB(117, 123, 127)
local black = Color3.fromRGB(19, 21, 23)
local rubber = Color3.fromRGB(28, 29, 30)
local safetyYellow = Color3.fromRGB(235, 173, 45)
local warmWhite = Color3.fromRGB(245, 239, 220)
local cyan = Color3.fromRGB(35, 190, 205)
local red = Color3.fromRGB(174, 57, 45)

-- Foundation and worn concrete workshop floor.
part("GarageFoundation", Vector3.new(176, 4, 142), Vector3.new(baseX, baseY, baseZ), concreteDark, Enum.Material.Concrete)
part("GarageFloor", Vector3.new(168, 0.5, 134), Vector3.new(baseX, floorY, baseZ), concrete, Enum.Material.Concrete)

-- Subtle service-bay markings, leaving the central driving aisle clear.
for _, xOffset in ipairs({-39, 39}) do
    part("ServiceBayLine_" .. xOffset, Vector3.new(0.35, 0.08, 34), Vector3.new(baseX + xOffset, floorY + 0.29, baseZ - 5), safetyYellow, Enum.Material.SmoothPlastic)
    part("ServiceBayRearLine_" .. xOffset, Vector3.new(24, 0.08, 0.35), Vector3.new(baseX + xOffset, floorY + 0.29, baseZ - 22), safetyYellow, Enum.Material.SmoothPlastic)
end
part("CentralDriveLane", Vector3.new(13, 0.08, 46), Vector3.new(baseX, floorY + 0.3, baseZ + 5), Color3.fromRGB(78, 80, 81), Enum.Material.Asphalt)

-- Fully enclosed workshop shell. The front has a wide garage opening with a raised lintel.
local shell = Instance.new("Folder")
shell.Name = "GarageBuilding"
shell.Parent = model

part("RearConcreteWall", Vector3.new(124, 25, 3), Vector3.new(baseX, floorY + 12.5, baseZ - 29), concreteDark, Enum.Material.Concrete, shell)
part("LeftConcreteWall", Vector3.new(3, 25, 62), Vector3.new(baseX - 61, floorY + 12.5, baseZ), concreteDark, Enum.Material.Concrete, shell)
part("RightConcreteWall", Vector3.new(3, 25, 62), Vector3.new(baseX + 61, floorY + 12.5, baseZ), concreteDark, Enum.Material.Concrete, shell)

part("FrontWallLeft", Vector3.new(43, 25, 3), Vector3.new(baseX - 40.5, floorY + 12.5, baseZ + 29), concreteDark, Enum.Material.Concrete, shell)
part("FrontWallRight", Vector3.new(43, 25, 3), Vector3.new(baseX + 40.5, floorY + 12.5, baseZ + 29), concreteDark, Enum.Material.Concrete, shell)
part("FrontGarageHeader", Vector3.new(39, 6, 3), Vector3.new(baseX, floorY + 22, baseZ + 29), steel, Enum.Material.Metal, shell)

-- Heavy roof and exposed structural beams.
part("GarageRoof", Vector3.new(128, 3, 66), Vector3.new(baseX, floorY + 26.5, baseZ - 1), black, Enum.Material.Metal, shell)
for _, xOffset in ipairs({-58, -30, 0, 30, 58}) do
    part("RoofCrossBeam_" .. xOffset, Vector3.new(1.4, 1.4, 64), Vector3.new(baseX + xOffset, floorY + 24.5, baseZ - 1), steel, Enum.Material.DiamondPlate, shell)
end
for _, xOffset in ipairs({-60, -30, 0, 30, 60}) do
    part("FrontSteelColumn_" .. xOffset, Vector3.new(2.5, 25, 3.2), Vector3.new(baseX + xOffset, floorY + 12.5, baseZ + 27.5), steelLight, Enum.Material.DiamondPlate, shell)
end

-- Industrial fascia and main sign above the entrance.
part("EntranceTopBeam", Vector3.new(128, 2, 3.5), Vector3.new(baseX, floorY + 25, baseZ + 29), safetyYellow, Enum.Material.Metal, shell)
sign("MainSign", "BLOCK KARTS  |  WORKSHOP", Vector3.new(48, 7, 0.8), Vector3.new(baseX, floorY + 17, baseZ + 30.9), black, warmWhite, shell)

-- Back-wall workshop details: metal cabinets, workbench, pegboards and tool silhouettes.
for _, xOffset in ipairs({-48, -31, 31, 48}) do
    local cabinet = part("ToolCabinet_" .. xOffset, Vector3.new(12, 8, 4), Vector3.new(baseX + xOffset, floorY + 4.2, baseZ - 25), steel, Enum.Material.DiamondPlate)
    part("CabinetDoor_" .. xOffset, Vector3.new(5.2, 6.4, 0.18), Vector3.new(baseX + xOffset - 2.8, floorY + 4.2, baseZ - 22.85), concreteDark, Enum.Material.Metal)
    part("CabinetHandle_" .. xOffset, Vector3.new(0.25, 1.2, 0.25), Vector3.new(baseX + xOffset - 2.8, floorY + 4.2, baseZ - 22.65), safetyYellow, Enum.Material.Metal)
    cabinet:SetAttribute("WorkshopProp", true)
end

part("RearWorkbenchTop", Vector3.new(38, 1, 5), Vector3.new(baseX, floorY + 5.3, baseZ - 24), Color3.fromRGB(91, 76, 59), Enum.Material.Wood)
for _, xOffset in ipairs({-16, 16}) do
    part("WorkbenchLeg_" .. xOffset, Vector3.new(1.2, 5, 4), Vector3.new(baseX + xOffset, floorY + 2.7, baseZ - 24), steel, Enum.Material.Metal)
end
part("ToolPegboard", Vector3.new(38, 7, 0.7), Vector3.new(baseX, floorY + 11, baseZ - 27), steel, Enum.Material.DiamondPlate)
for i = -5, 5 do
    part("ToolPeg_" .. i, Vector3.new(0.45, 2.1, 0.3), Vector3.new(baseX + i * 3, floorY + 11, baseZ - 26.4), safetyYellow, Enum.Material.Metal)
end

-- Shelving and stacked tires along both side walls.
for _, side in ipairs({-1, 1}) do
    local x = baseX + side * 54
    for shelf = 1, 3 do
        local y = floorY + 3 + shelf * 4
        part("SideShelf_" .. side .. "_" .. shelf, Vector3.new(8, 0.6, 15), Vector3.new(x - side * 4, y, baseZ - 5), steel, Enum.Material.DiamondPlate)
    end
    for stack = 1, 3 do
        local tire = part("TireStack_" .. side .. "_" .. stack, Vector3.new(3.4, 1.7, 3.4), Vector3.new(x - side * 4, floorY + 1.25 + stack * 1.8, baseZ + 14), rubber, Enum.Material.SmoothPlastic, nil, Enum.PartType.Cylinder)
        tire.Orientation = Vector3.new(0, 0, 90)
    end
end

-- Display platforms for karts: kept away from the driving lane and entrance pads.
for i, xOffset in ipairs({-35, 0, 35}) do
    local x = baseX + xOffset
    part("KartDisplay_" .. i, Vector3.new(22, 0.8, 15), Vector3.new(x, floorY + 0.7, baseZ - 7), black, Enum.Material.Metal)
    part("DisplayEdge_" .. i, Vector3.new(22.4, 0.25, 15.4), Vector3.new(x, floorY + 1.2, baseZ - 7), i == 2 and safetyYellow or steelLight, Enum.Material.DiamondPlate)
    part("DisplayTop_" .. i, Vector3.new(20.5, 0.18, 13.5), Vector3.new(x, floorY + 1.35, baseZ - 7), steel, Enum.Material.Metal)
end

-- Ranking panels integrated into the rear wall.
sign("WinsBoard", "MEJORES PILOTOS  |  VICTORIAS", Vector3.new(27, 9, 0.8), Vector3.new(baseX - 35, floorY + 17, baseZ - 27.1), black, safetyYellow)
sign("TimesBoard", "MEJORES TIEMPOS", Vector3.new(27, 9, 0.8), Vector3.new(baseX + 35, floorY + 17, baseZ - 27.1), black, cyan)

-- Physical race portals. CPU keeps the existing backend name/position.
-- The 1vUser pad is deliberately named for the upcoming matchmaking connection.
local function createRoomPad(name, roomType, labelText, xOffset, glowColor)
    local pad = part(name, Vector3.new(22, 0.55, 17), Vector3.new(baseX + xOffset, floorY + 0.55, baseZ + 15), glowColor, Enum.Material.Neon)
    pad:SetAttribute("LobbyRoomType", roomType)
    pad:SetAttribute("RoomCapacity", 1)
    pad.CanCollide = true
    pad.CanTouch = true

    local trim = part(name .. "_Trim", Vector3.new(23, 0.2, 18), Vector3.new(baseX + xOffset, floorY + 0.2, baseZ + 15), safetyYellow, Enum.Material.Metal)
    trim.CanCollide = false
    local board = sign(name .. "_Sign", labelText, Vector3.new(22, 4.5, 0.8), Vector3.new(baseX + xOffset, floorY + 7, baseZ + 5.7), black, warmWhite)
    board.CanCollide = false

    local light = Instance.new("PointLight")
    light.Color = glowColor
    light.Brightness = 1.1
    light.Range = 18
    light.Parent = pad
    return pad
end

createRoomPad("RoomEntryPad_1vCPU", "1vCPU", "ENTRAR  |  1 VS COMPUTADORA", 28, cyan)
createRoomPad("RoomEntryPad_1vUser", "1vUser", "ENTRAR  |  1 VS USUARIO", -28, red)

-- Industrial ceiling lights and wall-mounted lamps.
for _, xOffset in ipairs({-42, -14, 14, 42}) do
    local lamp = part("CeilingLight_" .. xOffset, Vector3.new(15, 0.45, 2.4), Vector3.new(baseX + xOffset, floorY + 24.5, baseZ - 2), warmWhite, Enum.Material.Neon)
    lamp.CanCollide = false
    lamp.CanTouch = false
    local point = Instance.new("PointLight")
    point.Color = Color3.fromRGB(255, 239, 207)
    point.Brightness = 1.7
    point.Range = 32
    point.Parent = lamp
end

for _, side in ipairs({-1, 1}) do
    local wallLamp = part("WallLamp_" .. side, Vector3.new(1, 5, 2), Vector3.new(baseX + side * 59, floorY + 17, baseZ + 4), warmWhite, Enum.Material.Neon)
    wallLamp.CanCollide = false
    wallLamp.CanTouch = false
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 225, 180)
    light.Brightness = 1.0
    light.Range = 22
    light.Parent = wallLamp
end

-- Arrival lane inside the entrance.
part("ArrivalLane", Vector3.new(14, 0.12, 20), Vector3.new(baseX, floorY + 0.32, baseZ + 21), Color3.fromRGB(52, 55, 57), Enum.Material.Asphalt)

local marker = part("GarageLocator", Vector3.new(2, 2, 2), Vector3.new(baseX, floorY + 2, baseZ + 58), safetyYellow, Enum.Material.Neon)
marker.Transparency = 1
marker.CanCollide = false
marker.CanTouch = false
marker.CanQuery = false
model.PrimaryPart = marker

print(("[GARAGE] Enclosed industrial lobby built at %s. Pista 1 (Playa) was not modified."):format(tostring(GARAGE_ORIGIN)))
