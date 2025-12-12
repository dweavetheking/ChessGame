--!strict
--[=[
	Handles playing sound effects for the game.
	@module SoundManager
]=]

local SoundService = game:GetService("SoundService")

local SoundManager = {}

-- Create a container for our sounds
local soundFolder = SoundService:FindFirstChild("MagicChessSounds")
if not soundFolder then
	soundFolder = Instance.new("Folder")
	soundFolder.Name = "MagicChessSounds"
	soundFolder.Parent = SoundService
end

local function createSound(name: string, id: string, volume: number)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = soundFolder
	return sound
end

local sounds = {
	MagicMove = createSound("MagicMove", "rbxassetid://1840124991", 1),
	Move = createSound("Move", "rbxassetid://130764124", 0.5),
	Capture = createSound("Capture", "rbxassetid://130764136", 0.8),
	Check = createSound("Check", "rbxassetid://2420998848", 0.7),
}

--[=[
	Plays the sound for a Magic Move transformation.
]=]
function SoundManager.playMagicMoveSound()
	sounds.MagicMove:Play()
end

--[=[
	Plays the sound for a normal piece move.
]=]
function SoundManager.playMoveSound()
	sounds.Move:Play()
end

--[=[
	Plays the sound for a piece capture.
]=]
function SoundManager.playCaptureSound()
	sounds.Capture:Play()
end

--[=[
	Plays the sound for a check alert.
]=]
function SoundManager.playCheckSound()
	sounds.Check:Play()
end


return SoundManager
