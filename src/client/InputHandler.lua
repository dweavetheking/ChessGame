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

local InputHandler = {}
InputHandler.__index = InputHandler

-- Constants
local BOARD_SIZE = 8
local TILE_SIZE = 8

--[=[
	Initializes the InputHandler.
	@param boardRenderer The BoardRenderer instance.
]=]
function InputHandler.new(boardRenderer)
	local self = setmetatable({}, InputHandler)

	self.boardRenderer = boardRenderer
	self.boardModel = boardRenderer.boardModel
	self.anchor = boardRenderer.anchor

	self.connections = {}
	self.isEnabled = false
	self.localPlayerColor = nil
	self.boardState = nil

	self.selectedSquare = nil -- {x: number, y: number}

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

	if result and result.Instance then
		local coords = self:_worldToBoardCoords(result.Position)
		if not coords then
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
				self.selectedSquare = nil
				self.boardRenderer:clearHighlights()
			else
				-- Invalid move or selecting another piece
				self.selectedSquare = nil
				self.boardRenderer:clearHighlights()
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
end

--[=[
	Selects a piece and shows its legal moves.
]=]
function InputHandler:_selectPiece(coords)
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
end

return InputHandler
