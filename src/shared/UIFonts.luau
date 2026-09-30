local FAMILY = "rbxasset://fonts/families/Nunito.json"

return table.freeze({
	Regular = Font.new(FAMILY, Enum.FontWeight.Regular),
	Bold = Font.new(FAMILY, Enum.FontWeight.Bold),
	ExtraBold = Font.new(FAMILY, Enum.FontWeight.ExtraBold),
})
