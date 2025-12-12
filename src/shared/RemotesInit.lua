--!strict
--[=[
	Initializes and manages RemoteEvents for the game.
	@module RemotesInit
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

-- Create a container for our remotes if it doesn't exist
local remotesFolder = ReplicatedStorage:FindFirstChild("MagicChessRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "MagicChessRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

-- Function to create a remote event
local function createRemote(name: string)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

-- Define and create all remotes
Remotes.MoveAttempt = createRemote("MoveAttempt")
Remotes.MagicMoveAttempt = createRemote("MagicMoveAttempt")
Remotes.MagicMoveRejected = createRemote("MagicMoveRejected")
Remotes.ResignAttempt = createRemote("ResignAttempt")
Remotes.MatchStateUpdate = createRemote("MatchStateUpdate")
Remotes.MatchEnd = createRemote("MatchEnd")
Remotes.RequestQuickMatch = createRemote("RequestQuickMatch")
Remotes.RequestAIMatch = createRemote("RequestAIMatch")

-- A function to get the folder, primarily for the server to know where to find them
function Remotes.getRemotesFolder()
	return remotesFolder
end

return Remotes
