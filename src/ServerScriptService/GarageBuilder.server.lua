-- BLOCK KARTS | GARAGE LOBBY - VISUAL FOUNDATION
-- Builds a separate garage island beside Pista 1 (Playa).
-- This first pass is intentionally visual-only: it does not change player spawning,
-- kart creation, race state, camera selection, controls, or the existing beach course.

local Workspace = game:GetService("Workspace")

local COURSE_NAME = "KartTestCourse"
local GARAGE_NAME = "BlockKartsGarage"
local GARAGE_ORIGIN = Vector3.new(520, 1, 0)

local existing = Workspace:FindFirstChild(GARAGE_NAME)
if existing then
    existing:Destroy()
end

-- Wait for the existing course builder so the garage is added beside it,
-- never inside or in place of the beach track.
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
    p.Material = material or Enum.Material.SmoothPlastic
    p.Color = color
    p.Parent = parent or model
    if shape then p.Shape = shape end
    return p
end

local function sign(name, text, size, position, faceColor, textColor, parent)
    local board = part(name, size, position, faceColor, Enum.Material.SmoothPlastic, parent)
    board.CanCollide = false
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
local concrete = Color3.fromRGB(48, 55, 66)
local dark = Color3.fromRGB(24, 29, 38)
local steel = Color3.fromRGB(91, 105, 121)
local cyan = Color3.fromRGB(34, 205, 225)
local yellow = Color3.fromRGB(255, 195, 45)
local white = Color3.fromRGB(245, 247, 250)
local floorY = baseY + 2

-- Floating concrete apron and marked arrival lane.
part("GarageFoundation", Vector3.new(176, 4, 142), Vector3.new(baseX, baseY, baseZ), concrete, Enum.Material.Concrete)
part("GarageFloor", Vector3.new(168, 0.5, 134), Vector3.new(baseX, floorY, baseZ), Color3.fromRGB(67, 75, 88), Enum.Material.Asphalt)
part("ArrivalLane", Vector3.new(18, 0.12, 54), Vector3.new(baseX, floorY + 0.31, baseZ + 42), cyan, Enum.Material.Neon)
for offset = -1, 1 do
    part("LaneDash_" .. offset, Vector3.new(1.2, 0.14, 8), Vector3.new(baseX + offset * 6, floorY + 0.4, baseZ + 42), white, Enum.Material.Neon)
end

-- Main open-front garage shell: side walls, rear wall, roof and structural beams.
local shell = Instance.new("Folder")
shell.Name = "GarageBuilding"
shell.Parent = model
part("BackWall", Vector3.new(112, 24, 3), Vector3.new(baseX, floorY + 12, baseZ - 28), dark, Enum.Material.Metal, shell)
part("LeftWall", Vector3.new(3, 24, 56), Vector3.new(baseX - 54.5, floorY + 12, baseZ), steel, Enum.Material.Metal, shell)
part("RightWall", Vector3.new(3, 24, 56), Vector3.new(baseX + 54.5, floorY + 12, baseZ), steel, Enum.Material.Metal, shell)
part("Roof", Vector3.new(116, 3, 62), Vector3.new(baseX, floorY + 25.5, baseZ - 1), dark, Enum.Material.Metal, shell)

for _, x in ipairs({-53, -18, 18, 53}) do
    part("FrontSupport_" .. tostring(x), Vector3.new(3, 24, 3), Vector3.new(baseX + x, floorY + 12, baseZ + 27), steel, Enum.Material.Metal, shell)
end

-- Color bands and illuminated garage fascia.
part("FrontFascia", Vector3.new(116, 4, 3), Vector3.new(baseX, floorY + 23, baseZ + 28), cyan, Enum.Material.Neon, shell)
part("FasciaShadow", Vector3.new(116, 1, 3.2), Vector3.new(baseX, floorY + 20.5, baseZ + 28), yellow, Enum.Material.Neon, shell)
sign("MainSign", "BLOCK KARTS  |  GARAGE", Vector3.new(46, 8, 1), Vector3.new(baseX, floorY + 15.5, baseZ + 29.8), dark, white, shell)

-- Three simple display plinths reserved for the player's kart and future showroom.
for i, xOffset in ipairs({-34, 0, 34}) do
    local x = baseX + xOffset
    part("KartDisplay_" .. i, Vector3.new(25, 1, 18), Vector3.new(x, floorY + 0.7, baseZ - 8), dark, Enum.Material.Metal)
    part("DisplayGlow_" .. i, Vector3.new(23, 0.18, 16), Vector3.new(x, floorY + 1.3, baseZ - 8), i == 2 and yellow or cyan, Enum.Material.Neon)
    part("DisplayTop_" .. i, Vector3.new(21, 0.2, 14), Vector3.new(x, floorY + 1.45, baseZ - 8), steel, Enum.Material.Metal)
end

-- Ranking wall: currently a clearly marked placeholder board, ready for live data later.
part("RankingCounter", Vector3.new(28, 2, 5), Vector3.new(baseX - 38, floorY + 4, baseZ - 24), steel, Enum.Material.Metal)
sign("WinsBoard", "PILOTOS  |  VICTORIAS", Vector3.new(25, 12, 1), Vector3.new(baseX - 38, floorY + 13, baseZ - 25.5), dark, yellow)
sign("TimesBoard", "MEJORES TIEMPOS", Vector3.new(25, 12, 1), Vector3.new(baseX + 38, floorY + 13, baseZ - 25.5), dark, cyan)

-- Race entrance / future room and track selection point.
part("RaceDesk", Vector3.new(28, 3, 8), Vector3.new(baseX, floorY + 2, baseZ + 18), dark, Enum.Material.Metal)
sign("RaceDeskSign", "CENTRO DE CARRERAS", Vector3.new(26, 6, 1), Vector3.new(baseX, floorY + 8, baseZ + 13.4), dark, white)

-- Ceiling lights and side accent blocks.
for _, xOffset in ipairs({-40, 0, 40}) do
    local lamp = part("CeilingLight_" .. tostring(xOffset), Vector3.new(20, 0.5, 3), Vector3.new(baseX + xOffset, floorY + 23.7, baseZ - 2), white, Enum.Material.Neon)
    lamp.CanCollide = false
    local point = Instance.new("PointLight")
    point.Color = Color3.fromRGB(190, 235, 255)
    point.Brightness = 1.4
    point.Range = 34
    point.Parent = lamp
end

for _, xOffset in ipairs({-78, 78}) do
    part("CornerPylon_" .. tostring(xOffset), Vector3.new(5, 12, 5), Vector3.new(baseX + xOffset, floorY + 6, baseZ + 51), yellow, Enum.Material.Metal)
    part("CornerGlow_" .. tostring(xOffset), Vector3.new(5.2, 1, 5.2), Vector3.new(baseX + xOffset, floorY + 12.2, baseZ + 51), cyan, Enum.Material.Neon)
end

-- A locator marker makes the separate lobby area easy to find during this visual pass.
local marker = part("GarageLocator", Vector3.new(2, 2, 2), Vector3.new(baseX, floorY + 2, baseZ + 58), yellow, Enum.Material.Neon)
marker.Transparency = 1
marker.CanCollide = false
model.PrimaryPart = marker

print(("[GARAGE] Visual lobby built at %s. Existing Pista 1 (Playa) was left untouched."):format(tostring(GARAGE_ORIGIN)))
