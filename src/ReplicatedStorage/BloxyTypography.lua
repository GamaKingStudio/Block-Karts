-- Centralized typography roles for the BLOXY KARTS interface.
-- Temporary Roblox-native fallback until the BLOXY font family is published
-- as a Roblox font asset and its asset ID is available.
local FontFamily = "rbxasset://fonts/families/GothamSSm.json"

local Fonts = {
	Bold = Font.new(FontFamily, Enum.FontWeight.Bold, Enum.FontStyle.Normal),
	Light = Font.new(FontFamily, Enum.FontWeight.Light, Enum.FontStyle.Normal),
}

local Typography = {}

function Typography.getFont(role)
	return Fonts[role] or Fonts.Light
end

return Typography
