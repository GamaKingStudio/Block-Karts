-- BLOCK KARTS | UNDERGROUND GARAGE - BLUEPRINT LAYOUT
-- Reorganizes only the lobby geometry. Race track, checkpoints and race logic are untouched.
print("[GARAGE][BOOT] GarageBuilder.server.lua is running.")
local Workspace = game:GetService("Workspace")

local GARAGE_NAME = "BlockKartsGarage"
local GARAGE_ORIGIN = Vector3.new(520, 1, 0)
local existing = Workspace:FindFirstChild(GARAGE_NAME)
if existing then existing:Destroy() end

print("[GARAGE][BUILD] Building 120 x 160 underground garage.")
local model = Instance.new("Model")
model.Name = GARAGE_NAME
model:SetAttribute("GeneratedByGarageBuilder", true)
model:SetAttribute("GarageStyle", "UndergroundBlueprint")
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

local function buildDisplayKart(name, center, bodyColor)
    local display = Instance.new("Model")
    display.Name = name
    display.Parent = model
    local function piece(partName, size, offset, color, material, shape)
        local p = part(partName, size, center + offset, color, material, display, shape)
        p.CanCollide = false
        p.CanTouch = false
        p.CanQuery = false
        return p
    end
    piece("Chassis", Vector3.new(4.8,0.65,6.6), Vector3.new(0,0,0), bodyColor, Enum.Material.SmoothPlastic)
    piece("Nose", Vector3.new(3.2,0.38,1.8), Vector3.new(0,0.18,3.45), bodyColor, Enum.Material.SmoothPlastic)
    piece("RearWing", Vector3.new(5.4,0.25,0.65), Vector3.new(0,0.95,-2.7), steelLight, Enum.Material.Metal)
    piece("Seat", Vector3.new(1.65,0.8,1.7), Vector3.new(0,0.68,-0.65), black, Enum.Material.Leather)
    piece("SteeringColumn", Vector3.new(0.18,0.8,0.18), Vector3.new(0,0.75,1.15), steelLight, Enum.Material.Metal)
    piece("SteeringWheel", Vector3.new(1.15,0.16,0.16), Vector3.new(0,1.12,1.15), black, Enum.Material.Metal)
    for side=-1,1,2 do
        for axle=-1,1,2 do
            local wheel = piece("Wheel_"..side.."_"..axle, Vector3.new(1.25,1.25,0.8),
                Vector3.new(side*2.55,-0.05,axle*2.15), black, Enum.Material.Rubber, Enum.PartType.Cylinder)
            wheel.Orientation = Vector3.new(0,0,90)
            local hub = piece("Hub_"..side.."_"..axle, Vector3.new(0.45,0.45,0.84),
                Vector3.new(side*2.58,-0.05,axle*2.15), steelLight, Enum.Material.Metal, Enum.PartType.Cylinder)
            hub.Orientation = Vector3.new(0,0,90)
        end
    end
    return display
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
local concrete = Color3.fromRGB(65, 68, 75)
local dark = Color3.fromRGB(55, 58, 62)
local steel = Color3.fromRGB(30, 32, 35)
local steelLight = Color3.fromRGB(139, 148, 153)
local yellow = Color3.fromRGB(244, 184, 55)
local cyan = Color3.fromRGB(35, 205, 220)
local red = Color3.fromRGB(220, 65, 58)
local white = Color3.fromRGB(232, 239, 241)

local x, y, z = GARAGE_ORIGIN.X, GARAGE_ORIGIN.Y, GARAGE_ORIGIN.Z

-- Underground lighting requested by the garage blueprint.
local Lighting = game:GetService("Lighting")
-- Technology is configured in Studio; server scripts cannot write Lighting.Technology.
Lighting.Ambient = Color3.fromRGB(100, 105, 115)
Lighting.OutdoorAmbient = Color3.fromRGB(85, 90, 100)
Lighting.Brightness = 2
Lighting.ClockTime = 14
Lighting.GlobalShadows = true
local bloom=Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
bloom.Intensity=0.25; bloom.Size=18; bloom.Threshold=0.9; bloom.Parent=Lighting
local correction=Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
correction.Contrast=0.05; correction.Saturation=0.05; correction.TintColor=Color3.fromRGB(255,255,255); correction.Parent=Lighting
local atmosphere=Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atmosphere.Density=0.08; atmosphere.Offset=0; atmosphere.Color=Color3.fromRGB(150,160,175); atmosphere.Parent=Lighting
local width, depth = 120, 160
local halfW, halfD = width/2, depth/2
local floorY = y + 2.25
local wallH, wallT = 30, 4
local ceilingY = floorY + wallH
local frontZ, rearZ = z + halfD - wallT/2, z - halfD + wallT/2

