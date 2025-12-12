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

	local isLegal, reason = ChessEngine.isMoveLegal(self.boardState, fromSquare, toSquare, self.activeColor)
	if not isLegal then
		return false, reason or "Illegal move"
	end

	-- Apply the move
	local newBoard, _, _ = ChessEngine.applyMove(self.boardState, fromSquare, toSquare)
	self.boardState = newBoard

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

-- Placeholder for magic move
function MatchManager:handleMagicMove(...)
	-- To be implemented
	warn("handleMagicMove not implemented yet")
	return false, "Not implemented"
end

return MatchManager
