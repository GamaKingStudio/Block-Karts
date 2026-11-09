-- BLOCK KARTS | UNDERGROUND MEGA GARAGE
-- Lobby-only geometry. This script never edits the Playa track or its checkpoints.
print("[GARAGE][BOOT] GarageBuilder.server.lua is running.")
local Workspace = game:GetService("Workspace")

local COURSE_NAME = "KartTestCourse"
local GARAGE_NAME = "BlockKartsGarage"
local GARAGE_ORIGIN = Vector3.new(520, 1, 0)

local existing = Workspace:FindFirstChild(GARAGE_NAME)
if existing then existing:Destroy() end

-- The garage is independent from the race course. Do not block lobby creation
-- while waiting for KartTestCourse: this can leave the server with no garage.
print("[GARAGE][BUILD] Starting underground garage generation.")

local model = Instance.new("Model")
model.Name = GARAGE_NAME
model:SetAttribute("GeneratedByGarageBuilder", true)
model:SetAttribute("GarageStyle", "Underground")
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

local function sign(name, text, size, position, faceColor, textColor, parent, face)
    local board = part(name, size, position, faceColor, Enum.Material.Metal, parent)
    board.CanCollide = false
    board.CanTouch = false
    local gui = Instance.new("SurfaceGui")
    gui.Name = "SignSurface"
    gui.Face = face or Enum.NormalId.Front
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.PixelsPerStud = 35
    gui.Parent = board
    local label = Instance.new("TextLabel")
    label.Name = "Text"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = textColor
    label.TextScaled = true
    label.Font = Enum.Font.LondrinaSolid
    label.TextStrokeTransparency = 0.3
    label.Parent = gui
    return board
end

local x, y, z = GARAGE_ORIGIN.X, GARAGE_ORIGIN.Y, GARAGE_ORIGIN.Z
local floorY = y + 2.25
local width, depth = 250, 220
local halfW, halfD = width / 2, depth / 2
local wallH = 34
local wallT = 4
local ceilingY = floorY + wallH

local concrete = Color3.fromRGB(67, 69, 71)
local concreteDark = Color3.fromRGB(35, 38, 41)
local concreteMid = Color3.fromRGB(52, 56, 60)
local steel = Color3.fromRGB(83, 90, 96)
local steelLight = Color3.fromRGB(121, 127, 132)
local black = Color3.fromRGB(16, 19, 22)
local yellow = Color3.fromRGB(235, 174, 48)
local warmWhite = Color3.fromRGB(240, 232, 211)
local cyan = Color3.fromRGB(35, 190, 205)
local red = Color3.fromRGB(190, 62, 48)

-- Huge underground concrete bunker floor and foundation.
part("GarageFoundation", Vector3.new(width + 12, 5, depth + 12), Vector3.new(x, y, z), concreteDark, Enum.Material.Concrete)
part("GarageFloor", Vector3.new(width - 8, 0.6, depth - 8), Vector3.new(x, floorY, z), concrete, Enum.Material.Concrete)

-- Full perimeter walls. The front wall is continuous: there is NO open entrance.
local shell = Instance.new("Folder")
shell.Name = "GarageBuilding"
shell.Parent = model

part("RearConcreteWall", Vector3.new(width, wallH, wallT), Vector3.new(x, floorY + wallH/2, z - halfD + wallT/2), concreteDark, Enum.Material.Concrete, shell)
part("FrontConcreteWall", Vector3.new(width, wallH, wallT), Vector3.new(x, floorY + wallH/2, z + halfD - wallT/2), concreteDark, Enum.Material.Concrete, shell)
part("LeftConcreteWall", Vector3.new(wallT, wallH, depth - wallT*2), Vector3.new(x - halfW + wallT/2, floorY + wallH/2, z), concreteDark, Enum.Material.Concrete, shell)
part("RightConcreteWall", Vector3.new(wallT, wallH, depth - wallT*2), Vector3.new(x + halfW - wallT/2, floorY + wallH/2, z), concreteDark, Enum.Material.Concrete, shell)

-- Heavy sealed ceiling slab and exposed underground structural girders.
part("GarageRoof", Vector3.new(width + 8, 5, depth + 8), Vector3.new(x, ceilingY + 2, z), black, Enum.Material.Concrete, shell)
for _, zOffset in ipairs({-88, -44, 0, 44, 88}) do
    part("RoofBeam_" .. zOffset, Vector3.new(width - 12, 1.6, 2.4), Vector3.new(x, ceilingY - 1.2, z + zOffset), steel, Enum.Material.DiamondPlate, shell)
