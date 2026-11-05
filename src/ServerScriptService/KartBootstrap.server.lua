print(("[BLOXY-KART][SERVER][BOOTSTRAP] script=%s"):format(script:GetFullName()))

-- Finish banner texture diagnostic/application.
-- Kept in the known-running bootstrap so it cannot be skipped by a separate script.
task.spawn(function()
    local Workspace = game:GetService("Workspace")
    local textureId = "rbxassetid://71542588828532"
    local expectedMeshId = "120071389923358"

    print("[META][BOOTSTRAP] Texture routine started.")

    local course = Workspace:WaitForChild("KartTestCourse", 60)
    if not course then
        warn("[META][BOOTSTRAP] KartTestCourse was not found in Workspace after 60 seconds.")
        return
    end

    local imported = course:WaitForChild("ImportedFinishStructure", 20)
    local meta = imported and imported:WaitForChild("meta", 20)
    local root = meta and meta:WaitForChild("Arco_Meta_Root", 20)
    local banner = root and root:WaitForChild("Arco_Lona_Cartel", 20)

    if not banner then
        warn("[META][BOOTSTRAP] Banner hierarchy incomplete.")
        return
    end

    if not banner:IsA("MeshPart") then
        warn("[META][BOOTSTRAP] Arco_Lona_Cartel is not a MeshPart; class=" .. banner.ClassName)
        return
    end

    local meshDigits = string.match(banner.MeshId, "%d+")
    print("[META][BOOTSTRAP] Banner found: " .. banner:GetFullName()
        .. " | MeshId=" .. banner.MeshId
        .. " | Current TextureID=" .. banner.TextureID)

    if meshDigits ~= expectedMeshId then
        warn("[META][BOOTSTRAP] MeshId mismatch; no texture assigned.")
        return
    end

    local ok, err = pcall(function()
        banner.TextureID = textureId
    end)

    if not ok then
        warn("[META][BOOTSTRAP] Texture assignment failed: " .. tostring(err))
        return
    end

    print("[META][BOOTSTRAP] Texture assigned. Readback TextureID=" .. banner.TextureID)
end)

require(script.Parent:WaitForChild("KartService"))