-- Main underground shell: 120 x 160 x 30, completely enclosed.
part("GarageFoundation", Vector3.new(width + 8, 4, depth + 8), Vector3.new(x, y, z), dark, Enum.Material.Concrete)
part("GarageFloor", Vector3.new(width - 4, 0.6, depth - 4), Vector3.new(x, floorY, z), Color3.fromRGB(65,68,75), Enum.Material.Concrete)
local shell = Instance.new("Folder")
shell.Name = "GarageBuilding"
shell.Parent = model
part("RearConcreteWall", Vector3.new(width, wallH, wallT), Vector3.new(x, floorY + wallH/2, rearZ), Color3.fromRGB(55,58,62), Enum.Material.Concrete, shell)
local gateCenterX, gateWidth = x, 34
local frontSideWidth=(width-gateWidth)/2
part("FrontConcreteWall_Left",Vector3.new(frontSideWidth,wallH,wallT),Vector3.new(x-(gateWidth/2+frontSideWidth/2),floorY+wallH/2,frontZ),Color3.fromRGB(55,58,62),Enum.Material.Concrete,shell)
part("FrontConcreteWall_Right",Vector3.new(frontSideWidth,wallH,wallT),Vector3.new(x+(gateWidth/2+frontSideWidth/2),floorY+wallH/2,frontZ),Color3.fromRGB(55,58,62),Enum.Material.Concrete,shell)
part("FrontConcreteLintel",Vector3.new(gateWidth,2,wallT),Vector3.new(x,floorY+wallH-1,frontZ),Color3.fromRGB(55,58,62),Enum.Material.Concrete,shell)
part("FrontConcreteSill",Vector3.new(gateWidth,2,wallT),Vector3.new(x,floorY+1,frontZ),Color3.fromRGB(55,58,62),Enum.Material.Concrete,shell)
part("LeftConcreteWall", Vector3.new(wallT, wallH, depth - wallT*2), Vector3.new(x-halfW+wallT/2, floorY+wallH/2, z), Color3.fromRGB(55,58,62), Enum.Material.Concrete, shell)
part("RightConcreteWall", Vector3.new(wallT, wallH, depth - wallT*2), Vector3.new(x+halfW-wallT/2, floorY+wallH/2, z), Color3.fromRGB(55,58,62), Enum.Material.Concrete, shell)

-- Fully closed corrugated-metal shutter on the front (+Z) wall.
part("ExitGateFrameLeft", Vector3.new(3, wallH, 3), Vector3.new(gateCenterX-gateWidth/2-1.5, floorY+wallH/2, frontZ-1), yellow, Enum.Material.Metal, shell)
part("ExitGateFrameRight", Vector3.new(3, wallH, 3), Vector3.new(gateCenterX+gateWidth/2+1.5, floorY+wallH/2, frontZ-1), yellow, Enum.Material.Metal, shell)
part("ExitGateShutter", Vector3.new(gateWidth, wallH-4, 1.2), Vector3.new(gateCenterX, floorY+wallH/2, frontZ-2.2), Color3.fromRGB(35,37,40), Enum.Material.Metal, shell)
for i=1,22 do
 part("ExitShutterRib_"..i, Vector3.new(0.22,wallH-4,0.18),
  Vector3.new(gateCenterX-gateWidth/2+1+(i-1)*(gateWidth-2)/21,floorY+wallH/2,frontZ-2.9),
  Color3.fromRGB(70,74,78),Enum.Material.Metal,shell)
end
sign("ExitGateSign","SALIDA A PISTA",Vector3.new(25,3,0.6),Vector3.new(gateCenterX,floorY+wallH-3.1,frontZ-3.2),black,red)
for _,side in ipairs({-1,1}) do
 neon("ExitWarning_"..side,Vector3.new(0.7,7,0.7),Vector3.new(gateCenterX+side*19,floorY+wallH-7,frontZ-2),red)
end

-- Four structural corner columns plus intermediate 4x30x4 concrete pillars.
for _, xOff in ipairs({-56,-28,0,28,56}) do
 for _, zOff in ipairs({-76,0,76}) do
  if not (xOff==0 and zOff==0) then
   part("StructuralPillar_"..xOff.."_"..zOff,Vector3.new(4,30,4),Vector3.new(x+xOff,floorY+13.5,z+zOff),Color3.fromRGB(45,48,52),Enum.Material.Concrete,shell)
  end
 end
