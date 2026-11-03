-- Built-in Roblox fonts keep the HUD readable even if uploaded font assets are unavailable.
local Fonts = {
	Bold = Font.fromEnum(Enum.Font.GothamBold),
	Light = Font.fromEnum(Enum.Font.GothamMedium),
	-- Highway: alternativa nativa de Roblox al estilo Impact (gruesa y condensada).
	Title = Font.fromEnum(Enum.Font.Highway),
}

local Typography = {}

function Typography.getFont(role)
	return Fonts[role] or Fonts.Light
end

return Typography
