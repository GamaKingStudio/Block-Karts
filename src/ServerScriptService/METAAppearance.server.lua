--[[
    BLOXY KARTS - META banner texture diagnostics
    Only inspects Workspace.META and applies the supplied texture when the
    exact banner mesh asset is found. It never replaces or moves any geometry.
]]

local Workspace = game:GetService("Workspace")

local MODEL_NAME = "META"
local BANNER_MESH_ID = "120071389923358"
local BANNER_TEXTURE_ID = "rbxassetid://71542588828532"

local function assetDigits(value)
    if typeof(value) ~= "string" then
        return ""
    end
    return value:match("%d+") or ""
end

print("[META] METAAppearance script started.")

local meta = Workspace:WaitForChild(MODEL_NAME, 30)
if not meta then
    warn("[META] Workspace.META was not found after 30 seconds.")
    return
end

local matches = {}
local meshCount = 0

for _, descendant in ipairs(meta:GetDescendants()) do
    if descendant:IsA("MeshPart") then
        meshCount += 1
        local meshId = descendant.MeshId
        print("[META][INSPECT] " .. descendant:GetFullName() .. " | MeshId=" .. tostring(meshId))

        if assetDigits(meshId) == BANNER_MESH_ID then
            table.insert(matches, descendant)
        end
    end
end

print("[META] Inspection complete. MeshParts found: " .. meshCount .. "; exact ID matches: " .. #matches)

if #matches == 1 then
    local banner = matches[1]
    banner.TextureID = BANNER_TEXTURE_ID
    print("[META] Texture assigned to " .. banner:GetFullName() .. ". Current TextureID=" .. banner.TextureID)
elseif #matches == 0 then
    warn("[META] No MeshPart inside META has MeshId " .. BANNER_MESH_ID .. ". Nothing was changed; use the INSPECT lines to identify the banner mesh.")
else
    warn("[META] Multiple MeshParts have MeshId " .. BANNER_MESH_ID .. ". Nothing was changed to avoid modifying the wrong piece.")
end
