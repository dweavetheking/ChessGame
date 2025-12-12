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
local RankConfig = require(Shared.RankConfig)

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

	-- Check Indicator
	self.checkIndicator = Instance.new("TextLabel")
	self.checkIndicator.Name = "CheckIndicator"
	self.checkIndicator.Size = UDim2.new(0.2, 0, 0, 30)
	self.checkIndicator.Position = UDim2.new(0.4, 0, 0.7, 0)
	self.checkIndicator.Font = Enum.Font.SourceSansBold
	self.checkIndicator.TextColor3 = Color3.fromRGB(255, 0, 0)
	self.checkIndicator.Text = "CHECK!"
	self.checkIndicator.Visible = false
	self.checkIndicator.BackgroundTransparency = 1
	self.checkIndicator.Parent = mainFrame

	-- Resign Button
	self.resignButton = Instance.new("TextButton")
	self.resignButton.Name = "ResignButton"
	self.resignButton.Size = UDim2.new(0.1, 0, 0, 30)
	self.resignButton.Position = UDim2.new(0.88, 0, 0.1, 0)
	self.resignButton.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
	self.resignButton.Font = Enum.Font.SourceSansBold
	self.resignButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.resignButton.Text = "Resign"
	self.resignButton.Parent = mainFrame

	-- AI Match Button
	self.aiMatchButton = Instance.new("TextButton")
	self.aiMatchButton.Name = "AIMatchButton"
	self.aiMatchButton.Size = UDim2.new(0.15, 0, 0, 30)
	self.aiMatchButton.Position = UDim2.new(0.7, 0, 0.1, 0)
	self.aiMatchButton.BackgroundColor3 = Color3.fromRGB(30, 150, 30)
	self.aiMatchButton.Font = Enum.Font.SourceSansBold
	self.aiMatchButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.aiMatchButton.Text = "Play vs AI"
	self.aiMatchButton.Parent = mainFrame

	-- Quick Match Button
	self.quickMatchButton = Instance.new("TextButton")
	self.quickMatchButton.Name = "QuickMatchButton"
	self.quickMatchButton.Size = UDim2.new(0.15, 0, 0, 30)
	self.quickMatchButton.Position = UDim2.new(0.5, 0, 0.1, 0)
	self.quickMatchButton.BackgroundColor3 = Color3.fromRGB(30, 30, 150)
	self.quickMatchButton.Font = Enum.Font.SourceSansBold
	self.quickMatchButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.quickMatchButton.Text = "Quick Match"
	self.quickMatchButton.Parent = mainFrame

	-- Profile Button
	self.profileButton = Instance.new("TextButton")
	self.profileButton.Name = "ProfileButton"
	self.profileButton.Size = UDim2.new(0.1, 0, 0, 30)
	self.profileButton.Position = UDim2.new(0.02, 0, 0.1, 0)
	self.profileButton.Text = "Profile"
	self.profileButton.Parent = mainFrame


	-- Magic Move Choice Modal
	self:_createChoiceModal()
	self:_createTypeSelectionModal()
	self:_createEndGameModal()
	self:_createProfilePanel()
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
	-- Update player names and ratings
	local whiteProfile = snapshot.profiles.White
	local blackProfile = snapshot.profiles.Black
	self.whitePlayerLabel.Text = `White: {snapshot.players.White} ({whiteProfile.elo} {whiteProfile.tier.Name})`
	self.blackPlayerLabel.Text = `Black: {snapshot.players.Black} ({blackProfile.elo} {blackProfile.tier.Name})`

	-- Update turn indicator and Magic Move button visibility
	local isMyTurn = snapshot.activeColor == localPlayerColor
	if snapshot.status ~= "InProgress" then
		self.turnIndicator.Text = snapshot.status
		self.magicMoveButton.Visible = false
	elseif isMyTurn then
		self.turnIndicator.Text = "Your Turn"
		self.turnIndicator.TextColor3 = Color3.fromRGB(0, 255, 0)
	else
		if snapshot.aiProfile then
			self.turnIndicator.Text = "AI is thinking..."
		else
			self.turnIndicator.Text = "Opponent's Turn"
		end
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

	-- Show check indicator
	self.checkIndicator.Visible = snapshot.isCheck

	-- Update profile panel
	local myProfile = (localPlayerColor == GameTypes.Colors.White) and whiteProfile or blackProfile
	if myProfile then
		self.profileEloLabel.Text = `Elo: {myProfile.elo}`
		self.profileTierLabel.Text = `Tier: {myProfile.tier.Name}`
		self.profileStatsLabel.Text = `W/L: {myProfile.totalWins or 0} / {myProfile.totalLosses or 0}`
	end
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
function UIController:showResult(result: table, localPlayerColor: string, oldElo: number, newElo: number)
	local resultText = "Game Over"
	if result.status:find("Draw") then
		resultText = "Draw!"
	elseif result.winner == localPlayerColor then
		resultText = "You Win!"
	else
		resultText = "You Lose!"
	end

	self.endGameModal.ResultText.Text = resultText
	self.endGameModal.EloChangeText.Text = `Elo: {oldElo} → {newElo}`
	self.endGameModal.Visible = true
