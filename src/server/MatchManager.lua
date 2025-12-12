--!strict
--[=[
	Manages a single match instance.
	@module MatchManager
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ServerScriptService.src.shared
local ChessEngine = require(Shared.ChessEngine)
local GameTypes = require(Shared.GameTypes)
local Remotes = require(Shared.RemotesInit)
local MagicMoveSystem = require(Shared.MagicMoveSystem)
local AIPlayer = require(script.Parent.AIPlayer)
local RatingSystem = require(script.Parent.RatingSystem)

local MatchManager = {}
MatchManager.__index = MatchManager

export type Match = {
	id: string,
	players: {
		White: Player,
		Black: Player,
	},
	playerIds: { [string]: string }, -- Maps Player.UserId to Color
	boardState: ChessEngine.BoardState,
	activeColor: string,
	magicState: any, -- Placeholder for MagicMoveSystem state
	moveHistory: {},
	status: string,
}

--[=[
	Creates a new match instance.
	@param playerWhite
	@param playerBlack
	@return Match
]=]
function MatchManager.createMatch(playerWhite: Player, playerBlack: Player): Match
	local newMatch = setmetatable({
		id = tostring(os.time()), -- Simple unique ID for now
		players = {
			White = playerWhite,
			Black = playerBlack,
		},
		playerIds = {
			[tostring(playerWhite.UserId)] = GameTypes.Colors.White,
			[tostring(playerBlack.UserId)] = GameTypes.Colors.Black,
		},
		boardState = ChessEngine.newGame(),
		previousBoardState = nil,
		activeColor = GameTypes.Colors.White,
		magicState = { whiteUsed = false, blackUsed = false },
		moveHistory = {},
		status = "InProgress",
	}, MatchManager)

	newMatch.isAI_Match = playerWhite.__isAI or playerBlack.__isAI

	print(`Match created between {playerWhite.Name} (White) and {playerBlack.Name} (Black)`)

	-- If AI is white, it needs to make the first move
	if newMatch.players[newMatch.activeColor].__isAI then
		newMatch:_processAITurn()
	end

	return newMatch
end

function MatchManager:_processAITurn()
	task.wait(1) -- Simulate thinking time

	local aiPlayer = self.players[self.activeColor]
	if not aiPlayer or not aiPlayer.__isAI then
		return
	end

	local move = AIPlayer.getBestMove(self.boardState, self.activeColor, aiPlayer.Elo, self.magicState, self.lastMove, self.previousBoardState)
	if move then
		if move.magic then
			-- AI wants to use a magic move
			self:handleMagicMove(aiPlayer, move.actionType, move.targetSquare, move.newType)
		else
			-- AI wants to make a normal move
			self:handlePlayerMove(aiPlayer, move.from, move.to)
		end
	end
end


--[=[
	Generates a serializable snapshot of the match state for clients.
	@param match
	@return table
]=]
function MatchManager:getSnapshot()
	return {
		boardState = self.boardState,
		activeColor = self.activeColor,
		magicState = self.magicState,
		status = self.status,
		isCheck = ChessEngine.isCheck(self.boardState, self.activeColor),
		players = {
			White = self.players.White.Name,
			Black = self.players.Black.Name,
		},
		ratings = {
			White = self.players.White.Elo or RatingSystem.getPlayerRating(self.players.White),
			Black = self.players.Black.Elo or RatingSystem.getPlayerRating(self.players.Black),
		},
		aiProfile = self.isAI_Match and (self.players.White.__isAI and self.players.White.Name or self.players.Black.Name),
		lastMove = self.lastMove,
	}
end

--[=[
	Broadcasts the latest match state to both players.
	@param match
]=]
function MatchManager:broadcastUpdate()
	local snapshot = self:getSnapshot()
	Remotes.MatchStateUpdate:FireClient(self.players.White, snapshot)
	Remotes.MatchStateUpdate:FireClient(self.players.Black, snapshot)
	print("Broadcasting update for match " .. self.id)
end

--[=[
	Handles a player's move attempt.
	@param match
	@param player
	@param fromSquare
	@param toSquare
	@return boolean, string?
]=]
function MatchManager:handlePlayerMove(player: Player, fromSquare: { x: number, y: number }, toSquare: { x: number, y: number })
	local playerColor = self.playerIds[tostring(player.UserId)]
	if not playerColor or playerColor ~= self.activeColor then
		return false, "Not your turn"
	end

	local pieceToMove = self.boardState[fromSquare.y][fromSquare.x]
	if not pieceToMove then
		return false, "No piece at source square"
	end

	local isLegal, reason = ChessEngine.isMoveLegal(self.boardState, fromSquare, toSquare, self.activeColor)
	if not isLegal then
		return false, reason or "Illegal move"
	end

	-- Store the state *before* the move
	self.previousBoardState = ChessEngine.cloneBoard(self.boardState)

	-- Apply the move
	local newBoard, movedPiece, capturedPiece = ChessEngine.applyMove(self.boardState, fromSquare, toSquare)
	self.boardState = newBoard

	-- Record last move for magic move system
	self.lastMove = {
		pieceId = movedPiece.id,
		fromSquare = fromSquare,
		toSquare = toSquare,
		capturedPiece = capturedPiece,
	}

	-- Swap active color
	self.activeColor = (self.activeColor == GameTypes.Colors.White) and GameTypes.Colors.Black or GameTypes.Colors.White

	-- Check for game end conditions
	if ChessEngine.isCheckmate(self.boardState, self.activeColor) then
		self.status = `{playerColor}Won`
		print(`Checkmate! {playerColor} wins.`)
		self:_updateElo(playerColor)
	elseif ChessEngine.isStalemate(self.boardState, self.activeColor) then
		self.status = "Draw"
		print("Stalemate!")
		self:_updateElo(nil) -- nil winner means draw
	end

	table.insert(self.moveHistory, { from = fromSquare, to = toSquare })
	self:broadcastUpdate()

	-- If the new active player is an AI, process their turn
	if self.players[self.activeColor].__isAI then
		self:_processAITurn()
	end

	return true
end


function MatchManager:handleMagicMove(
	player: Player,
	actionType: string,
	targetSquare: { x: number, y: number },
	newType: string
)
	local playerColor = self.playerIds[tostring(player.UserId)]
	if not playerColor or playerColor ~= self.activeColor then
		return false, "Not your turn"
	end

	-- Check if magic move has been used
	if (playerColor == GameTypes.Colors.White and self.magicState.whiteUsed) or (playerColor == GameTypes.Colors.Black and self.magicState.blackUsed) then
		return false, "Magic Move already used"
	end

	local success, reason, newBoard = MagicMoveSystem.applyMagicMove(
		self.boardState,
		actionType,
		targetSquare,
		newType,
		playerColor,
		self.lastMove,
		self.previousBoardState
	)

	if not success then
		-- Fire a remote to tell the client it failed
		Remotes.MagicMoveRejected:FireClient(player, reason)
		return false, reason
	end

	-- Mark as used
	if playerColor == GameTypes.Colors.White then
		self.magicState.whiteUsed = true
	else
		self.magicState.blackUsed = true
	end

	self.boardState = newBoard

	-- Swap active color
	self.activeColor = (self.activeColor == GameTypes.Colors.White) and GameTypes.Colors.Black or GameTypes.Colors.White

	-- Check for game end conditions after the magic move
	if ChessEngine.isCheckmate(self.boardState, self.activeColor) then
		self.status = `{playerColor}Won`
		self:_updateElo(playerColor)
	elseif ChessEngine.isStalemate(self.boardState, self.activeColor) then
		self.status = "Draw"
		self:_updateElo(nil)
	end

	self:broadcastUpdate()

	-- If the new active player is an AI, process their turn
	if self.players[self.activeColor].__isAI then
		self:_processAITurn()
	end

	return true
end

function MatchManager:handleResignation(player: Player)
	if self.status ~= "InProgress" then
		return -- Game is already over
	end

	local playerColor = self.playerIds[tostring(player.UserId)]
	if not playerColor then
		return
	end

	local winnerColor = (playerColor == GameTypes.Colors.White) and GameTypes.Colors.Black or GameTypes.Colors.White
	self.status = `{winnerColor}Won_Resign`
	print(`{playerColor} resigned. {winnerColor} wins.`)
	self:_updateElo(winnerColor)

	self:broadcastUpdate()
	-- Consider firing MatchEnd here as well
end

function MatchManager:_updateElo(winnerColor: string?)
	if not self.isAI_Match then
		return
	end

	local humanPlayer, aiPlayer = nil, nil
	if self.players.White.__isAI then
		aiPlayer = self.players.White
		humanPlayer = self.players.Black
	else
		aiPlayer = self.players.Black
		humanPlayer = self.players.White
	end

	local humanColor = self.playerIds[tostring(humanPlayer.UserId)]
	local result
	if not winnerColor then
		result = 0.5 -- Draw
	elseif winnerColor == humanColor then
		result = 1 -- Human won
	else
		result = 0 -- AI won
	end

	RatingSystem.updateRating(humanPlayer, aiPlayer.Elo, result)
end

return MatchManager
