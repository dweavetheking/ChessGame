--!strict
--[=[
	Defines shared constants and types for the game.
	@module GameTypes
]=]

local GameTypes = {}

GameTypes.Colors = {
	White = "White",
	Black = "Black",
}

GameTypes.PieceTypes = {
	Pawn = "Pawn",
	Knight = "Knight",
	Bishop = "Bishop",
	Rook = "Rook",
	Queen = "Queen",
	King = "King",
}

return GameTypes
