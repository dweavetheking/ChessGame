--!strict
--[=[
	Renders the 3D board and piece instances based on board snapshots from the server.
	@module BoardRenderer
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.src.shared
local Client = ReplicatedStorage.src.client
local GameTypes = require(Shared.GameTypes)
local SoundManager = require(Client.SoundManager)

local BoardRenderer = {}
BoardRenderer.__index = BoardRenderer

-- Constants
local BOARD_SIZE = 8
local TILE_SIZE = 8
local BOARD_THICKNESS = 1
local PIECE_SIZE = TILE_SIZE * 0.8
local HIGHLIGHT_TRANSPARENCY = 0.5
local HIGHLIGHT_COLOR = Color3.fromRGB(255, 255, 0)

--[=[
	Initializes the BoardRenderer.
	@param anchor CFrame The CFrame where the center of the board should be.
	@return BoardRenderer
]=]
function BoardRenderer.new(anchor: CFrame)
	local self = setmetatable({}, BoardRenderer)

	self.anchor = anchor
	self.boardModel = Instance.new("Model")
	self.boardModel.Name = "MagicChessBoard"
	self.boardModel.Parent = Workspace

	self.pieceModels = {} -- Map of pieceType -> Part
	self.activePieces = {} -- Map of pieceId -> Model
	self.highlightParts = {} -- Array of highlight parts

	self:_createPieceTemplates()
	self:_createBoard()

	return self
end

--[=[
	Creates the visual 8x8 chessboard.
]=]
function BoardRenderer:_createBoard()
	local boardContainer = Instance.new("Part")
	boardContainer.Name = "BoardContainer"
	boardContainer.Size = Vector3.new(BOARD_SIZE * TILE_SIZE, BOARD_THICKNESS, BOARD_SIZE * TILE_SIZE)
	boardContainer.Anchored = true
	boardContainer.CFrame = self.anchor
	boardContainer.Parent = self.boardModel
	boardContainer.Color = Color3.fromRGB(80, 40, 0) -- Wood color

	for x = 1, BOARD_SIZE do
		for y = 1, BOARD_SIZE do
			local tile = Instance.new("Part")
			tile.Name = `Tile_{x}_{y}`
			tile.Size = Vector3.new(TILE_SIZE, BOARD_THICKNESS + 0.1, TILE_SIZE)
			tile.TopSurface = Enum.SurfaceType.Smooth
			tile.BottomSurface = Enum.SurfaceType.Smooth
			tile.Anchored = true
			tile.Parent = self.boardModel

			-- Color the tile
			if (x + y) % 2 == 0 then
				tile.Color = Color3.fromRGB(235, 235, 208) -- Light
			else
				tile.Color = Color3.fromRGB(119, 149, 86) -- Dark
			end

			-- Position the tile
			local boardCenterOffset = Vector3.new(BOARD_SIZE * TILE_SIZE / 2, 0, BOARD_SIZE * TILE_SIZE / 2)
			local tileOffset = Vector3.new(x * TILE_SIZE - TILE_SIZE / 2, 0, y * TILE_SIZE - TILE_SIZE / 2)
			tile.CFrame = self.anchor * CFrame.new(tileOffset - boardCenterOffset)
		end
	end
end

--[=[
	Creates the template models for each piece type.
]=]
function BoardRenderer:_createPieceTemplates()
	local templatesFolder = Instance.new("Folder")
	templatesFolder.Name = "PieceTemplates"
	templatesFolder.Parent = self.boardModel

	local function createTemplate(name: string, shape: Enum.PartType, size: Vector3)
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = shape
		part.Size = size
		part.Anchored = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = templatesFolder
		self.pieceModels[name] = part
	end

	createTemplate(GameTypes.PieceTypes.Pawn, Enum.PartType.Cylinder, Vector3.new(PIECE_SIZE * 0.8, PIECE_SIZE, PIECE_SIZE * 0.8))
	createTemplate(GameTypes.PieceTypes.Knight, Enum.PartType.Block, Vector3.new(PIECE_SIZE * 0.9, PIECE_SIZE * 1.5, PIECE_SIZE * 0.9)) -- Distinct shape
	createTemplate(GameTypes.PieceTypes.Bishop, Enum.PartType.Ball, Vector3.new(PIECE_SIZE, PIECE_SIZE * 1.6, PIECE_SIZE))
	createTemplate(GameTypes.PieceTypes.Rook, Enum.PartType.Cylinder, Vector3.new(PIECE_SIZE, PIECE_SIZE * 1.4, PIECE_SIZE))
	createTemplate(GameTypes.PieceTypes.Queen, Enum.PartType.Cylinder, Vector3.new(PIECE_SIZE, PIECE_SIZE * 1.8, PIECE_SIZE))
	createTemplate(GameTypes.PieceTypes.King, Enum.PartType.Block, Vector3.new(PIECE_SIZE, PIECE_SIZE * 2, PIECE_SIZE)) -- Tallest
end

--[=[
	Clears all highlights from the board.
]=]
function BoardRenderer:clearHighlights()
	for _, part in ipairs(self.highlightParts) do
		part:Destroy()
	end
	table.clear(self.highlightParts)
end

--[=[
	Highlights a list of squares on the board.
	@param squares table Array of {x: number, y: number}
]=]
function BoardRenderer:highlightSquares(squares: { { x: number, y: number } })
	self:clearHighlights()

	for _, square in ipairs(squares) do
		local highlight = Instance.new("Part")
		highlight.Name = "Highlight"
		highlight.Size = Vector3.new(TILE_SIZE, BOARD_THICKNESS + 0.2, TILE_SIZE)
		highlight.Color = HIGHLIGHT_COLOR
		highlight.Material = Enum.Material.Neon
		highlight.Transparency = HIGHLIGHT_TRANSPARENCY
		highlight.Anchored = true
		highlight.CanCollide = false
		highlight.Parent = self.boardModel

		local boardCenterOffset = Vector3.new(BOARD_SIZE * TILE_SIZE / 2, 0, BOARD_SIZE * TILE_SIZE / 2)
		local tileOffset = Vector3.new(square.x * TILE_SIZE - TILE_SIZE / 2, 0, square.y * TILE_SIZE - TILE_SIZE / 2)
		highlight.CFrame = self.anchor * CFrame.new(tileOffset - boardCenterOffset)

		table.insert(self.highlightParts, highlight)
	end
end

--[=[
	Calculates the CFrame for a piece at a given board coordinate.
]=]
function BoardRenderer:_getPieceCFrame(x: number, y: number, pieceSize: Vector3): CFrame
	local boardCenterOffset = Vector3.new(BOARD_SIZE * TILE_SIZE / 2, 0, BOARD_SIZE * TILE_SIZE / 2)
	local pieceOffset = Vector3.new(
		x * TILE_SIZE - TILE_SIZE / 2,
		(pieceSize.Y / 2) + BOARD_THICKNESS,
		y * TILE_SIZE - TILE_SIZE / 2
	)
	return self.anchor * CFrame.new(pieceOffset - boardCenterOffset)
end

--[=[
	Animates a piece's movement.
]=]
function BoardRenderer:_animateMove(pieceModel: Part, toCFrame: CFrame)
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local tween = TweenService:Create(pieceModel, tweenInfo, { CFrame = toCFrame })
	tween:Play()
end

--[=[
	Animates a piece being captured.
]=]
function BoardRenderer:_animateCapture(pieceModel: Part)
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(pieceModel, tweenInfo, { Transparency = 1 })
	tween:Play()
	tween.Completed:Wait()
	pieceModel:Destroy()
end

function BoardRenderer:animateMagicTransformation(pieceModel: Part)
	-- Simple glow and pulse effect
	local originalColor = pieceModel.Color
	local highlight = Instance.new("PointLight")
	highlight.Color = Color3.fromRGB(0, 255, 255)
	highlight.Brightness = 5
	highlight.Range = 12
	highlight.Parent = pieceModel

	SoundManager.playMagicMoveSound()

	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, true)
	local scaleTween = TweenService:Create(pieceModel, tweenInfo, { Size = pieceModel.Size * 1.5 })

	scaleTween:Play()
	scaleTween.Completed:Wait()

	highlight:Destroy()
end

--[=[
	Renders the entire board state from a snapshot, animating changes.
	@param boardState table The 8x8 grid of piece data.
]=]
function BoardRenderer:drawBoard(boardState: ChessEngine.BoardState)
	local newPieceIds = {}
	local piecesToMove = {}

	-- First pass: identify new pieces and pieces that moved
	for y = 1, BOARD_SIZE do
		for x = 1, BOARD_SIZE do
			local pieceData = boardState[y][x]
			if pieceData then
				newPieceIds[pieceData.id] = true
				local existingPiece = self.activePieces[pieceData.id]

				if existingPiece then
					-- Piece exists, check for changes
					if not existingPiece.Name:match(pieceData.pieceType) then
						-- Piece type changed! Magic Move occurred.
						self:animateMagicTransformation(existingPiece)
						existingPiece:Destroy()
						self.activePieces[pieceData.id] = nil -- Force recreation
						existingPiece = nil -- Redefine to trigger creation below
					else
						-- Type is the same, check if it needs to move
						local newCFrame = self:_getPieceCFrame(x, y, existingPiece.Size)
						if (existingPiece.CFrame.Position - newCFrame.Position).Magnitude > 0.1 then
							table.insert(piecesToMove, { model = existingPiece, cframe = newCFrame })
						end
					end
				end

				if not existingPiece then
					-- Piece is new or was just transformed
					local template = self.pieceModels[pieceData.pieceType]
					if template then
						local newPiece = template:Clone()
						newPiece.Name = `{pieceData.pieceType}_{pieceData.id}`
						newPiece.Color = (pieceData.color == GameTypes.Colors.White) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(20, 20, 20)
						newPiece.CFrame = self:_getPieceCFrame(x, y, newPiece.Size)
						newPiece.Parent = self.boardModel
						self.activePieces[pieceData.id] = newPiece
					end
				end
			end
		end
	end

	-- Second pass: identify and animate captured pieces
	for id, model in pairs(self.activePieces) do
		if not newPieceIds[id] then
			self:_animateCapture(model)
			self.activePieces[id] = nil
		end
	end

	-- Animate all movements
	for _, moveData in ipairs(piecesToMove) do
		self:_animateMove(moveData.model, moveData.cframe)
	end
end

--[=[
	Cleans up the board and all related instances.
]=]
function BoardRenderer:destroy()
	if self.boardModel then
		self.boardModel:Destroy()
	end
	table.clear(self.pieceModels)
	table.clear(self.activePieces)
	table.clear(self.highlightParts)
end

return BoardRenderer
