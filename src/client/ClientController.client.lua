--!strict
--[=[
	Main client-side controller. Glues UI, board, and server communication together.
	@module ClientController
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Client = script.Parent
local Shared = ReplicatedStorage.src.shared

local BoardRenderer = require(Client.BoardRenderer)
local InputHandler = require(Client.InputHandler)
local UIController = require(Client.UIController)
local Remotes = require(Shared.RemotesInit)
local GameTypes = require(Shared.GameTypes)

local ClientController = {}

local localPlayer = Players.LocalPlayer

--[=[
	Main entry point for the client.
]=]
function ClientController.start()
	print("ClientController started.")

	-- Initial setup
	local boardAnchor = CFrame.new(0, 5, 0) -- Example position, can be adjusted
	local boardRenderer = BoardRenderer.new(boardAnchor)
	local uiController = UIController.new()
	local inputHandler = InputHandler.new(boardRenderer, uiController)

	local playerColor = nil -- Determined at the start of a match

	-- Hide Roblox's default UI
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)


	-- Listen for match state updates from the server
	Remotes.MatchStateUpdate.OnClientEvent:Connect(function(snapshot: table)
		print("Received match state update.")
		boardRenderer:drawBoard(snapshot.boardState)

		-- Determine the local player's color for the first time
		if not playerColor then
			if localPlayer.Name == snapshot.players.White then
				playerColor = GameTypes.Colors.White
			elseif localPlayer.Name == snapshot.players.Black then
				playerColor = GameTypes.Colors.Black
			end
			print("Player color is:", playerColor)
		end

		-- Enable or disable input based on whose turn it is
		if snapshot.activeColor == playerColor and snapshot.status == "InProgress" then
			inputHandler:enable(snapshot.boardState, playerColor)
		else
			inputHandler:disable()
		end

		uiController:update(snapshot, playerColor) -- Update HUD
	end)

	-- Listen for the end of the match
	Remotes.MatchEnd.OnClientEvent:Connect(function(result: table)
		print("Match ended. Result:", result)
		inputHandler:disable()
		uiController:showResult(result, playerColor)
	end)

	Remotes.MagicMoveRejected.OnClientEvent:Connect(function(reason: string)
		print("Magic Move Rejected:", reason)
		uiController:showToast("Magic Move Rejected: " .. reason)
	end)


	-- For testing, immediately request a match
	-- In a real lobby, this would be tied to a UI button
	wait(2) -- Wait for server to set up
	print("Requesting quick match...")
	Remotes.RequestQuickMatch:FireServer()

end


ClientController.start()

return ClientController
