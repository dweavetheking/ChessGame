--!strict
--[=[
	Handles player input on the 3D board.
	@module InputHandler
]=]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.src.shared
local ChessEngine = require(Shared.ChessEngine)
local Remotes = require(Shared.RemotesInit)
local MagicMoveSystem = require(Shared.MagicMoveSystem)

local InputHandler = {}
InputHandler.__index = InputHandler

-- Constants
local BOARD_SIZE = 8
local TILE_SIZE = 8

--[=[
	Initializes the InputHandler.
	@param boardRenderer The BoardRenderer instance.
	@param uiController The UIController instance.
]=]
function InputHandler.new(boardRenderer, uiController)
	local self = setmetatable({}, InputHandler)

	self.boardRenderer = boardRenderer
	self.uiController = uiController
	self.boardModel = boardRenderer.boardModel
	self.anchor = boardRenderer.anchor

	self.connections = {}
	self.isEnabled = false
	self.localPlayerColor = nil
	self.boardState = nil

	self.selectedSquare = nil -- {x: number, y: number}
	self.selectionMode = "None" -- "None", "Move", "MagicUpgrade", "MagicDowngrade", "Tutorial"
	self.tutorialCallback = nil

	self:_connectUICalls()

	return self
end

--[=[
	Converts a 3D world position to board coordinates.
	@param worldPos Vector3
	@return {x: number, y: number}?
]=]
function InputHandler:_worldToBoardCoords(worldPos: Vector3)
	-- Transform the world position to be relative to the board's anchor CFrame
	local relativePos = self.anchor:PointToObjectSpace(worldPos)

	-- Calculate the total board dimensions
	local totalBoardDim = BOARD_SIZE * TILE_SIZE
	local halfBoardDim = totalBoardDim / 2

	-- Normalize the coordinates from [-half, +half] to [0, total]
	local normalizedX = relativePos.X + halfBoardDim
	local normalizedZ = relativePos.Z + halfBoardDim

	-- Convert to grid coordinates [1-8]
	local gridX = math.floor(normalizedX / TILE_SIZE) + 1
	local gridZ = math.floor(normalizedZ / TILE_SIZE) + 1

	if gridX >= 1 and gridX <= BOARD_SIZE and gridZ >= 1 and gridZ <= BOARD_SIZE then
		return { x = gridX, y = gridZ }
	end

	return nil
end

--[=[
	Connects UI button clicks to handler functions.
]=]
function InputHandler:_connectUICalls()
	self.uiController.magicMoveButton.MouseButton1Click:Connect(function()
		self.uiController:showChoiceModal(true)
	end)

	local choiceModal = self.uiController.choiceModal
	choiceModal.UpgradeButton.MouseButton1Click:Connect(function()
		self:_enterMagicSelectionMode("MagicUpgrade")
	end)
	choiceModal.DowngradeButton.MouseButton1Click:Connect(function()
		self:_enterMagicSelectionMode("MagicDowngrade")
	end)
	choiceModal.CancelButton.MouseButton1Click:Connect(function()
		self:_resetSelection()
	end)
end

--[=[
	Handles a click on the board.
]=]
function InputHandler:_handleInput(input: InputObject)
	if not self.isEnabled or not self.boardState then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1Click and input.UserInputType ~= Enum.UserInputType.TouchTap then
		return
	end

	local ray = workspace.CurrentCamera:ViewportPointToRay(input.Position.X, input.Position.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { self.boardModel }
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)

	if not result or not result.Instance then
		self:_resetSelection()
		return
	end

	local coords = self:_worldToBoardCoords(result.Position)
	if not coords then
		self:_resetSelection()
		return
	end

	if self.selectionMode == "MagicUpgrade" or self.selectionMode == "MagicDowngrade" then
		self:_handleMagicSelection(coords)
	else
		self:_handleMoveSelection(coords)
	end
end

function InputHandler:setTutorialCallback(callback: ((any) -> ())?)
	self.tutorialCallback = callback
	if callback then
		self.selectionMode = "Tutorial"
	else
		self.selectionMode = "None"
	end
end

function InputHandler:_handleMoveSelection(coords)
	if self.tutorialCallback then
		self.tutorialCallback(coords)
		return
	end

	local pieceAtClick = self.boardState[coords.y][coords.x]

	if self.selectedSquare then
		-- A piece is already selected, check if this is a move
		local fromSquare = self.selectedSquare
		local toSquare = coords
		local isLegal, _ = ChessEngine.isMoveLegal(self.boardState, fromSquare, toSquare, self.localPlayerColor)

		if isLegal then
			-- Valid move, send to server
			Remotes.MoveAttempt:FireServer(fromSquare, toSquare)
			self:_resetSelection()
		else
			-- Invalid move or selecting another piece
			self:_resetSelection()
			-- If the new click is on a friendly piece, select it
			if pieceAtClick and pieceAtClick.color == self.localPlayerColor then
				self:_selectPiece(coords)
			end
		end
	else
		-- No piece is selected, try to select one
		if pieceAtClick and pieceAtClick.color == self.localPlayerColor then
			self:_selectPiece(coords)
		end
	end
