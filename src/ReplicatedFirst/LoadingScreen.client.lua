local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")

local LOGO_IMAGE = "rbxassetid://109317195867919"
local MINIMUM_DISPLAY_TIME = 1.25

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "BLOXYLoadingScreen"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.DisplayOrder = 10000
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(10, 14, 22)
background.BorderSizePixel = 0
background.Parent = screen

local glow = Instance.new("Frame")
glow.Name = "LogoGlow"
glow.AnchorPoint = Vector2.new(0.5, 0.5)
glow.Position = UDim2.fromScale(0.5, 0.43)
glow.Size = UDim2.fromOffset(360, 220)
glow.BackgroundColor3 = Color3.fromRGB(32, 75, 112)
glow.BackgroundTransparency = 0.78
glow.BorderSizePixel = 0
glow.Parent = background
local glowCorner = Instance.new("UICorner")
glowCorner.CornerRadius = UDim.new(1, 0)
glowCorner.Parent = glow

local logo = Instance.new("ImageLabel")
logo.Name = "GameLogo"
logo.AnchorPoint = Vector2.new(0.5, 0.5)
logo.Position = UDim2.fromScale(0.5, 0.43)
logo.Size = UDim2.new(0.68, 0, 0.34, 0)
logo.BackgroundTransparency = 1
logo.Image = LOGO_IMAGE
logo.ScaleType = Enum.ScaleType.Fit
logo.Parent = background

local loadingText = Instance.new("TextLabel")
loadingText.Name = "LoadingText"
loadingText.AnchorPoint = Vector2.new(0.5, 0.5)
loadingText.Position = UDim2.fromScale(0.5, 0.72)
loadingText.Size = UDim2.new(0.8, 0, 0, 32)
loadingText.BackgroundTransparency = 1
loadingText.Font = Enum.Font.GothamMedium
loadingText.Text = "CARGANDO..."
loadingText.TextColor3 = Color3.fromRGB(225, 232, 240)
loadingText.TextSize = 18
loadingText.Parent = background

local track = Instance.new("Frame")
track.Name = "ProgressTrack"
track.AnchorPoint = Vector2.new(0.5, 0.5)
track.Position = UDim2.fromScale(0.5, 0.78)
track.Size = UDim2.new(0.34, 0, 0, 4)
track.BackgroundColor3 = Color3.fromRGB(48, 57, 70)
track.BorderSizePixel = 0
track.Parent = background
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = track

local fill = Instance.new("Frame")
fill.Name = "ProgressFill"
fill.Size = UDim2.fromScale(0.08, 1)
fill.BackgroundColor3 = Color3.fromRGB(255, 190, 55)
fill.BorderSizePixel = 0
fill.Parent = track
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill

screen.Parent = playerGui
ReplicatedFirst:RemoveDefaultLoadingScreen()

task.spawn(function()
    while screen.Parent do
        local tween = TweenService:Create(fill, TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            Size = UDim2.fromScale(0.92, 1)
        })
        tween:Play()
        tween.Completed:Wait()
        if not screen.Parent then break end
        fill.Size = UDim2.fromScale(0.08, 1)
    end
end)

local startedAt = os.clock()
pcall(function()
    ContentProvider:PreloadAsync({ logo })
end)
if not game:IsLoaded() then
    game.Loaded:Wait()
end
local remaining = MINIMUM_DISPLAY_TIME - (os.clock() - startedAt)
if remaining > 0 then
    task.wait(remaining)
end

local fade = TweenService:Create(background, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    BackgroundTransparency = 1
})
for _, descendant in ipairs(screen:GetDescendants()) do
    if descendant:IsA("GuiObject") then
        local goal = {}
        if descendant:IsA("TextLabel") then
            goal.TextTransparency = 1
        elseif descendant:IsA("ImageLabel") then
            goal.ImageTransparency = 1
        elseif descendant:IsA("Frame") then
            goal.BackgroundTransparency = 1
        end
        if next(goal) then
            TweenService:Create(descendant, TweenInfo.new(0.45), goal):Play()
        end
    end
end
fade:Play()
fade.Completed:Wait()
screen:Destroy()