end

function UIController:_createProfilePanel()
	local panel = Instance.new("Frame")
	panel.Name = "ProfilePanel"
	panel.Size = UDim2.new(0.3, 0, 0.5, 0)
	panel.Position = UDim2.new(0.35, 0, 0.25, 0)
	panel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	panel.BorderColor3 = Color3.fromRGB(255, 255, 255)
	panel.BorderSizePixel = 2
	panel.Visible = false
	panel.Parent = self.screenGui
	self.profilePanel = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Text = "Player Profile"
	title.Parent = panel

	local eloLabel = Instance.new("TextLabel")
	eloLabel.Name = "EloLabel"
	eloLabel.Size = UDim2.new(1, 0, 0, 30)
	eloLabel.Position = UDim2.new(0, 0, 0.2, 0)
	eloLabel.Parent = panel
	self.profileEloLabel = eloLabel

	local tierLabel = Instance.new("TextLabel")
	tierLabel.Name = "TierLabel"
	tierLabel.Size = UDim2.new(1, 0, 0, 30)
	tierLabel.Position = UDim2.new(0, 0, 0.3, 0)
	tierLabel.Parent = panel
	self.profileTierLabel = tierLabel

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.Size = UDim2.new(1, 0, 0, 30)
	statsLabel.Position = UDim2.new(0, 0, 0.4, 0)
	statsLabel.Parent = panel
	self.profileStatsLabel = statsLabel

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0.3, 0, 0, 30)
	closeButton.Position = UDim2.new(0.35, 0, 0.8, 0)
	closeButton.Text = "Close"
	closeButton.Parent = panel
	closeButton.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	self.profileButton.MouseButton1Click:Connect(function()
		panel.Visible = true
	end)
end

function UIController:_createEndGameModal()
	local modal = Instance.new("Frame")
	modal.Name = "EndGameModal"
	modal.Size = UDim2.new(0.5, 0, 0.4, 0)
	modal.Position = UDim2.new(0.25, 0, 0.3, 0)
	modal.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	modal.BorderColor3 = Color3.fromRGB(255, 255, 255)
	modal.BorderSizePixel = 2
	modal.Visible = false
	modal.Parent = self.screenGui
	self.endGameModal = modal

	local title = Instance.new("TextLabel")
	title.Name = "ResultText"
	title.Size = UDim2.new(1, 0, 0.4, 0)
	title.Font = Enum.Font.SourceSansBold
	title.TextColor3 = Color3.fromRGB(255, 255, 25_5)
	title.TextSize = 48
	title.Text = "You Win!"
	title.Parent = modal

	local eloChange = Instance.new("TextLabel")
	eloChange.Name = "EloChangeText"
	eloChange.Size = UDim2.new(1, 0, 0, 30)
	eloChange.Position = UDim2.new(0, 0, 0.5, 0)
	eloChange.Font = Enum.Font.SourceSans
	eloChange.TextColor3 = Color3.fromRGB(200, 200, 200)
	eloChange.Text = "Elo: 1200 -> 1215"
	eloChange.Parent = modal
	self.endGameModal.EloChangeText = eloChange

	local backButton = Instance.new("TextButton")
	backButton.Name = "BackButton"
	backButton.Size = UDim2.new(0.6, 0, 0, 50)
	backButton.Position = UDim2.new(0.2, 0, 0.7, 0)
	backButton.Text = "Back to Lobby"
	backButton.Parent = modal
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
	self.screenGui = nil
end

return UIController
