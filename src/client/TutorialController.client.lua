--!strict
--[=[
	Manages the first-time user experience and tutorial.
	@module TutorialController
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Client = ReplicatedStorage.src.client
local Shared = ReplicatedStorage.src.shared

local UIController = require(Client.UIController)
local BoardRenderer = require(Client.BoardRenderer)
local InputHandler = require(Client.InputHandler)
local CameraController = require(Client.CameraController)
local GameTypes = require(Shared.GameTypes)
local Remotes = require(Shared.RemotesInit)

local TutorialController = {}
TutorialController.__index = TutorialController

function TutorialController.new(uiController)
	local self = setmetatable({}, TutorialController)
	self.uiController = uiController
	self.step = 1
	self.boardState = nil
	self.connections = {}
	return self
end

function TutorialController:start()
	self.uiController:showWelcomeModal(function()
		Remotes.RequestTutorialMatch:FireServer()
		self:_setupMatch()
	end)
end

function TutorialController:_setupMatch()
	local boardAnchor = CFrame.new(0, 5, 0)
	self.boardRenderer = BoardRenderer.new(boardAnchor, "Classic")
	self.cameraController = CameraController.new(boardAnchor)
	self.inputHandler = InputHandler.new(self.boardRenderer, self.uiController)
	self.inputHandler:enable(nil, GameTypes.Colors.White) -- Enable for tutorial

	self.connections.StateUpdate = Remotes.MatchStateUpdate.OnClientEvent:Connect(function(snapshot)
		self.boardState = snapshot.boardState
		self.inputHandler.boardState = self.boardState -- Keep input handler's state in sync
		self.boardRenderer:drawBoard(snapshot.boardState)
		self:_processStep()
	end)
end

function TutorialController:_processStep()
	if self.step == 1 then
		self.uiController:showTutorialBanner("Welcome! Let's learn the basics. Select your Pawn.")
		self.boardRenderer:highlightSquares({ { x = 5, y = 2 } })
		self:_waitForClickOnSquare(5, 2, function()
			self.step = 2
			self:_processStep()
		end)
	elseif self.step == 2 then
		self.uiController:showTutorialBanner("Good. Now move it forward two squares.")
		self.boardRenderer:highlightSquares({ { x = 5, y = 4 } })
		self:_waitForClickOnSquare(5, 4, function()
			Remotes.MoveAttempt:FireServer({ x = 5, y = 2 }, { x = 5, y = 4 })
			self.step = 3
		end)
	elseif self.step == 3 then
		self.uiController:showTutorialBanner("Great! Now, let's try a capture. Select your Rook.")
		self.boardRenderer:highlightSquares({ { x = 3, y = 4 } })
		self:_waitForClickOnSquare(3, 4, function()
			self.step = 4
			self:_processStep()
		end)
	elseif self.step == 4 then
		self.uiController:showTutorialBanner("Capture the enemy Pawn.")
		self.boardRenderer:highlightSquares({ { x = 3, y = 7 } })
		self:_waitForClickOnSquare(3, 7, function()
			Remotes.MoveAttempt:FireServer({ x = 3, y = 4 }, { x = 3, y = 7 })
			self.step = 5
		end)
	elseif self.step == 5 then
		self.uiController:showTutorialBanner("Excellent! Now for the fun part. Click the Magic Move button.")
		-- Highlighting UI elements is more complex, for now we'll just rely on the text
		self.uiController.magicMoveButton.Visible = true
		self.connections.MagicMove = self.uiController.magicMoveButton.MouseButton1Click:Connect(function()
			self.step = 6
			self:_processStep()
		end)
	elseif self.step == 6 then
		self.uiController:showTutorialBanner("Let's upgrade your Pawn. Choose 'Upgrade'.")
		self.connections.Upgrade = self.uiController.choiceModal.UpgradeButton.MouseButton1Click:Connect(function()
			self.step = 7
			self:_processStep()
		end)
	elseif self.step == 7 then
		self.uiController:showTutorialBanner("Select the Pawn to upgrade it.")
		self.boardRenderer:highlightSquares({ { x = 5, y = 4 } })
		self:_waitForClickOnSquare(5, 4, function()
			self.step = 8
			self:_processStep()
		end)
	elseif self.step == 8 then
		self.uiController:showTutorialBanner("Turn it into a Rook!")
		self.connections.ToRook = self.uiController.typeSelectionModal.RookButton.MouseButton1Click:Connect(function()
			Remotes.MagicMoveAttempt:FireServer("Upgrade", { x = 5, y = 4 }, GameTypes.PieceTypes.Rook)
			self.step = 9
		end)
	elseif self.step == 9 then
		self.uiController:showTutorialBanner("Tutorial Complete!")
		Remotes.TutorialEnded:FireServer()
		self.uiController:showResult({ status = "TutorialComplete", winner = nil }, nil, 1200, 1200)
		self:_cleanup()
	end
end

function TutorialController:_waitForClickOnSquare(x, y, callback)
	self.inputHandler:setTutorialCallback(function(coords)
		if coords and coords.x == x and coords.y == y then
			self.inputHandler:setTutorialCallback(nil)
			callback()
		end
	end)
end

function TutorialController:_cleanup()
	for _, conn in pairs(self.connections) do
		conn:Disconnect()
	end
	table.clear(self.connections)
	if self.boardRenderer then
		self.boardRenderer:destroy()
	end
	if self.cameraController then
		self.cameraController:destroy()
	end
	if self.inputHandler then
		self.inputHandler:destroy()
	end
	self.uiController.tutorialBanner.Visible = false
end

return TutorialController
