--!strict
--[=[
	Handles AI opponent logic.
	@module AIPlayer
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local Shared = ServerScriptService.src.shared

local ChessEngine = require(Shared.ChessEngine)
local MagicMoveSystem = require(Shared.MagicMoveSystem)
local GameTypes = require(Shared.GameTypes)

local AIPlayer = {}

local PIECE_VALUES = {
	[GameTypes.PieceTypes.Pawn] = 1,
	[GameTypes.PieceTypes.Knight] = 3,
	[GameTypes.PieceTypes.Bishop] = 3,
	[GameTypes.PieceTypes.Rook] = 5,
	[GameTypes.PieceTypes.Queen] = 9,
	[GameTypes.PieceTypes.King] = 100, -- High value to avoid checkmate
}

--[=[
	Evaluates the board state from the perspective of the given color.
	Higher score is better.
]=]
local function evaluateBoard(boardState: ChessEngine.BoardState, color: string): number
	local score = 0
	for y = 1, 8 do
		for x = 1, 8 do
			local piece = boardState[y][x]
			if piece then
				local value = PIECE_VALUES[piece.pieceType] or 0
				if piece.color == color then
					score += value
				else
					score -= value
				end
			end
		end
	end
	return score
end

--[=[
	Gets the best move for the AI based on the target Elo.
	@param boardState
	@param aiColor
	@param targetElo
	@return table? -- { from: {x, y}, to: {x, y} } or { magic: true, ... }
]=]
function AIPlayer.getBestMove(
	boardState: ChessEngine.BoardState,
	aiColor: string,
	targetElo: number,
	magicState: table,
	lastMove: table?,
	previousBoardState: ChessEngine.BoardState?
): table?
	local legalMoves = {}

	-- Generate all legal moves
	for y = 1, 8 do
		for x = 1, 8 do
			local piece = boardState[y][x]
			if piece and piece.color == aiColor then
				for toY = 1, 8 do
					for toX = 1, 8 do
						if ChessEngine.isMoveLegal(boardState, { x = x, y = y }, { x = toX, y = toY }, aiColor) then
							table.insert(legalMoves, { from = { x = x, y = y }, to = { x = toX, y = toY } })
						end
					end
				end
			end
		end
	end

	if #legalMoves == 0 then
		return nil -- No legal moves
	end

	-- Score all legal moves
	local scoredMoves = {}
	for _, move in ipairs(legalMoves) do
		local tempBoard, _, _ = ChessEngine.applyMove(boardState, move.from, move.to)
		local score = evaluateBoard(tempBoard, aiColor)
		table.insert(scoredMoves, { move = move, score = score })
	end

	-- Sort moves by score (descending)
	table.sort(scoredMoves, function(a, b)
		return a.score > b.score
	end)

	-- Elo-based move selection
	local bestRegularMove = scoredMoves[1]
	local bestMagicMove = nil

	-- Magic Move Evaluation
	local canUseMagic = (aiColor == GameTypes.Colors.White and not magicState.whiteUsed) or (aiColor == GameTypes.Colors.Black and not magicState.blackUsed)
	if canUseMagic and targetElo > 800 then -- Lower Elo AI won't use magic
		local scoredMagicMoves = {}

		-- Evaluate upgrades
		local upgradeTargets = MagicMoveSystem.getValidUpgradeTargets(boardState, aiColor)
		for _, square in ipairs(upgradeTargets) do
			local piece = boardState[square.y][square.x]
			local allowedTypes = MagicMoveSystem.getAllowedUpgradeTypes(piece.pieceType)
			for _, newType in ipairs(allowedTypes) do
				local success, _, tempBoard = MagicMoveSystem.applyMagicMove(boardState, "Upgrade", square, newType, aiColor, lastMove, previousBoardState)
				if success then
					table.insert(scoredMagicMoves, {
						move = { magic = true, actionType = "Upgrade", targetSquare = square, newType = newType },
						score = evaluateBoard(tempBoard, aiColor),
					})
				end
			end
		end

		-- Evaluate downgrades
		local downgradeTargets = MagicMoveSystem.getValidDowngradeTargets(boardState, aiColor)
		for _, square in ipairs(downgradeTargets) do
			local piece = boardState[square.y][square.x]
			local allowedTypes = MagicMoveSystem.getAllowedDowngradeTypes(piece.pieceType)
			for _, newType in ipairs(allowedTypes) do
				local success, _, tempBoard = MagicMoveSystem.applyMagicMove(boardState, "Downgrade", square, newType, aiColor, lastMove, previousBoardState)
				if success then
					table.insert(scoredMagicMoves, {
						move = { magic = true, actionType = "Downgrade", targetSquare = square, newType = newType },
						score = evaluateBoard(tempBoard, aiColor),
					})
				end
			end
		end

		if #scoredMagicMoves > 0 then
			table.sort(scoredMagicMoves, function(a, b)
				return a.score > b.score
			end)
			bestMagicMove = scoredMagicMoves[1]
		end
	end

	-- Compare best regular move with best magic move
	if bestMagicMove and bestMagicMove.score > bestRegularMove.score + 1 then -- Require significant advantage
		if targetElo > 1200 or math.random() < 0.5 then -- Higher Elo AI are more likely to use it
			return bestMagicMove.move
		end
	end

	if targetElo <= 800 then
		local half = math.max(1, math.floor(#scoredMoves * 0.5))
		return scoredMoves[math.random(1, half)].move
	elseif targetElo <= 1200 then
		local topN = math.min(3, #scoredMoves)
		return scoredMoves[math.random(1, topN)].move
	else
		return bestRegularMove.move
	end
end

return AIPlayer
