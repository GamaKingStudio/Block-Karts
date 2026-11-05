-- BLOXY KARTS - Apply the uploaded artwork to the existing finish banner.
-- Exact hierarchy supplied by the developer: KartTestCourse/ImportedFinishStructure/meta/Arco_Meta_Root/Arco_Lona_Cartel
-- No parts are moved, resized, replaced, or recolored.

local Workspace = game:GetService("Workspace")

local TEXTURE_ID = "rbxassetid://71542588828532"
local EXPECTED_MESH_ID = "120071389923358"

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

local candidates = {}
if banner:IsA("MeshPart") then
    table.insert(candidates, banner)
end
for _, item in ipairs(banner:GetDescendants()) do
    if item:IsA("MeshPart") then
        table.insert(candidates, item)
    end
end

print("[META] Found banner object: " .. banner:GetFullName() .. " | class=" .. banner.ClassName .. " | MeshParts=" .. #candidates)

local matches = {}
for _, part in ipairs(candidates) do
    print("[META][INSPECT] " .. part:GetFullName() .. " | MeshId=" .. part.MeshId .. " | TextureID=" .. part.TextureID)
    if string.match(part.MeshId, "%d+") == EXPECTED_MESH_ID then
        table.insert(matches, part)
    end
end

if #matches == 1 then
    matches[1].TextureID = TEXTURE_ID
    print("[META] Texture applied to " .. matches[1]:GetFullName() .. " | TextureID=" .. matches[1].TextureID)
elseif #matches == 0 then
    warn("[META] Target found, but no MeshPart has expected MeshId " .. EXPECTED_MESH_ID .. ". See INSPECT output; nothing changed.")
else
    warn("[META] Multiple MeshParts match expected MeshId. Nothing changed to avoid ambiguity.")
end
