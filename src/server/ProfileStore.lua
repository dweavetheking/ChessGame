--!strict
--[=[
	Manages player data persistence using DataStoreService.
	@module ProfileStore
]=]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ProfileStore = {}

local profileStore = DataStoreService:GetDataStore("PlayerProfiles_V1")
local profileCache = {} -- [Player.UserId: string] = profileTable

local DEFAULT_PROFILE = {
	elo = 1200,
	totalGames = 0,
	totalWins = 0,
	totalLosses = 0,
	hasCompletedTutorial = false,
}

--[=[
	Loads a player's profile from the DataStore.
	@param player
	@return table -- The player's profile
]=]
function ProfileStore.loadProfile(player: Player): table
	local userId = tostring(player.UserId)
	if profileCache[userId] then
		return profileCache[userId]
	end

	local success, data = pcall(function()
		return profileStore:GetAsync(userId)
	end)

	if success and data then
		profileCache[userId] = data
		print(`Profile loaded for {player.Name}`)
		return data
	else
		-- Create a new profile if one doesn't exist
		profileCache[userId] = table.clone(DEFAULT_PROFILE)
		print(`New profile created for {player.Name}`)
		return profileCache[userId]
	end
end

--[=[
	Saves a player's profile to the DataStore.
	@param player
]=]
function ProfileStore.saveProfile(player: Player)
	local userId = tostring(player.UserId)
	local profile = profileCache[userId]
	if not profile then
		return
	end

	local success, err = pcall(function()
		profileStore:SetAsync(userId, profile)
	end)

	if success then
		print(`Profile saved for {player.Name}`)
	else
		warn(`Failed to save profile for {player.Name}: {err}`)
	end
end

--[=[
	Gets a player's cached profile.
	@param player
	@return table?
]=]
function ProfileStore.getProfile(player: Player): table?
	return profileCache[tostring(player.UserId)]
end

-- Initialize for players who might already be in the game
for _, player in ipairs(Players:GetPlayers()) do
	ProfileStore.loadProfile(player)
end

Players.PlayerAdded:Connect(ProfileStore.loadProfile)
Players.PlayerRemoving:Connect(ProfileStore.saveProfile)


return ProfileStore