end
for _, xOffset in ipairs({-108, -54, 0, 54, 108}) do
    part("RoofCrossBeam_" .. xOffset, Vector3.new(2.2, 1.6, depth - 16), Vector3.new(x + xOffset, ceilingY - 1.3, z), steel, Enum.Material.DiamondPlate, shell)
end

-- Reinforced concrete columns create scale and make the structure feel subterranean.
for _, xOffset in ipairs({-108, -54, 0, 54, 108}) do
    for _, zOffset in ipairs({-88, 0, 88}) do
        if not (xOffset == 0 and zOffset == 0) then
            local pillar = part("ReinforcedPillar_" .. xOffset .. "_" .. zOffset, Vector3.new(4.5, wallH - 1, 4.5), Vector3.new(x + xOffset, floorY + (wallH - 1)/2, z + zOffset), concreteMid, Enum.Material.Concrete)
            part("PillarSafetyBand_" .. xOffset .. "_" .. zOffset, Vector3.new(4.58, 1.2, 4.58), Vector3.new(x + xOffset, floorY + 2.2, z + zOffset), yellow, Enum.Material.Metal)
        end
    end
end

-- Front shutter is a sealed decorative industrial door panel, not an opening.
local shutterZ = z + halfD - wallT - 0.08
part("ClosedSecurityShutter", Vector3.new(104, 22, 0.7), Vector3.new(x, floorY + 11, shutterZ), steel, Enum.Material.DiamondPlate)
for row = 1, 18 do
    part("ShutterRib_" .. row, Vector3.new(103.5, 0.22, 0.9), Vector3.new(x, floorY + 0.7 + row * 1.15, shutterZ - 0.48), steelLight, Enum.Material.Metal)
end
sign("MainSign", "BLOCK KARTS  |  UNDERGROUND RACE GARAGE", Vector3.new(74, 8, 0.9), Vector3.new(x, floorY + 27, shutterZ - 0.65), black, warmWhite)

-- Large floor markings and a wide central circulation lane for many players.
part("MainDriveAisle", Vector3.new(24, 0.1, depth - 38), Vector3.new(x, floorY + 0.36, z), Color3.fromRGB(78, 81, 83), Enum.Material.Asphalt)
for _, xOffset in ipairs({-13, 13}) do
    part("AisleLine_" .. xOffset, Vector3.new(0.35, 0.08, depth - 42), Vector3.new(x + xOffset, floorY + 0.43, z), yellow, Enum.Material.SmoothPlastic)
end

-- Parking / display bays around the perimeter, enough open space for a busy lobby.
for row, zOffset in ipairs({-72, -34, 78}) do
    for col, xOffset in ipairs({-88, -58, 58, 88}) do
        local bx, bz = x + xOffset, z + zOffset
        part("ParkingBay_" .. row .. "_" .. col, Vector3.new(25, 0.08, 30), Vector3.new(bx, floorY + 0.34, bz), Color3.fromRGB(57, 60, 62), Enum.Material.Asphalt)
        for _, edgeX in ipairs({-12, 12}) do
            part("ParkingLine_" .. row .. "_" .. col .. "_" .. edgeX, Vector3.new(0.3, 0.08, 29), Vector3.new(bx + edgeX, floorY + 0.42, bz), yellow, Enum.Material.SmoothPlastic)
        end
    end
end

-- Kart display platforms along the rear half of the bunker.
for i, xOffset in ipairs({-78, -26, 26, 78}) do
    local px, pz = x + xOffset, z - 79
    part("KartDisplay_" .. i, Vector3.new(25, 0.8, 18), Vector3.new(px, floorY + 0.8, pz), black, Enum.Material.Metal)
    part("DisplayEdge_" .. i, Vector3.new(25.5, 0.25, 18.5), Vector3.new(px, floorY + 1.3, pz), i % 2 == 0 and cyan or yellow, Enum.Material.DiamondPlate)
    part("DisplayTop_" .. i, Vector3.new(23.5, 0.18, 16.5), Vector3.new(px, floorY + 1.45, pz), steel, Enum.Material.Metal)
end