end

-- Roof, exposed steel beams and hazard-marked lower wall skirting.
part("GarageRoof",Vector3.new(width+6,4,depth+6),Vector3.new(x,ceilingY+2,z),black,Enum.Material.Concrete,shell)
for _,zOff in ipairs({-64,-32,0,32,64}) do
 part("RoofBeam_Z"..zOff,Vector3.new(width-8,1.5,2.5),Vector3.new(x,ceilingY-1,z+zOff),Color3.fromRGB(30,32,35),Enum.Material.Metal,shell)
end
for _,xOff in ipairs({-40,0,40}) do
 part("RoofCrossBeam_X"..xOff,Vector3.new(2.5,1.5,depth-12),Vector3.new(x+xOff,ceilingY-1.1,z),Color3.fromRGB(30,32,35),Enum.Material.DiamondPlate,shell)
end
for side=-1,1,2 do
 for i=1,24 do
  local stripe=part("HazardSkirting_"..side.."_"..i,Vector3.new(1.3,0.45,0.35),
   CFrame.new(x+side*(halfW-2.5),floorY+0.7,z-74+(i-1)*6)*CFrame.Angles(0,0,math.rad(35)),
   i%2==0 and yellow or black,Enum.Material.SmoothPlastic,shell)
  stripe.CanCollide=false
 end
end

-- BACK (-Z): two ranking screens. Keep the center area clear: no podium.
local function leaderboardBoard(name, title, size, position, accent)
 local board=part(name,size,position,black,Enum.Material.DiamondPlate)
 local gui=Instance.new("SurfaceGui"); gui.Name="LeaderboardDisplay"; gui.Face=Enum.NormalId.Front
 gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud; gui.PixelsPerStud=32; gui.LightInfluence=0.1; gui.Parent=board
 local panel=Instance.new("Frame"); panel.Name="Panel"; panel.Size=UDim2.fromScale(1,1); panel.BackgroundColor3=Color3.fromRGB(15,20,28); panel.BorderSizePixel=0; panel.Parent=gui
 local stroke=Instance.new("UIStroke"); stroke.Color=accent; stroke.Thickness=3; stroke.Parent=panel
 local heading=Instance.new("TextLabel"); heading.Name="Heading"; heading.Size=UDim2.fromScale(0.96,0.22); heading.Position=UDim2.fromScale(0.02,0.025); heading.BackgroundTransparency=1; heading.Text=title; heading.TextColor3=accent; heading.TextScaled=true; heading.Font=Enum.Font.GothamBlack; heading.Parent=panel
 for row=1,5 do
  local line=Instance.new("TextLabel"); line.Name="LeaderboardRow"..row; line.Size=UDim2.fromScale(0.96,0.12); line.Position=UDim2.fromScale(0.02,0.27+(row-1)*0.14); line.BackgroundColor3=row%2==0 and Color3.fromRGB(24,31,37) or Color3.fromRGB(17,23,29); line.BorderSizePixel=0; line.Text=string.format("%d   ---",row); line.TextColor3=white; line.TextScaled=true; line.Font=Enum.Font.GothamMedium; line.Parent=panel
 end
 return board
end
leaderboardBoard("WinsBoard","RANKING GLOBAL",Vector3.new(30,9,0.8),Vector3.new(x-27,floorY+21,rearZ+2),Color3.fromRGB(0,220,255))
leaderboardBoard("TimesBoard","MEJORES TIEMPOS",Vector3.new(30,9,0.8),Vector3.new(x+27,floorY+21,rearZ+2),white)

-- Ten cylindrical spawn discs in two rows, with cyan neon outer rings.
for row=1,2 do
 for col=1,5 do
  local sx=x+(col-3)*10
  local sz=z-57+(row-1)*13
  local disc=part("SpawnLocation_"..row.."_"..col,Vector3.new(6,0.5,6),Vector3.new(sx,floorY+0.38,sz),Color3.fromRGB(38,45,52),Enum.Material.Metal,nil,Enum.PartType.Cylinder)
  disc.Orientation=Vector3.new(0,0,90); disc.CanCollide=true
  local ring=part("SpawnNeonRing_"..row.."_"..col,Vector3.new(6.5,0.22,6.5),Vector3.new(sx,floorY+0.68,sz),cyan,Enum.Material.Neon,nil,Enum.PartType.Cylinder)
  ring.Orientation=Vector3.new(0,0,90); ring.Transparency=0.2; ring.CanCollide=false
  local spawn=Instance.new("SpawnLocation"); spawn.Name="PlayerSpawn_"..row.."_"..col; spawn.Size=Vector3.new(5.5,0.4,5.5); spawn.Position=Vector3.new(sx,floorY+0.85,sz); spawn.Anchored=true; spawn.Neutral=true; spawn.Transparency=1; spawn.CanCollide=false; spawn.Parent=model
 end
