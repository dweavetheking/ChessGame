--!strict
--[=[
	All pure chess logic (no UI, no Roblox instances).
	@module ChessEngine
]=]

local GameTypes = require(script.Parent.GameTypes)

local ChessEngine = {}

local _pieceIdCounter = 0

-- Represents the board as an 8x8 grid (row-major).
-- boardState[y][x] where y is the row (1-8) and x is the column (1-8).
export type BoardState = {
	[number]: {
		[number]: {
			pieceType: string,
			color: string,
			id: string,
		}?,
	},
}

-- Piece Type Definition
export type Piece = {
	pieceType: string,
	color: string,
	id: string,
}

-- Private utility to create a new piece
local function newPiece(pieceType: string, color: string): Piece
	_pieceIdCounter += 1
	return {
		pieceType = pieceType,
		color = color,
		id = tostring(_pieceIdCounter),
	}
end

--[=[
	Creates a new board state with pieces in their starting positions.
	@return BoardState
]=]
function ChessEngine.newGame(): BoardState
	_pieceIdCounter = 0
	local board: BoardState = {}
	for y = 1, 8 do
		board[y] = {}
	end

	-- Place Pawns
	for x = 1, 8 do
		board[2][x] = newPiece(GameTypes.PieceTypes.Pawn, GameTypes.Colors.White)
		board[7][x] = newPiece(GameTypes.PieceTypes.Pawn, GameTypes.Colors.Black)
	end

	-- Place White Pieces
	board[1][1] = newPiece(GameTypes.PieceTypes.Rook, GameTypes.Colors.White)
	board[1][8] = newPiece(GameTypes.PieceTypes.Rook, GameTypes.Colors.White)
	board[1][2] = newPiece(GameTypes.PieceTypes.Knight, GameTypes.Colors.White)
	board[1][7] = newPiece(GameTypes.PieceTypes.Knight, GameTypes.Colors.White)
	board[1][3] = newPiece(GameTypes.PieceTypes.Bishop, GameTypes.Colors.White)
	board[1][6] = newPiece(GameTypes.PieceTypes.Bishop, GameTypes.Colors.White)
	board[1][4] = newPiece(GameTypes.PieceTypes.Queen, GameTypes.Colors.White)
	board[1][5] = newPiece(GameTypes.PieceTypes.King, GameTypes.Colors.White)

	-- Place Black Pieces
	board[8][1] = newPiece(GameTypes.PieceTypes.Rook, GameTypes.Colors.Black)
	board[8][8] = newPiece(GameTypes.PieceTypes.Rook, GameTypes.Colors.Black)
	board[8][2] = newPiece(GameTypes.PieceTypes.Knight, GameTypes.Colors.Black)
	board[8][7] = newPiece(GameTypes.PieceTypes.Knight, GameTypes.Colors.Black)
	board[8][3] = newPiece(GameTypes.PieceTypes.Bishop, GameTypes.Colors.Black)
	board[8][6] = newPiece(GameTypes.PieceTypes.Bishop, GameTypes.Colors.Black)
	board[8][4] = newPiece(GameTypes.PieceTypes.Queen, GameTypes.Colors.Black)
	board[8][5] = newPiece(GameTypes.PieceTypes.King, GameTypes.Colors.Black)

	return board
end

--[=[
	Creates a deep copy of the board state.
	@param boardState BoardState
	@return BoardState
]=]
function ChessEngine.cloneBoard(boardState: BoardState): BoardState
	local newBoard: BoardState = {}
	for y = 1, 8 do
		newBoard[y] = {}
		for x = 1, 8 do
			if boardState[y][x] then
				newBoard[y][x] = {
					pieceType = boardState[y][x].pieceType,
					color = boardState[y][x].color,
					id = boardState[y][x].id,
				}
			end
		end
	end
	return newBoard
end