end

function InputHandler:_handleMagicSelection(coords)
	local piece = self.boardState[coords.y][coords.x]
	if not piece then
		return
	end

	local actionType = (self.selectionMode == "MagicUpgrade") and "Upgrade" or "Downgrade"
	local allowedTypes = (actionType == "Upgrade")
		and MagicMoveSystem.getAllowedUpgradeTypes(piece.pieceType)
		or MagicMoveSystem.getAllowedDowngradeTypes(piece.pieceType)

	if #allowedTypes == 0 then
		-- This shouldn't happen if highlighting is correct, but as a safeguard:
		self:_resetSelection()
		return
	end

	if #allowedTypes == 1 then
		-- Only one option, so send the request immediately
		Remotes.MagicMoveAttempt:FireServer(actionType, coords, allowedTypes[1])
		self:_resetSelection()
	else
		-- Multiple options, show the type selection UI
		self.uiController:showTypeSelectionModal(allowedTypes, function(selectedType)
			Remotes.MagicMoveAttempt:FireServer(actionType, coords, selectedType)
			self:_resetSelection()
		end)
	end
end

function InputHandler:_enterMagicSelectionMode(mode: string)
	self.selectionMode = mode
	self.uiController:showChoiceModal(false)
	self.boardRenderer:clearHighlights()

	local targets = {}
	if mode == "MagicUpgrade" then
		targets = MagicMoveSystem.getValidUpgradeTargets(self.boardState, self.localPlayerColor)
	elseif mode == "MagicDowngrade" then
		targets = MagicMoveSystem.getValidDowngradeTargets(self.boardState, self.localPlayerColor)
	end

	self.boardRenderer:highlightSquares(targets)
end

function InputHandler:_resetSelection()
	self.selectedSquare = nil
	self.selectionMode = "None"
	self.boardRenderer:clearHighlights()
	self.uiController:showChoiceModal(false)
	self.uiController:updateTooltip(false)
end

function InputHandler:_handleMouseMove(input: InputObject)
	if not self.isEnabled or not (self.selectionMode == "MagicUpgrade" or self.selectionMode == "MagicDowngrade") then
		self.uiController:updateTooltip(false)
		return
	end

	local ray = workspace.CurrentCamera:ViewportPointToRay(input.Position.X, input.Position.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { self.boardModel }
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)

	if result and result.Instance then
		local coords = self:_worldToBoardCoords(result.Position)
		if coords then
			local piece = self.boardState[coords.y][coords.x]
			if piece then
				local allowedTypes = (self.selectionMode == "MagicUpgrade")
					and MagicMoveSystem.getAllowedUpgradeTypes(piece.pieceType)
					or MagicMoveSystem.getAllowedDowngradeTypes(piece.pieceType)

				if #allowedTypes > 0 then
					local tooltipText = `Transform {piece.pieceType} to:\n{table.concat(allowedTypes, " / ")}`
					local pos = UDim2.new(0, input.Position.X + 15, 0, input.Position.Y)
					self.uiController:updateTooltip(true, tooltipText, pos)
					return
				end
			end
		end
	end

	self.uiController:updateTooltip(false)
end


--[=[
	Selects a piece and shows its legal moves.
]=]
function InputHandler:_selectPiece(coords)
	self.selectionMode = "Move"
	self.selectedSquare = coords
	local legalMoves = {}

	for y = 1, BOARD_SIZE do
		for x = 1, BOARD_SIZE do
			if ChessEngine.isMoveLegal(self.boardState, coords, { x = x, y = y }, self.localPlayerColor) then
				table.insert(legalMoves, { x = x, y = y })
			end
		end
	end

	self.boardRenderer:highlightSquares(legalMoves)
end


--[=[
	Enables player input.
]=]
function InputHandler:enable(boardState, playerColor)
	if self.isEnabled then
		return
	end
	print("Input enabled for color:", playerColor)
	self.isEnabled = true
	self.localPlayerColor = playerColor
	self.boardState = boardState
	if not self.connections["InputBegan"] then
		self.connections["InputBegan"] = UserInputService.InputBegan:Connect(function(input)
			self:_handleInput(input)
		end)
		self.connections["InputChanged"] = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				self:_handleMouseMove(input)
			end
		end)
	end
end

--[=[
	Disables player input.
]=]
function InputHandler:disable()
	if not self.isEnabled then
		return
	end
	print("Input disabled.")
	self.isEnabled = false
	self.localPlayerColor = nil
	self.boardState = nil
	self.selectedSquare = nil
	self.boardRenderer:clearHighlights()
	-- Do not disconnect the event, just use the isEnabled flag
end

--[=[
	Cleans up connections.
]=]
function InputHandler:destroy()
	for _, conn in pairs(self.connections) do
		conn:Disconnect()
	end
	table.clear(self.connections)
	self.boardRenderer = nil
	self.uiController = nil
end

return InputHandler
