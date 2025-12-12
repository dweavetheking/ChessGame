--!strict
--[=[
	Handles matchmaking and high-level game flow.
	@module GameServer
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local Shared = ServerScriptService.src.shared
local Remotes = require(Shared.RemotesInit)
local MatchManager = require(script.Parent.MatchManager)

local GameServer = {}

local matchQueue = {}
local activeMatches = {} -- Maps Player -> Match

--[=[
	Adds a player to the matchmaking queue and attempts to create a match.
]=]
local function queuePlayer(player: Player)
	-- Avoid adding the same player twice
	for _, p in ipairs(matchQueue) do
		if p == player then
			return
		end
	end
	table.insert(matchQueue, player)
	print(`Player {player.Name} added to the queue.`)

	-- If we have enough players, create a match
	if #matchQueue >= 2 then
		local playerWhite = table.remove(matchQueue, 1)
		local playerBlack = table.remove(matchQueue, 1)

		if not playerWhite or not playerBlack then
			return
		end

		local newMatch = MatchManager.createMatch(playerWhite, playerBlack)
		activeMatches[playerWhite] = newMatch
		activeMatches[playerBlack] = newMatch

		-- Send the initial state
		newMatch:broadcastUpdate()
	end
end

--[=[
	Handles a player's move attempt by routing it to the correct match.
]=]
local function onMoveAttempt(player: Player, fromSquare: { x: number, y: number }, toSquare: { x: number, y: number })
	local match = activeMatches[player]
	if match then
		match:handlePlayerMove(player, fromSquare, toSquare)
	else
		warn(`Player {player.Name} tried to move but is not in a match.`)
	end
end

--[=[
	Handles a player's magic move attempt.
]=]
local function onMagicMoveAttempt(player: Player, actionType: string, targetSquare: any, newType: string)
	local match = activeMatches[player]
	if match then
		match:handleMagicMove(player, actionType, targetSquare, newType)
	else
		warn(`Player {player.Name} tried a magic move but is not in a match.`)
	end
end

local function onResignAttempt(player: Player)
	local match = activeMatches[player]
	if match then
		match:handleResignation(player)
	else
		warn(`Player {player.Name} tried to resign but is not in a match.`)
	end
end

--[=[
	Removes a player from any active match or queue when they leave.
]=]
local function onPlayerRemoving(player: Player)
	-- Remove from queue
	for i, p in ipairs(matchQueue) do
		if p == player then
			table.remove(matchQueue, i)
			print(`Player {player.Name} removed from queue.`)
			break
		end
	end

	-- End any active match
	local match = activeMatches[player]
	if match then
		-- For MVP, the other player wins
		local winner = (match.players.White == player) and match.players.Black or match.players.White
		match.status = `{winner.Name}Won_Disconnect`
		print(`Player {player.Name} disconnected. Match ended.`)
		match:broadcastUpdate() -- Notify the other player

		-- Clean up
		activeMatches[match.players.White] = nil
		activeMatches[match.players.Black] = nil
	end
end


-- Initialize the server
function GameServer.start()
	print("GameServer started.")
	Remotes.RequestQuickMatch.OnServerEvent:Connect(queuePlayer)
	Remotes.MoveAttempt.OnServerEvent:Connect(onMoveAttempt)
	Remotes.MagicMoveAttempt.OnServerEvent:Connect(onMagicMoveAttempt)
	Remotes.ResignAttempt.OnServerEvent:Connect(onResignAttempt)

	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

GameServer.start()

return GameServer