--[=[
	Applies a move to the board state, assuming it's legal.
	Handles pawn promotion.
	@param boardState BoardState
	@param fromSquare {x: number, y: number}
	@param toSquare {x: number, y: number}
	@param promotionPieceType string? Optional piece type to promote a pawn to. Defaults to Queen.
	@return BoardState, Piece?, Piece? -- newBoardState, movedPiece, capturedPiece
]=]
function ChessEngine.applyMove(
	boardState: BoardState,
	fromSquare: { x: number, y: number },
	toSquare: { x: number, y: number },
	promotionPieceType: string?
)
	local newBoard = ChessEngine.cloneBoard(boardState)
	local movedPiece = newBoard[fromSquare.y][fromSquare.x]
	local capturedPiece = newBoard[toSquare.y][toSquare.x]

	if not movedPiece then
		return boardState, nil, nil
	end

	newBoard[toSquare.y][toSquare.x] = movedPiece
	newBoard[fromSquare.y][fromSquare.x] = nil

	-- Handle pawn promotion
	local isPawn = movedPiece.pieceType == GameTypes.PieceTypes.Pawn
	local promotionRank = (movedPiece.color == GameTypes.Colors.White) and 8 or 1

	if isPawn and toSquare.y == promotionRank then
		local promotedPiece = newBoard[toSquare.y][toSquare.x]
		if promotedPiece then
			promotedPiece.pieceType = promotionPieceType or GameTypes.PieceTypes.Queen
		end
	end

	return newBoard, movedPiece, capturedPiece
end

-- Private: Pawn move logic
local function _isPawnMoveLegal(boardState, fromSquare, toSquare, piece)
	local dy = toSquare.y - fromSquare.y
	local dx = toSquare.x - fromSquare.x
	local direction = (piece.color == GameTypes.Colors.White) and 1 or -1

	-- Standard 1-square move
	if dx == 0 and dy == direction and not boardState[toSquare.y][toSquare.x] then
		return true
	end

	-- Initial 2-square move
	local startRow = (piece.color == GameTypes.Colors.White) and 2 or 7
	if
		dx == 0
		and fromSquare.y == startRow
		and dy == 2 * direction
		and not boardState[fromSquare.y + direction][fromSquare.x]
		and not boardState[toSquare.y][toSquare.x]
	then
		return true
	end

	-- Capture
	if
		math.abs(dx) == 1
		and dy == direction
		and boardState[toSquare.y][toSquare.x]
		and boardState[toSquare.y][toSquare.x].color ~= piece.color
	then
		return true
	end

	return false, "Invalid pawn move"
end

-- Private: Knight move logic
local function _isKnightMoveLegal(dx, dy)
	return (math.abs(dx) == 1 and math.abs(dy) == 2) or (math.abs(dx) == 2 and math.abs(dy) == 1)
end

-- Private: Rook, Bishop, Queen line-of-sight check
local function _isLineOfSightClear(boardState, fromSquare, toSquare)
	local dx = toSquare.x - fromSquare.x
	local dy = toSquare.y - fromSquare.y
	local stepX = (dx == 0) and 0 or (dx > 0 and 1 or -1)
	local stepY = (dy == 0) and 0 or (dy > 0 and 1 or -1)
	local distance = math.max(math.abs(dx), math.abs(dy))

	for i = 1, distance - 1 do
		local checkX = fromSquare.x + i * stepX
		local checkY = fromSquare.y + i * stepY
		if boardState[checkY][checkX] then
			return false, "Path is blocked"
		end
	end

	return true
end

-- Private: Checks for pseudo-legal moves (basic movement rules, no check validation).
local function _isPseudoLegalMove(
	boardState: BoardState,
	fromSquare: { x: number, y: number },
	toSquare: { x: number, y: number }
): (boolean, string?)
	local piece = boardState[fromSquare.y][fromSquare.x]
	if not piece then
		return false, "No piece at fromSquare"
	end

	local targetPiece = boardState[toSquare.y][toSquare.x]
	if targetPiece and targetPiece.color == piece.color then
		return false, "Cannot capture friendly piece"
	end

	local dx = toSquare.x - fromSquare.x
	local dy = toSquare.y - fromSquare.y
	local legal = false
	local reason = "Invalid move for this piece"

	if piece.pieceType == GameTypes.PieceTypes.Pawn then
		legal, reason = _isPawnMoveLegal(boardState, fromSquare, toSquare, piece)
	elseif piece.pieceType == GameTypes.PieceTypes.Knight then
		legal = _isKnightMoveLegal(dx, dy)
	elseif piece.pieceType == GameTypes.PieceTypes.Bishop then
		if math.abs(dx) == math.abs(dy) then
			legal, reason = _isLineOfSightClear(boardState, fromSquare, toSquare)
		end
	elseif piece.pieceType == GameTypes.PieceTypes.Rook then
		if dx == 0 or dy == 0 then
			legal, reason = _isLineOfSightClear(boardState, fromSquare, toSquare)
		end
	elseif piece.pieceType == GameTypes.PieceTypes.Queen then
		if (dx == 0 or dy == 0) or (math.abs(dx) == math.abs(dy)) then
			legal, reason = _isLineOfSightClear(boardState, fromSquare, toSquare)
		end
	elseif piece.pieceType == GameTypes.PieceTypes.King then
		if math.abs(dx) <= 1 and math.abs(dy) <= 1 then
			legal = true
		end
	end

	if not legal then
		return false, reason
	end

	return true