end

-- LEFT (-X): two hydraulic lift bays and compact customization workshop.
sign("WorkshopTitle","TALLER DE PERSONALIZACIÓN",Vector3.new(28,5,0.7),Vector3.new(x-43,floorY+16,z-5),black,yellow)
for bay=1,2 do
 local bx=x-43+(bay-1)*19
 for _,sx in ipairs({-5,5}) do
  part("LiftPost_"..bay.."_"..sx,Vector3.new(1.2,12,1.2),Vector3.new(bx+sx,floorY+6,z+4),Color3.fromRGB(0,120,215),Enum.Material.Metal)
 end
 part("LiftArm_"..bay,Vector3.new(13,0.7,1),Vector3.new(bx,floorY+3,z+4),Color3.fromRGB(0,120,215),Enum.Material.Metal)
 part("LiftPlatform_"..bay,Vector3.new(13,0.5,8),Vector3.new(bx,floorY+2,z+4),steel,Enum.Material.DiamondPlate)
end
for station,zOff in ipairs({-35,0,35}) do
 local sx=x-49
 part("WorkshopBench_"..station,Vector3.new(12,1.2,6),Vector3.new(sx,floorY+1.5,z+zOff),Color3.fromRGB(102,77,53),Enum.Material.Wood)
 part("WorkshopCabinet_"..station,Vector3.new(12,4,2),Vector3.new(sx,floorY+3.2,z+zOff-4),steel,Enum.Material.DiamondPlate)
end
for i=1,4 do
 local barrel=part("WorkshopBarrel_"..i,Vector3.new(3,4,3),Vector3.new(x-53,floorY+2,z-55+i*8),i%2==0 and Color3.fromRGB(30,80,140) or Color3.fromRGB(180,40,35),Enum.Material.Metal,nil,Enum.PartType.Cylinder)
 barrel.Orientation=Vector3.new(0,0,90)
end

-- CENTRAL-LOWER: four true 1:1 square matchmaking pads (14x14).
local padPositions={{x-27,z+24},{x-9,z+24},{x+9,z+24},{x+27,z+24}}
for i,pos in ipairs(padPositions) do
 local px,pz=pos[1],pos[2]
 local padName=i==1 and "RoomEntryPad_1vCPU" or ("MatchmakingPad_"..i)
 local trim=part(padName.."_Frame",Vector3.new(15,0.45,15),Vector3.new(px,floorY+0.45,pz),Color3.fromRGB(35,39,44),Enum.Material.DiamondPlate)
 trim.CanCollide=true
 local pad=part(padName,Vector3.new(14,0.4,14),Vector3.new(px,floorY+0.7,pz),i%2==0 and Color3.fromRGB(0,255,130) or Color3.fromRGB(0,180,255),Enum.Material.Neon)
 pad:SetAttribute("LobbyRoomType","HumanMatchmaking"); pad:SetAttribute("RoomCapacity",4); pad:SetAttribute("PadIndex",i)
 pad.CanCollide=true; pad.CanTouch=i==1
 local gui=Instance.new("SurfaceGui")
 gui.Name="QueueStatus"
 gui.Face=Enum.NormalId.Top
 gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud
 gui.PixelsPerStud=45
 gui.LightInfluence=0.15
 gui.AlwaysOnTop=false
 gui.Parent=pad
 local panel=Instance.new("Frame")
 panel.Name="StencilPanel"
 panel.Size=UDim2.fromScale(1,1)
 panel.BackgroundTransparency=1
 panel.Parent=gui
 local label=Instance.new("TextLabel")
 label.Name="QueueLabel"
 label.Size=UDim2.fromScale(0.9,0.55)
 label.Position=UDim2.fromScale(0.05,0.12)
 label.BackgroundTransparency=1
 label.Text=string.format("PAD %02d",i)
 label.TextColor3=white
 label.TextScaled=true
 label.Font=Enum.Font.RobotoMono
 label.Parent=panel
 local status=Instance.new("TextLabel")
 status.Name="QueueCount"
 status.Size=UDim2.fromScale(0.9,0.24)
 status.Position=UDim2.fromScale(0.05,0.68)
 status.BackgroundTransparency=1
 status.Text="0/4"
 status.TextColor3=yellow
 status.TextScaled=true
 status.Font=Enum.Font.RobotoMono
 status.Parent=panel
