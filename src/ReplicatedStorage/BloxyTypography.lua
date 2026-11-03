-- Centralized typography roles for the BLOXY KARTS interface.
-- Font assets are installed from the Roblox Creator Store.
-- Londrina Solid is used for display/headline text.
-- Rajdhani is used for readable HUD text and supporting information.

local Fonts = {
	Bold = Font.fromId(113086061264643, Enum.FontWeight.Regular, Enum.FontStyle.Normal),
	Light = Font.fromId(12187375422, Enum.FontWeight.Light, Enum.FontStyle.Normal),
}

local Typography = {}

function Typography.getFont(role)
	return Fonts[role] or Fonts.Light
end

return Typography
