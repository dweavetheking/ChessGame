--!strict
--[=[
	Manages Elo ratings for players and AI.
	@module RatingSystem
]=]

local ProfileStore = require(script.Parent.ProfileStore)

local RatingSystem = {}

local K_FACTOR = 32

RatingSystem.AIProfiles = {
	{ Name = "Beginner", Elo = 800 },
	{ Name = "Intermediate", Elo = 1200 },
	{ Name = "Advanced", Elo = 1600 },
	{ Name = "Expert", Elo = 2000 },
}

--[=[
	Gets a player's current Elo rating.
	@param player
	@return number
]=]
function RatingSystem.getPlayerRating(player: Player): number
	local profile = ProfileStore.getProfile(player)
	return profile and profile.elo or 1200
end

--[=[
	Sets a player's Elo rating.
	@param player
	@param rating
]=]
function RatingSystem.setPlayerRating(player: Player, rating: number)
	local profile = ProfileStore.getProfile(player)
	if profile then
		profile.elo = rating
		print(`Rating for {player.Name} set to {rating}`)
	end
end

--[=[
	Calculates the expected score for a player against an opponent.
]=]
local function getExpectedScore(playerRating: number, opponentRating: number): number
	return 1 / (1 + 10 ^ ((opponentRating - playerRating) / 400))
end

--[=[
	Updates a player's rating based on a match result.
	@param player
	@param opponentRating
	@param result 1 for win, 0.5 for draw, 0 for loss
	@return number -- The new rating
]=]
function RatingSystem.updateRating(player: Player, opponentRating: number, result: number): number
	local playerRating = RatingSystem.getPlayerRating(player)
	local expectedScore = getExpectedScore(playerRating, opponentRating)
	local newRating = playerRating + K_FACTOR * (result - expectedScore)
	newRating = math.floor(newRating + 0.5) -- Round to nearest integer

	RatingSystem.setPlayerRating(player, newRating)
	return newRating
end

--[=[
	Selects an AI profile based on a player's rating.
	@param playerRating
	@return table -- The selected AI profile
]=]
function RatingSystem.getAIOpponent(playerRating: number): table
	-- Find the AI with the closest Elo rating
	local bestMatch = RatingSystem.AIProfiles[1]
	local smallestDiff = math.abs(playerRating - bestMatch.Elo)

	for i = 2, #RatingSystem.AIProfiles do
		local profile = RatingSystem.AIProfiles[i]
		local diff = math.abs(playerRating - profile.Elo)
		if diff < smallestDiff then
			smallestDiff = diff
			bestMatch = profile
		end
	end

	return bestMatch
end


return RatingSystem