end

-- Safety stripe in front of the matchmaking row.
for i=1,18 do
 local stripe=part("MatchmakingSafety_"..i,Vector3.new(1.4,0.08,1.2),CFrame.new(x-36+(i-1)*4,floorY+0.36,z+34)*CFrame.Angles(0,0,math.rad(35)),i%2==0 and yellow or black,Enum.Material.SmoothPlastic)
 stripe.CanCollide=false
end

-- Open center gathering strip; keep it free of podiums and obstacles.
local spawnCenter=Vector3.new(x,floorY+0.34,z+48)
local spawnBase=part("SpawnZoneBase",Vector3.new(76,0.12,18),spawnCenter,Color3.fromRGB(48,53,57),Enum.Material.Asphalt)
spawnBase.CanCollide=false
sign("SpawnZoneTitle","ZONA DE REUNIÓN",Vector3.new(30,3.5,0.6),Vector3.new(x,floorY+3,z+58),black,white)

-- RIGHT (+X): four circular vehicle display plinths.
sign("VehicleStoreTitle","TIENDA DE VEHÍCULOS",Vector3.new(30,5,0.7),Vector3.new(x+43,floorY+17,z-5),black,cyan)
local displayIndex=0
for _,zOff in ipairs({-43,-7,29,65}) do
 displayIndex+=1
 local px,pz=x+42,z+zOff
 local base=part("KartDisplay_"..displayIndex,Vector3.new(12,0.7,12),Vector3.new(px,floorY+0.7,pz),black,Enum.Material.Metal,nil,Enum.PartType.Cylinder)
 base.Orientation=Vector3.new(0,0,90)
 local ring=part("DisplayNeonRing_"..displayIndex,Vector3.new(12.8,0.25,12.8),Vector3.new(px,floorY+1.18,pz),cyan,Enum.Material.Neon,nil,Enum.PartType.Cylinder)
 ring.Orientation=Vector3.new(0,0,90); ring.CanCollide=false
 sign("DisplayLabel_"..displayIndex,"KART "..displayIndex,Vector3.new(10,2,0.4),Vector3.new(px,floorY+3,pz-6.5),black,white)
end
-- Tool shelves and industrial storage in the rear/right corner.
for rack=1,2 do
 local rx=x+54
 local rz=z-65+(rack-1)*18
 part("StoreShelf_"..rack,Vector3.new(2,7,12),Vector3.new(rx,floorY+3.5,rz),steel,Enum.Material.DiamondPlate)
 for level=1,3 do part("StoreShelfLevel_"..rack.."_"..level,Vector3.new(5,0.35,12),Vector3.new(rx-1.5,floorY+level*2,rz),dark,Enum.Material.Metal) end
end

-- Internal route/exit guide (shutter remains closed until a race departure system opens it).
local lane = part("ExitDriveLane", Vector3.new(18,0.1,depth-90),
    Vector3.new(gateCenterX,floorY+0.38,z+35), Color3.fromRGB(48,52,55), Enum.Material.Asphalt)
lane.CanCollide = false
for _, side in ipairs({-1,1}) do
    part("ExitLaneLine_"..side, Vector3.new(0.3,0.08,depth-94),
        Vector3.new(gateCenterX+side*9.5,floorY+0.45,z+35), yellow, Enum.Material.SmoothPlastic)
end
for i = 1,4 do
    neon("ExitArrow_"..i, Vector3.new(3,0.2,0.45),
        Vector3.new(gateCenterX,floorY+0.55,frontZ-8-(i-1)*5), cyan)
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
        if light then light.Brightness, light.Range = 2.5, 42 end
        local spot=Instance.new("SpotLight")
        spot.Angle=90; spot.Brightness=3; spot.Range=55
        spot.Color=Color3.fromRGB(220,235,255)
        spot.Face=Enum.NormalId.Bottom
        spot.Parent=lamp
    end
end

-- Exact locator name is consumed by the existing spawn/return logic.
local marker = part("GarageLocator", Vector3.new(2,2,2),
    Vector3.new(x, floorY+2, z+37), yellow, Enum.Material.Neon)
marker.Transparency = 1
marker.CanCollide, marker.CanTouch, marker.CanQuery = false, false, false
model.PrimaryPart = marker

print(("[GARAGE] Underground garage built at %s (%d x %d x %d). Square matchmaking pads and closed shell generated; race track untouched.")
    :format(tostring(GARAGE_ORIGIN), width, depth, wallH))
