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
local MagicMoveSystem = require(Shared.MagicMoveSystem) -- Will be needed later

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

	print(`Match created between {playerWhite.Name} (White) and {playerBlack.Name} (Black)`)
	return newMatch
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
		-- Fire MatchEnd remote
	elseif ChessEngine.isStalemate(self.boardState, self.activeColor) then
		self.status = "Draw"
		print("Stalemate!")
		-- Fire MatchEnd remote
	end

	table.insert(self.moveHistory, { from = fromSquare, to = toSquare })
	self:broadcastUpdate()

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
	elseif ChessEngine.isStalemate(self.boardState, self.activeColor) then
		self.status = "Draw"
	end

	self:broadcastUpdate()
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

	self:broadcastUpdate()
	-- Consider firing MatchEnd here as well
end

return MatchManager
