-- BLOXY KARTZ | Custom first-load screen
-- Removes Roblox's default loading overlay and displays the supplied game icon.
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local GAME_ICON = "rbxassetid://111362919336374"

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "BloxyKartzLoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 10000
gui.Parent = playerGui

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(8, 12, 18)
background.BorderSizePixel = 0
background.Parent = gui

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 13, 22)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 24, 34)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 8, 14)),
})
gradient.Rotation = 35
gradient.Parent = background

local accent = Instance.new("Frame")
accent.Name = "AccentLine"
accent.AnchorPoint = Vector2.new(0.5, 0.5)
accent.Position = UDim2.fromScale(0.5, 0.72)
accent.Size = UDim2.new(0.22, 0, 0, 3)
accent.BackgroundColor3 = Color3.fromRGB(34, 205, 220)
accent.BorderSizePixel = 0
accent.Parent = background

local icon = Instance.new("ImageLabel")
icon.Name = "GameIcon"
icon.AnchorPoint = Vector2.new(0.5, 0.5)
icon.Position = UDim2.fromScale(0.5, 0.39)
icon.Size = UDim2.fromOffset(190, 190)
icon.BackgroundTransparency = 1
icon.Image = GAME_ICON
icon.ScaleType = Enum.ScaleType.Fit
icon.Parent = background

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(0, 22)
iconCorner.Parent = icon

local title = Instance.new("TextLabel")
title.Name = "GameTitle"
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.57)
title.Size = UDim2.new(0.8, 0, 0, 54)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.Text = "BLOXY KARTZ"
title.TextColor3 = Color3.fromRGB(245, 248, 252)
title.TextScaled = true
title.TextStrokeTransparency = 0.8
title.Parent = background

local subtitle = Instance.new("TextLabel")
subtitle.Name = "LoadingStatus"
subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
subtitle.Position = UDim2.fromScale(0.5, 0.78)
subtitle.Size = UDim2.new(0.8, 0, 0, 28)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.GothamMedium
subtitle.Text = "PREPARANDO LA CARRERA..."
subtitle.TextColor3 = Color3.fromRGB(160, 184, 198)
subtitle.TextScaled = true
subtitle.Parent = background

task.spawn(function()
    pcall(function()
        ContentProvider:PreloadAsync({icon})
    end)
end)

if not game:IsLoaded() then
    game.Loaded:Wait()
end

task.wait(0.65)
local fadeInfo = TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
for _, item in ipairs(gui:GetDescendants()) do
    if item:IsA("GuiObject") then
        local goal = {}
        if item:IsA("TextLabel") then
            goal.TextTransparency = 1
            goal.BackgroundTransparency = 1
        elseif item:IsA("ImageLabel") then
            goal.ImageTransparency = 1
            goal.BackgroundTransparency = 1
        elseif item:IsA("Frame") then
            goal.BackgroundTransparency = 1
        end
        if next(goal) then
            TweenService:Create(item, fadeInfo, goal):Play()
        end
    end
end
task.wait(0.75)
gui:Destroy()
