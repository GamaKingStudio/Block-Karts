-- BLOXY KARTS - Replace the artwork on the existing finish banner.
-- The existing model and UV layout are preserved. Every texture channel on
-- the specific banner object is updated so SurfaceAppearance cannot keep
-- displaying the previous artwork.

local Workspace = game:GetService("Workspace")

local TEXTURE_ID = "rbxassetid://77625250062263"

print("[META] Looking for KartTestCourse/ImportedFinishStructure/meta/Arco_Meta_Root/Arco_Lona_Cartel")

local course = Workspace:WaitForChild("KartTestCourse", 30)
if not course then
    warn("[META] KartTestCourse not found directly under Workspace.")
    return
end

local imported = course:WaitForChild("ImportedFinishStructure", 10)
local meta = imported and imported:WaitForChild("meta", 10)
local root = meta and meta:WaitForChild("Arco_Meta_Root", 10)
local banner = root and root:WaitForChild("Arco_Lona_Cartel", 10)

if not banner then
    warn("[META] Banner path incomplete. Check exact spelling/capitalization in Explorer.")
    return
end

local meshCount = 0
local surfaceCount = 0
local decalCount = 0
local textureCount = 0
local specialMeshCount = 0

local function applyToPart(part)
    if part:IsA("MeshPart") then
        part.TextureID = TEXTURE_ID
        meshCount += 1
        print("[META][MESH] " .. part:GetFullName() .. " | MeshId=" .. part.MeshId .. " | TextureID=" .. part.TextureID)
    end

    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("SurfaceAppearance") then
            child.ColorMap = TEXTURE_ID
            surfaceCount += 1
            print("[META][SURFACE] " .. child:GetFullName() .. " | ColorMap=" .. child.ColorMap)
        elseif child:IsA("Decal") then
            child.Texture = TEXTURE_ID
            decalCount += 1
            print("[META][DECAL] " .. child:GetFullName() .. " | Texture=" .. child.Texture)
        elseif child:IsA("Texture") then
            child.Texture = TEXTURE_ID
            textureCount += 1
            print("[META][TEXTURE] " .. child:GetFullName() .. " | Texture=" .. child.Texture)
        elseif child:IsA("SpecialMesh") then
            child.TextureId = TEXTURE_ID
            specialMeshCount += 1
            print("[META][SPECIALMESH] " .. child:GetFullName() .. " | TextureId=" .. child.TextureId)
        end
    end
end

if banner:IsA("BasePart") then
    applyToPart(banner)
end
for _, item in ipairs(banner:GetDescendants()) do
    if item:IsA("BasePart") then
        applyToPart(item)
    elseif item:IsA("Decal") then
        item.Texture = TEXTURE_ID
        decalCount += 1
        print("[META][DECAL] " .. item:GetFullName() .. " | Texture=" .. item.Texture)
    elseif item:IsA("Texture") then
        item.Texture = TEXTURE_ID
        textureCount += 1
        print("[META][TEXTURE] " .. item:GetFullName() .. " | Texture=" .. item.Texture)
    elseif item:IsA("SurfaceAppearance") then
        item.ColorMap = TEXTURE_ID
        surfaceCount += 1
        print("[META][SURFACE] " .. item:GetFullName() .. " | ColorMap=" .. item.ColorMap)
    elseif item:IsA("SpecialMesh") then
        item.TextureId = TEXTURE_ID
        specialMeshCount += 1
        print("[META][SPECIALMESH] " .. item:GetFullName() .. " | TextureId=" .. item.TextureId)
    end
end

print(("[META][RESULT] banner=%s meshes=%d surfaceAppearances=%d decals=%d textures=%d specialMeshes=%d newTexture=%s"):format(
    banner:GetFullName(), meshCount, surfaceCount, decalCount, textureCount, specialMeshCount, TEXTURE_ID
))
if meshCount + surfaceCount + decalCount + textureCount + specialMeshCount == 0 then
    warn("[META] Banner object exists but contains no supported texture target.")
end
