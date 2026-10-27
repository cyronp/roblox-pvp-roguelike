-- Shared visual tokens keep the combat HUD and upgrade cards in the same style.
local Theme = {
	-- Chunky cartoon HUD: navy panels with a thick outline and a darker drop
	-- "lip" underneath, so panels read clearly against the bright arena.
	Surface = Color3.fromRGB(38, 52, 82),
	SurfaceLight = Color3.fromRGB(58, 78, 118),
	SurfaceShadow = Color3.fromRGB(17, 23, 38),
	Outline = Color3.fromRGB(17, 23, 38),
	Track = Color3.fromRGB(22, 30, 50),
	Text = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(168, 184, 214),
	Ink = Color3.fromRGB(36, 51, 73),
	Paper = Color3.fromRGB(255, 248, 236),
	PaperShade = Color3.fromRGB(231, 216, 189),
	White = Color3.fromRGB(255, 255, 255),
	Gold = Color3.fromRGB(242, 185, 45),
	GoldLight = Color3.fromRGB(255, 225, 132),
	GoldDark = Color3.fromRGB(196, 128, 22),
	Cyan = Color3.fromRGB(45, 187, 201),
	CyanLight = Color3.fromRGB(138, 239, 229),
	Blue = Color3.fromRGB(56, 159, 236),
	BlueLight = Color3.fromRGB(146, 221, 255),
	Orange = Color3.fromRGB(247, 123, 57),
	Green = Color3.fromRGB(66, 199, 141),
	GreenLight = Color3.fromRGB(150, 240, 150),
	Purple = Color3.fromRGB(168, 121, 232),
	Danger = Color3.fromRGB(217, 74, 65),
	DangerLight = Color3.fromRGB(255, 132, 112),
	Border = 2.5,
	PanelBorder = 3,
	-- Height of the darker lip drawn below panels and buttons.
	Lip = 4,
	Radius = 10,
	PanelRadius = 14,
	SmallRadius = 6,
	BottomInset = 12,
	-- Height of the bottom-center vitals (health and XP) cluster.
	VitalsHeight = 58,
	InventoryBottom = 86,
}

Theme.GoldGradient = ColorSequence.new(Theme.GoldLight, Theme.Gold)
Theme.CyanGradient = ColorSequence.new(Theme.CyanLight, Theme.Cyan)
Theme.BlueGradient = ColorSequence.new(Theme.BlueLight, Theme.Blue)
Theme.GreenGradient = ColorSequence.new(Theme.GreenLight, Theme.Green)
Theme.DangerGradient = ColorSequence.new(Theme.DangerLight, Theme.Danger)
Theme.SurfaceGradient = ColorSequence.new(Theme.SurfaceLight, Theme.Surface)

return table.freeze(Theme)
