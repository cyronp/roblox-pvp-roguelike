-- Shared visual tokens keep the combat HUD and upgrade cards in the same style.
local Theme = {
	Ink = Color3.fromRGB(36, 51, 73),
	Paper = Color3.fromRGB(255, 248, 236),
	PaperShade = Color3.fromRGB(231, 216, 189),
	Muted = Color3.fromRGB(102, 115, 128),
	White = Color3.fromRGB(255, 255, 255),
	Gold = Color3.fromRGB(242, 185, 45),
	GoldLight = Color3.fromRGB(255, 225, 132),
	Cyan = Color3.fromRGB(45, 187, 201),
	CyanLight = Color3.fromRGB(138, 239, 229),
	Blue = Color3.fromRGB(56, 159, 236),
	BlueLight = Color3.fromRGB(146, 221, 255),
	Orange = Color3.fromRGB(247, 123, 57),
	Green = Color3.fromRGB(66, 199, 141),
	Purple = Color3.fromRGB(168, 121, 232),
	Danger = Color3.fromRGB(217, 74, 65),
	Border = 2.5,
	Radius = 10,
	SmallRadius = 6,
	BottomInset = 12,
	ProgressHeight = 30,
	InventoryBottom = 56,
}

Theme.GoldGradient = ColorSequence.new(Theme.GoldLight, Theme.Gold)
Theme.CyanGradient = ColorSequence.new(Theme.CyanLight, Theme.Cyan)
Theme.BlueGradient = ColorSequence.new(Theme.BlueLight, Theme.Blue)

return table.freeze(Theme)