-- Workshop stations, tool cabinets and tire racks along the rear wall.
for _, xOffset in ipairs({-104, -82, 82, 104}) do
    part("ToolCabinet_" .. xOffset, Vector3.new(13, 9, 5), Vector3.new(x + xOffset, floorY + 4.8, z - 101), steel, Enum.Material.DiamondPlate)
    part("CabinetDoor_" .. xOffset, Vector3.new(5.5, 7, 0.2), Vector3.new(x + xOffset - 3, floorY + 4.8, z - 98.35), concreteDark, Enum.Material.Metal)
end
part("RearWorkbench", Vector3.new(46, 1, 6), Vector3.new(x, floorY + 5.4, z - 101), Color3.fromRGB(91, 76, 59), Enum.Material.Wood)
part("WorkshopPegboard", Vector3.new(46, 8, 0.7), Vector3.new(x, floorY + 12, z - 107), steel, Enum.Material.DiamondPlate)

-- Ranking boards mounted on the left and right interior walls.
local wins = sign("WinsBoard", "MEJORES PILOTOS  |  VICTORIAS", Vector3.new(34, 11, 0.8), Vector3.new(x - halfW + 3.2, floorY + 23, z - 4), black, yellow)
wins.Orientation = Vector3.new(0, 90, 0)
local times = sign("TimesBoard", "MEJORES TIEMPOS", Vector3.new(34, 11, 0.8), Vector3.new(x + halfW - 3.2, floorY + 23, z - 4), black, cyan)
times.Orientation = Vector3.new(0, -90, 0)

-- Two distinct physical portals in the front half of the interior.
local function createRoomPad(name, roomType, labelText, xOffset, glowColor)
    local px, pz = x + xOffset, z + 48
    local pad = part(name, Vector3.new(30, 0.7, 24), Vector3.new(px, floorY + 0.7, pz), glowColor, Enum.Material.Neon)
    pad:SetAttribute("LobbyRoomType", roomType)
    pad:SetAttribute("RoomCapacity", 1)
    pad.CanCollide = true
    pad.CanTouch = true

    local trim = part(name .. "_Trim", Vector3.new(31, 0.22, 25), Vector3.new(px, floorY + 0.28, pz), yellow, Enum.Material.Metal)
    trim.CanCollide = false
    local board = sign(name .. "_Sign", labelText, Vector3.new(29, 6, 1), Vector3.new(px, floorY + 10, pz - 14), black, warmWhite)
    board.Orientation = Vector3.new(0, 180, 0)
    board.CanCollide = false
    local light = Instance.new("PointLight")
    light.Color = glowColor
    light.Brightness = 1.8
    light.Range = 28
    light.Parent = pad
    return pad
end

createRoomPad("RoomEntryPad_1vCPU", "1vCPU", "ENTRAR  |  1 VS COMPUTADORA", 48, cyan)
createRoomPad("RoomEntryPad_1vUser", "1vUser", "ENTRAR  |  1 VS USUARIO", -48, red)

-- Neon strips mounted directly under the exposed gray roof girders.
-- Most stay steady; a few flicker irregularly for an underground race-garage mood.
local function createBeamNeon(name, size, position, color, flicker)
    local tube = part(name, size, position, color, Enum.Material.Neon)
    tube.CanCollide = false
    tube.CanTouch = false
    tube.CanQuery = false

    local glow = Instance.new("PointLight")
    glow.Name = "BeamNeonGlow"
    glow.Color = color
    glow.Brightness = flicker and 1.25 or 1.8
    glow.Range = flicker and 22 or 28
    glow.Shadows = false
    glow.Parent = tube

    local downLight = Instance.new("SurfaceLight")
    downLight.Name = "BeamNeonDownLight"
    downLight.Face = Enum.NormalId.Bottom
    downLight.Color = color
    downLight.Brightness = flicker and 1.8 or 2.6
    downLight.Range = flicker and 24 or 32
    downLight.Angle = 150
    downLight.Shadows = false
    downLight.Parent = tube

    if flicker then
        task.spawn(function()
            while tube.Parent and model.Parent do
                task.wait(math.random(18, 65) / 10)
                -- Uneven short cuts, followed by a longer dim pulse.
                local pulses = math.random(1, 3)
                for _ = 1, pulses do
                    if not tube.Parent then break end
                    tube.Transparency = 0.82
                    glow.Brightness = 0.08
                    downLight.Brightness = 0.05
                    task.wait(math.random(5, 13) / 100)
                    tube.Transparency = 0.08
                    glow.Brightness = 1.5
                    downLight.Brightness = 2.4
                    task.wait(math.random(7, 18) / 100)
                end
                tube.Transparency = 0.48
                glow.Brightness = 0.45
                downLight.Brightness = 0.6
                task.wait(math.random(12, 30) / 100)
                tube.Transparency = 0
                glow.Brightness = 1.25
                downLight.Brightness = 1.8
            end
        end)
    end
    return tube
