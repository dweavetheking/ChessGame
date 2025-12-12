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
local CameraController = require(Client.CameraController)
local Remotes = require(Shared.RemotesInit)
local GameTypes = require(Shared.GameTypes)

local ClientController = {}

local localPlayer = Players.LocalPlayer
local activeModules = {}

function ClientController.destroyAll()
	for name, module in pairs(activeModules) do
		if module and module.destroy then
			module:destroy()
		end
		activeModules[name] = nil
	end
	table.clear(activeModules)
	-- Show the main lobby UI again, for now just re-enable CoreGui
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
end

--[=[
	Main entry point for the client.
]=]
function ClientController.start()
	print("ClientController started.")

	-- Initial setup
	local boardAnchor = CFrame.new(0, 5, 0)
	local themeName = math.random(1, 2) == 1 and "Classic" or "Magic"
	local boardRenderer = BoardRenderer.new(boardAnchor, themeName)
	local uiController = UIController.new()
	local inputHandler = InputHandler.new(boardRenderer, uiController)
	local cameraController = CameraController.new(boardAnchor)

	activeModules = {
		boardRenderer = boardRenderer,
		uiController = uiController,
		inputHandler = inputHandler,
		cameraController = cameraController,
	}

	local playerColor = nil
	local lastMagicState = { whiteUsed = false, blackUsed = false }

	-- Hide non-essential Roblox UI
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

	-- Connect UI events
	uiController.resignButton.MouseButton1Click:Connect(function()
		Remotes.ResignAttempt:FireServer()
	end)

	uiController.aiMatchButton.MouseButton1Click:Connect(function()
		ClientController.destroyAll()
		wait(0.5)
		Remotes.RequestAIMatch:FireServer()
	end)

	uiController.quickMatchButton.MouseButton1Click:Connect(function()
		ClientController.destroyAll()
		wait(0.5)
		Remotes.RequestQuickMatch:FireServer()
	end)

	uiController.endGameModal.BackButton.MouseButton1Click:Connect(function()
		ClientController.destroyAll()
		-- In a real app, you'd show a lobby UI. For now, we'll re-queue.
		wait(1)
		ClientController.start()
	end)


	-- Listen for match state updates from the server
	local onStateUpdate = Remotes.MatchStateUpdate.OnClientEvent:Connect(function(snapshot: table)
		if not playerColor then
			if localPlayer.Name == snapshot.players.White then
				playerColor = GameTypes.Colors.White
			elseif localPlayer.Name == snapshot.players.Black then
				playerColor = GameTypes.Colors.Black
			end
		end

		if snapshot.isCheck then SoundManager.playCheckSound() end
		if snapshot.lastMove and snapshot.lastMove.capturedPiece then cameraController:playEmphasis() end
		if snapshot.magicState.whiteUsed ~= lastMagicState.whiteUsed or snapshot.magicState.blackUsed ~= lastMagicState.blackUsed then
			cameraController:playEmphasis()
			lastMagicState = snapshot.magicState
		end

		boardRenderer:drawBoard(snapshot.boardState, snapshot.lastMove)

		if snapshot.activeColor == playerColor and snapshot.status == "InProgress" then
			inputHandler:enable(snapshot.boardState, playerColor)
		else
			inputHandler:disable()
		end
		uiController:update(snapshot, playerColor)
	end)

	local onMatchEnd = Remotes.MatchEnd.OnClientEvent:Connect(function(result: table)
		inputHandler:disable()
		uiController:showResult(result, playerColor)
	end)

	local onMagicRejected = Remotes.MagicMoveRejected.OnClientEvent:Connect(function(reason: string)
		uiController:showToast("Magic Move Rejected: " .. reason)
	end)

	function activeModules.inputHandler:destroy()
		onStateUpdate:Disconnect()
		onMatchEnd:Disconnect()
		onMagicRejected:Disconnect()
	end

	-- For testing, immediately request a match
	-- wait(2)
	-- Remotes.RequestQuickMatch:FireServer()
end

-- ClientController.start() -- Should be started from a lobby screen
ClientController.start()

return ClientController
