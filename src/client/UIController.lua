--!strict
--[=[
	Builds and manages the in-game UI (HUD).
	@module UIController
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage.src.shared
local GameTypes = require(Shared.GameTypes)

local UIController = {}
UIController.__index = UIController

--[=[
	Initializes the UIController.
]=]
function UIController.new()
	local self = setmetatable({}, UIController)

	self.screenGui = Instance.new("ScreenGui")
	self.screenGui.Name = "MagicChessHUD"
	self.screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	self:_createHUD()

	return self
end

--[=[
	Creates the main HUD elements.
]=]
function UIController:_createHUD()
	-- Main container
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(1, 0, 0, 100)
	mainFrame.Position = UDim2.new(0, 0, 1, -100)
	mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	mainFrame.BackgroundTransparency = 0.3
	mainFrame.Parent = self.screenGui

	-- Player Info (White)
	self.whitePlayerLabel = Instance.new("TextLabel")
	self.whitePlayerLabel.Name = "WhitePlayer"
	self.whitePlayerLabel.Size = UDim2.new(0.3, 0, 0, 40)
	self.whitePlayerLabel.Position = UDim2.new(0.05, 0, 0.1, 0)
	self.whitePlayerLabel.Font = Enum.Font.SourceSansBold
	self.whitePlayerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.whitePlayerLabel.Text = "White: ..."
	self.whitePlayerLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.whitePlayerLabel.Parent = mainFrame

	-- Player Info (Black)
	self.blackPlayerLabel = Instance.new("TextLabel")
	self.blackPlayerLabel.Name = "BlackPlayer"
	self.blackPlayerLabel.Size = UDim2.new(0.3, 0, 0, 40)
	self.blackPlayerLabel.Position = UDim2.new(0.65, 0, 0.1, 0)
	self.blackPlayerLabel.Font = Enum.Font.SourceSansBold
	self.blackPlayerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.blackPlayerLabel.Text = "Black: ..."
	self.blackPlayerLabel.TextXAlignment = Enum.TextXAlignment.Right
	self.blackPlayerLabel.Parent = mainFrame

	-- Turn Indicator
	self.turnIndicator = Instance.new("TextLabel")
	self.turnIndicator.Name = "TurnIndicator"
	self.turnIndicator.Size = UDim2.new(0.4, 0, 0, 40)
	self.turnIndicator.Position = UDim2.new(0.3, 0, 0.5, 0)
	self.turnIndicator.Font = Enum.Font.SourceSansBold
	self.turnIndicator.TextColor3 = Color3.fromRGB(255, 255, 0)
	self.turnIndicator.Text = "Waiting for match..."
	self.turnIndicator.Parent = mainFrame

	-- Magic Move Status
	self.whiteMagicLabel = self._createMagicLabel("WhiteMagic", UDim2.new(0.05, 0, 0.5, 0), "Left", mainFrame)
	self.blackMagicLabel = self._createMagicLabel("BlackMagic", UDim2.new(0.65, 0, 0.5, 0), "Right", mainFrame)

	-- Magic Move Button
	self.magicMoveButton = Instance.new("TextButton")
	self.magicMoveButton.Name = "MagicMoveButton"
	self.magicMoveButton.Size = UDim2.new(0.2, 0, 0, 40)
	self.magicMoveButton.Position = UDim2.new(0.4, 0, 0.05, 0)
	self.magicMoveButton.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
	self.magicMoveButton.Font = Enum.Font.SourceSansBold
	self.magicMoveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.magicMoveButton.Text = "✨ Magic Move"
	self.magicMoveButton.Visible = false -- Hidden by default
	self.magicMoveButton.Parent = mainFrame

	-- Magic Move Choice Modal
	self:_createChoiceModal()
	self:_createTypeSelectionModal()
end

function UIController:_createMagicLabel(name: string, position: UDim2, align: string, parent: GuiObject)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = UDim2.new(0.2, 0, 0, 30)
	label.Position = position
	label.Font = Enum.Font.SourceSansBold
	label.Text = "Magic: READY"
	label.TextXAlignment = Enum.TextXAlignment[align]
	label.Parent = parent
	return label
end

function UIController:_createChoiceModal()
	local modalFrame = Instance.new("Frame")
	modalFrame.Name = "ChoiceModal"
	modalFrame.Size = UDim2.new(0.4, 0, 0.3, 0)
	modalFrame.Position = UDim2.new(0.3, 0, -0.35, 0) -- Position above the HUD
	modalFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	modalFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
	modalFrame.BorderSizePixel = 2
	modalFrame.Visible = false
	modalFrame.Parent = self.screenGui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Text = "Choose Magic Move"
	title.Font = Enum.Font.SourceSansBold
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Parent = modalFrame

	local upgradeBtn = Instance.new("TextButton")
	upgradeBtn.Name = "UpgradeButton"
	upgradeBtn.Size = UDim2.new(0.4, 0, 0, 50)
	upgradeBtn.Position = UDim2.new(0.05, 0, 0.5, 0)
	upgradeBtn.Text = "Upgrade Own Piece"
	upgradeBtn.Parent = modalFrame

	local downgradeBtn = Instance.new("TextButton")
	downgradeBtn.Name = "DowngradeButton"
	downgradeBtn.Size = UDim2.new(0.4, 0, 0, 50)
	downgradeBtn.Position = UDim2.new(0.55, 0, 0.5, 0)
	downgradeBtn.Text = "Downgrade Opponent's"
	downgradeBtn.Parent = modalFrame

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Name = "CancelButton"
	cancelBtn.Size = UDim2.new(0.9, 0, 0, 30)
	cancelBtn.Position = UDim2.new(0.05, 0, 0.8, 0)
	cancelBtn.Text = "Cancel"
	cancelBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	cancelBtn.Parent = modalFrame

	self.choiceModal = modalFrame
end

function UIController:_createTypeSelectionModal()
	local typeFrame = Instance.new("Frame")
	typeFrame.Name = "TypeSelectionModal"
	typeFrame.Size = UDim2.new(0.3, 0, 0.2, 0)
	typeFrame.Position = UDim2.new(0.35, 0, -0.25, 0)
	typeFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	typeFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
	typeFrame.BorderSizePixel = 2
	typeFrame.Visible = false
	typeFrame.Parent = self.screenGui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Text = "Select New Type"
	title.Font = Enum.Font.SourceSansBold
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Parent = typeFrame

	local buttonContainer = Instance.new("UIListLayout")
	buttonContainer.FillDirection = Enum.FillDirection.Horizontal
	buttonContainer.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonContainer.VerticalAlignment = Enum.VerticalAlignment.Center
	buttonContainer.Parent = typeFrame

	self.typeSelectionModal = typeFrame

	-- Tooltip
	local tooltip = Instance.new("TextLabel")
	tooltip.Name = "HoverTooltip"
	tooltip.Size = UDim2.new(0, 200, 0, 50)
	tooltip.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	tooltip.BackgroundTransparency = 0.5
	tooltip.TextColor3 = Color3.fromRGB(255, 255, 255)
	tooltip.Font = Enum.Font.SourceSans
	tooltip.TextWrapped = true
	tooltip.Visible = false
	tooltip.ZIndex = 10
	tooltip.Parent = self.screenGui
	self.tooltip = tooltip
end


--[=[
	Updates the HUD with the latest game state.
	@param snapshot The game state from the server.
	@param localPlayerColor The color of the local player.
]=]
function UIController:update(snapshot: table, localPlayerColor: string)
	-- Update player names
	self.whitePlayerLabel.Text = `White: {snapshot.players.White}`
	self.blackPlayerLabel.Text = `Black: {snapshot.players.Black}`

	-- Update turn indicator and Magic Move button visibility
	local isMyTurn = snapshot.activeColor == localPlayerColor
	if snapshot.status ~= "InProgress" then
		self.turnIndicator.Text = snapshot.status
		self.magicMoveButton.Visible = false
	elseif isMyTurn then
		self.turnIndicator.Text = "Your Turn"
		self.turnIndicator.TextColor3 = Color3.fromRGB(0, 255, 0)
	else
		self.turnIndicator.Text = "Opponent's Turn"
		self.turnIndicator.TextColor3 = Color3.fromRGB(255, 255, 0)
	end

	-- Update Magic Move status
	local whiteUsed = snapshot.magicState.whiteUsed
	local blackUsed = snapshot.magicState.blackUsed
	self.whiteMagicLabel.Text = whiteUsed and "Magic: USED" or "Magic: READY"
	self.whiteMagicLabel.TextColor3 = whiteUsed and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(0, 255, 255)

	self.blackMagicLabel.Text = blackUsed and "Magic: USED" or "Magic: READY"
	self.blackMagicLabel.TextColor3 = blackUsed and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(0, 255, 255)

	-- Show Magic Move button if it's our turn and we haven't used it
	local myColorIsWhite = localPlayerColor == GameTypes.Colors.White
	self.magicMoveButton.Visible = isMyTurn and ((myColorIsWhite and not whiteUsed) or (not myColorIsWhite and not blackUsed))
end

function UIController:showChoiceModal(show: boolean)
	self.choiceModal.Visible = show
end

function UIController:showTypeSelectionModal(allowedTypes: { string }, onTypeSelected: (string) -> ())
	-- Clear any existing buttons
	for _, child in ipairs(self.typeSelectionModal:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	-- Create a button for each type
	for _, pieceType in ipairs(allowedTypes) do
		local btn = Instance.new("TextButton")
		btn.Name = pieceType .. "Button"
		btn.Size = UDim2.new(0, 80, 0, 50)
		btn.Text = pieceType
		btn.Parent = self.typeSelectionModal

		btn.MouseButton1Click:Connect(function()
			onTypeSelected(pieceType)
			self:hideTypeSelectionModal()
		end)
	end

	self.typeSelectionModal.Visible = true
end

function UIController:hideTypeSelectionModal()
	self.typeSelectionModal.Visible = false
end

function UIController:updateTooltip(visible: boolean, text: string?, position: UDim2?)
	self.tooltip.Visible = visible
	if text then
		self.tooltip.Text = text
	end
	if position then
		self.tooltip.Position = position
	end
end


--[=[
	Shows the end-of-game result screen.
]=]
function UIController:showResult(result: table, localPlayerColor: string)
	-- For MVP, just update the turn indicator text
	local resultText = "Game Over"
	if result.status == "Draw" then
		resultText = "Draw!"
	elseif result.winner == localPlayerColor then
		resultText = "You Win!"
		self.turnIndicator.TextColor3 = Color3.fromRGB(0, 255, 0)
	else
		resultText = "You Lose!"
		self.turnIndicator.TextColor3 = Color3.fromRGB(255, 50, 50)
	end
	self.turnIndicator.Text = resultText
end

function UIController:showToast(message: string)
	local toast = Instance.new("TextLabel")
	toast.Name = "ToastMessage"
	toast.Size = UDim2.new(0.5, 0, 0, 50)
	toast.Position = UDim2.new(0.25, 0, -0.1, 0)
	toast.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
	toast.TextColor3 = Color3.fromRGB(255, 255, 255)
	toast.Font = Enum.Font.SourceSansBold
	toast.Text = message
	toast.Parent = self.screenGui

	game:GetService("TweenService"):Create(toast, TweenInfo.new(0.5), { Position = UDim2.new(0.25, 0, 0.1, 0) }):Play()

	delay(3, function()
		game:GetService("TweenService"):Create(toast, TweenInfo.new(0.5), { Position = UDim2.new(0.25, 0, -0.1, 0) }):Play()
		delay(0.5, function()
			toast:Destroy()
		end)
	end)
end

--[=[
	Cleans up the UI.
]=]
function UIController:destroy()
	if self.screenGui then
		self.screenGui:Destroy()
	end
end

return UIController
