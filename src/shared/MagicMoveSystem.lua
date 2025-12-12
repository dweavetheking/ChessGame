--!strict
--[=[
	Enforces Magic Move rules and transformation logic.
	@module MagicMoveSystem
]=]

local GameTypes = require(script.Parent.GameTypes)
local ChessEngine = require(script.Parent.ChessEngine)

local MagicMoveSystem = {}

-- Define upgrade and downgrade paths
local UPGRADE_PATHS = {
	[GameTypes.PieceTypes.Pawn] = { GameTypes.PieceTypes.Knight, GameTypes.PieceTypes.Bishop, GameTypes.PieceTypes.Rook },
	[GameTypes.PieceTypes.Knight] = { GameTypes.PieceTypes.Bishop, GameTypes.PieceTypes.Rook },
	[GameTypes.PieceTypes.Bishop] = { GameTypes.PieceTypes.Rook },
}

local DOWNGRADE_PATHS = {
	[GameTypes.PieceTypes.Rook] = { GameTypes.PieceTypes.Bishop, GameTypes.PieceTypes.Knight },
	[GameTypes.PieceTypes.Bishop] = { GameTypes.PieceTypes.Knight, GameTypes.PieceTypes.Pawn },
	[GameTypes.PieceTypes.Knight] = { GameTypes.PieceTypes.Pawn },
}

local UNTOUCHABLE_PIECES = {
	[GameTypes.PieceTypes.King] = true,
	[GameTypes.PieceTypes.Queen] = true,
}

--[=[
	Gets the allowed upgrade types for a given piece type.
	@param pieceType string
	@return {string}
]=]
function MagicMoveSystem.getAllowedUpgradeTypes(pieceType: string)
	return UPGRADE_PATHS[pieceType] or {}
end

--[=[
	Gets the allowed downgrade types for a given piece type.
	@param pieceType string
	@return {string}
]=]
function MagicMoveSystem.getAllowedDowngradeTypes(pieceType: string)
	return DOWNGRADE_PATHS[pieceType] or {}
end


--[=[
	Gets a list of valid squares for a player to upgrade.
	@param boardState
	@param color
	@return {{x: number, y: number}}
]=]
function MagicMoveSystem.getValidUpgradeTargets(boardState: ChessEngine.BoardState, color: string)
	local targets = {}
	for y = 1, 8 do
		for x = 1, 8 do
			local piece = boardState[y][x]
			if piece and piece.color == color and not UNTOUCHABLE_PIECES[piece.pieceType] and UPGRADE_PATHS[piece.pieceType] then
				table.insert(targets, { x = x, y = y })
			end
		end
	end
	return targets
end

--[=[
	Gets a list of valid squares for a player to downgrade.
	@param boardState
	@param color The color of the player PERFORMING the downgrade.
	@return {{x: number, y: number}}
]=]
function MagicMoveSystem.getValidDowngradeTargets(boardState: ChessEngine.BoardState, color: string)
	local opponentColor = (color == GameTypes.Colors.White) and GameTypes.Colors.Black or GameTypes.Colors.White
	local targets = {}
	for y = 1, 8 do
		for x = 1, 8 do
			local piece = boardState[y][x]
			if piece and piece.color == opponentColor and not UNTOUCHABLE_PIECES[piece.pieceType] and DOWNGRADE_PATHS[piece.pieceType] then
				table.insert(targets, { x = x, y = y })
			end
		end
	end
	return targets
end


--[=[
	Applies a magic move transformation to the board.
	This is the core server-side validation function.
	@param boardState
	@param actionType "Upgrade" or "Downgrade"
	@param square The target square of the piece to change.
	@param newType The new piece type.
	@param color The color of the player MAKING the move.
	@param lastMove The last move made in the game, for time-reversal checks.
	@return boolean, string?, BoardState? -- success, reason, newBoardState
]=]
function MagicMoveSystem.applyMagicMove(
	boardState: ChessEngine.BoardState,
	actionType: string,
	square: { x: number, y: number },
	newType: string,
	color: string,
	lastMove: table?,
	previousBoardState: ChessEngine.BoardState?
)
	local pieceToChange = boardState[square.y][square.x]
	if not pieceToChange then
		return false, "No piece on target square."
	end

	-- 1. Validate the requested transformation
	local allowedTypes = {}
	if actionType == "Upgrade" and pieceToChange.color == color then
		allowedTypes = MagicMoveSystem.getAllowedUpgradeTypes(pieceToChange.pieceType)
	elseif actionType == "Downgrade" and pieceToChange.color ~= color then
		allowedTypes = MagicMoveSystem.getAllowedDowngradeTypes(pieceToChange.pieceType)
	else
		return false, "Invalid action or target piece color."
	end

	local isTypeAllowed = false
	for _, t in ipairs(allowedTypes) do
		if t == newType then
			isTypeAllowed = true
			break
		end
	end
	if not isTypeAllowed then
		return false, `Cannot change {pieceToChange.pieceType} to {newType}.`
	end

	-- 2. Create a temporary board with the transformation
	local tempBoard = ChessEngine.cloneBoard(boardState)
	local changedPiece = tempBoard[square.y][square.x]
	changedPiece.pieceType = newType

	-- 3. Check for immediate checkmate
	local opponentColor = (color == GameTypes.Colors.White) and GameTypes.Colors.Black or GameTypes.Colors.White
	if ChessEngine.isCheckmate(tempBoard, opponentColor) then
		return false, "Magic Move cannot result in immediate checkmate."
	end

	-- 4. Handle Soft Time Reversal
	if
		actionType == "Downgrade"
		and lastMove
		and lastMove.pieceId == pieceToChange.id
		and (lastMove.toSquare.x == square.x and lastMove.toSquare.y == square.y)
		and previousBoardState
	then
		-- The downgraded piece was the one that just moved.
		-- Check if its new, downgraded type could have made that move.
		local tempPiece = table.clone(changedPiece)
		tempPiece.pieceType = newType
		local boardWithoutLastMove = ChessEngine.cloneBoard(previousBoardState)
		boardWithoutLastMove[lastMove.fromSquare.y][lastMove.fromSquare.x] = tempPiece

		local couldHaveMadeLastMove, _ = ChessEngine.isMoveLegal(
			boardWithoutLastMove,
			lastMove.fromSquare,
			lastMove.toSquare,
			changedPiece.color
		)

		if not couldHaveMadeLastMove then
			-- It could NOT have made that move. Revert it.
			print("Soft time reversal triggered!")
			tempBoard[lastMove.fromSquare.y][lastMove.fromSquare.x] = tempBoard[square.y][square.x]
			tempBoard[square.y][square.x] = nil -- Clear the original 'to' square
		end
	end

	return true, nil, tempBoard
end


return MagicMoveSystem