end

-- Private: Checks if a square is attacked by a given color.
local function _isSquareAttacked(
	boardState: BoardState,
	square: { x: number, y: number },
	attackerColor: string
): boolean
	for y = 1, 8 do
		for x = 1, 8 do
			local piece = boardState[y][x]
			if piece and piece.color == attackerColor then
				if _isPseudoLegalMove(boardState, { x = x, y = y }, square) then
					return true
				end
			end
		end
	end
	return false
end

--[=[
	Checks if a move is legal according to standard chess rules.
	@param boardState
	@param fromSquare {x: number, y: number}
	@param toSquare {x: number, y: number}
	@param color string The color of the player making the move.
	@return boolean, string? -- isLegal, reason
]=]
function ChessEngine.isMoveLegal(
	boardState: BoardState,
	fromSquare: { x: number, y: number },
	toSquare: { x: number, y: number },
	color: string
): (boolean, string?)
	-- Basic validation
	if
		not fromSquare
		or not toSquare
		or not boardState[fromSquare.y]
		or not boardState[fromSquare.y][fromSquare.x]
		or not boardState[toSquare.y]
	then
		return false, "Invalid square"
	end

	local piece = boardState[fromSquare.y][fromSquare.x]
	if not piece or piece.color ~= color then
		return false, "Cannot move opponent's piece"
	end

	-- Check if the move follows the piece's basic movement rules
	local isPseudo, reason = _isPseudoLegalMove(boardState, fromSquare, toSquare)
	if not isPseudo then
		return false, reason
	end

	-- Check if the move would leave the player's own king in check
	local tempBoard, _, _ = ChessEngine.applyMove(boardState, fromSquare, toSquare)
	if ChessEngine.isCheck(tempBoard, color) then
		return false, "Move would result in check"
	end

	return true
end

--[=[
	Checks if a given color's King is in check.
	@param boardState
	@param color The color of the king to check.
	@return boolean
]=]
function ChessEngine.isCheck(boardState: BoardState, color: string): boolean
	local kingSquare = nil
	local opponentColor = (color == GameTypes.Colors.White) and GameTypes.Colors.Black or GameTypes.Colors.White

	-- Find the king
	for y = 1, 8 do
		for x = 1, 8 do
			local piece = boardState[y][x]
			if piece and piece.pieceType == GameTypes.PieceTypes.King and piece.color == color then
				kingSquare = { x = x, y = y }
				break
			end
		end
		if kingSquare then
			break
		end
	end

	if not kingSquare then
		-- If there's no king, they can't be in check. This can happen in test scenarios.
		return false
	end

	return _isSquareAttacked(boardState, kingSquare, opponentColor)
end

--[=[
	Checks if a given color is in checkmate.
	@param boardState
	@param color The color to check for checkmate against.
	@return boolean
]=]
function ChessEngine.isCheckmate(boardState: BoardState, color: string): boolean
	if not ChessEngine.isCheck(boardState, color) then
		return false
	end

	-- Check if any move can get the player out of check
	for y = 1, 8 do
		for x = 1, 8 do
			local piece = boardState[y][x]
			if piece and piece.color == color then
				for toY = 1, 8 do
					for toX = 1, 8 do
						if ChessEngine.isMoveLegal(boardState, { x = x, y = y }, { x = toX, y = toY }, color) then
							-- If a legal move exists, it's not checkmate
							return false
						end
					end
				end
			end
		end
	end

	return true
end

--[=[
	Checks if the game is a stalemate.
	@param boardState
	@param color The color of the player whose turn it is.
	@return boolean
]=]
function ChessEngine.isStalemate(boardState: BoardState, color: string): boolean
	if ChessEngine.isCheck(boardState, color) then
		return false
	end

	-- Check if any legal move exists for the current player
	for y = 1, 8 do
		for x = 1, 8 do
			local piece = boardState[y][x]
			if piece and piece.color == color then
				for toY = 1, 8 do
					for toX = 1, 8 do
						if ChessEngine.isMoveLegal(boardState, { x = x, y = y }, { x = toX, y = toY }, color) then
							-- A legal move exists, so it's not a stalemate
							return false
						end
					end
				end
			end
		end
	end

	return true
end


return ChessEngine