end

-- Short segmented tubes follow the underside of the five long roof beams.
for beamIndex, zOffset in ipairs({-88, -44, 0, 44, 88}) do
    for segmentIndex, xOffset in ipairs({-82, -27, 27, 82}) do
        local color = ((beamIndex + segmentIndex) % 3 == 0) and yellow or cyan
        local flicker = (beamIndex == 2 and segmentIndex == 2)
            or (beamIndex == 4 and segmentIndex == 3)
            or (beamIndex == 5 and segmentIndex == 1)
        createBeamNeon(
            "BeamNeon_Long_" .. beamIndex .. "_" .. segmentIndex,
            Vector3.new(39, 0.38, 1.05),
            Vector3.new(x + xOffset, ceilingY - 2.85, z + zOffset),
            color,
            flicker
        )
    end
end

-- Cross-beam accents add depth overhead; selected sections pulse red/cyan.
for beamIndex, xOffset in ipairs({-108, -54, 0, 54, 108}) do
    for segmentIndex, zOffset in ipairs({-66, 0, 66}) do
        local color = (segmentIndex == 2 and beamIndex % 2 == 0) and red or warmWhite
        local flicker = (beamIndex == 1 and segmentIndex == 2)
            or (beamIndex == 3 and segmentIndex == 1)
            or (beamIndex == 5 and segmentIndex == 3)
        createBeamNeon(
            "BeamNeon_Cross_" .. beamIndex .. "_" .. segmentIndex,
            Vector3.new(1.05, 0.38, 38),
            Vector3.new(x + xOffset, ceilingY - 2.9, z + zOffset),
            color,
            flicker
        )
    end
end

-- Industrial overhead light rows and low wall strips. No outdoor sunlight is needed.
for _, zOffset in ipairs({-82, -42, 0, 42, 82}) do
    for _, xOffset in ipairs({-82, -27, 27, 82}) do
        local lamp = part("CeilingLight_" .. xOffset .. "_" .. zOffset, Vector3.new(18, 0.5, 3), Vector3.new(x + xOffset, ceilingY - 3.2, z + zOffset), warmWhite, Enum.Material.Neon)
        lamp.CanCollide = false
        lamp.CanTouch = false
        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(255, 235, 205)
        light.Brightness = 1.35
        light.Range = 34
        light.Parent = lamp
    end
end

for _, side in ipairs({-1, 1}) do
    for _, zOffset in ipairs({-72, -24, 24, 72}) do
        local strip = part("WallLight_" .. side .. "_" .. zOffset, Vector3.new(0.7, 4, 14), Vector3.new(x + side * (halfW - 2.5), floorY + 18, z + zOffset), side == -1 and cyan or red, Enum.Material.Neon)
        strip.CanCollide = false
        strip.CanTouch = false
        local light = Instance.new("PointLight")
        light.Color = strip.Color
        light.Brightness = 0.8
        light.Range = 18
        light.Parent = strip
    end
end

-- Overhead race-control sign keeps the central gathering floor completely open.
sign("ReceptionSign", "RACE CONTROL  |  SELECT YOUR RACE", Vector3.new(32, 5, 0.8), Vector3.new(x, floorY + 19, z + 12), black, yellow)

-- Invisible locator remains at the existing player lobby spawn position.
local marker = part("GarageLocator", Vector3.new(2, 2, 2), Vector3.new(x, floorY + 2, z + 12), yellow, Enum.Material.Neon)
marker.Transparency = 1
marker.CanCollide = false
marker.CanTouch = false
marker.CanQuery = false
model.PrimaryPart = marker

print(("[GARAGE] Underground mega garage built at %s (%d x %d). Playa track untouched."):format(tostring(GARAGE_ORIGIN), width, depth))
