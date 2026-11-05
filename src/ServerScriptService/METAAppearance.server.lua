--[[
    BLOXY KARTS - META banner texture
    Applies the uploaded BLOXY KARTS artwork to the existing banner MeshPart
    inside Workspace.META. Does not replace, move, resize, or recolor the arch.
    This runs when the server starts; the change is applied in the running game.
]]

local Workspace = game:GetService("Workspace")

local MODEL_NAME = "META"
local BANNER_MESH_ID = "rbxassetid://120071389923358"
local BANNER_TEXTURE_ID = "rbxassetid://71542588828532"

local function normalizeAssetId(value)
    if typeof(value) ~= "string" then
        return ""
    end

    local digits = value:match("%d+")
    return digits or value
end

local meta = Workspace:WaitForChild(MODEL_NAME, 30)
if not meta then
    warn("[META] No se encontró Workspace.META; no se aplicó la textura.")
    return
end

local matches = {}

for _, descendant in ipairs(meta:GetDescendants()) do
    if descendant:IsA("MeshPart")
        and normalizeAssetId(descendant.MeshId) == normalizeAssetId(BANNER_MESH_ID) then
        table.insert(matches, descendant)
    end
end

if #matches == 1 then
    matches[1].TextureID = BANNER_TEXTURE_ID
    print("[META] Textura BLOXY KARTS aplicada a " .. matches[1]:GetFullName())
elseif #matches == 0 then
    warn("[META] No se encontró una MeshPart con MeshId " .. BANNER_MESH_ID .. ". No se modificó ningún objeto.")
else
    warn("[META] Se encontraron " .. #matches .. " mallas coincidentes. No se modificó ninguna para evitar cambios ambiguos.")
end
