--!strict
--[=[
	Manages visual themes for the board and pieces.
	@module ThemeManager
]=]

local ThemeManager = {}

ThemeManager.Themes = {
	Classic = {
		BoardLight = Color3.fromRGB(235, 235, 208),
		BoardDark = Color3.fromRGB(119, 149, 86),
		PieceWhite = Color3.fromRGB(255, 255, 255),
		PieceBlack = Color3.fromRGB(20, 20, 20),
		PieceMaterial = Enum.Material.Plastic,
	},
	Magic = {
		BoardLight = Color3.fromRGB(80, 70, 120),
		BoardDark = Color3.fromRGB(30, 25, 50),
		PieceWhite = Color3.fromRGB(200, 220, 255),
		PieceBlack = Color3.fromRGB(150, 130, 200),
		PieceMaterial = Enum.Material.Neon,
	},
}

--[=[
	Gets a theme by name. Defaults to Classic.
	@param name string
	@return table
]=]
function ThemeManager.getTheme(name: string?)
	return ThemeManager.Themes[name or "Classic"] or ThemeManager.Themes.Classic
end

return ThemeManager
