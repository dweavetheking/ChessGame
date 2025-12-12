--!strict
--[=[
	Defines ranked tiers and provides helper functions.
	@module RankConfig
]=]

local RankConfig = {}

RankConfig.Tiers = {
	{ Id = "Bronze", Name = "Bronze", Min = 0, Max = 999 },
	{ Id = "Silver", Name = "Silver", Min = 1000, Max = 1199 },
	{ Id = "Gold", Name = "Gold", Min = 1200, Max = 1399 },
	{ Id = "Platinum", Name = "Platinum", Min = 1400, Max = 1599 },
	{ Id = "Diamond", Name = "Diamond", Min = 1600, Max = 1899 },
	{ Id = "Mythic", Name = "Mythic", Min = 1900, Max = 9999 },
}

--[=[
	Gets the tier for a given Elo rating.
	@param rating
	@return table? -- The tier data
]=]
function RankConfig.getTierForRating(rating: number): table?
	for _, tier in ipairs(RankConfig.Tiers) do
		if rating >= tier.Min and rating <= tier.Max then
			return tier
		end
	end
	return nil
end

return RankConfig
