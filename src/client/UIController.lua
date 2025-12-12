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


--[=[
	Updates the HUD with the latest game state.
	@param snapshot The game state from the server.
	@param localPlayerColor The color of the local player.
]=]
function UIController:update(snapshot: table, localPlayerColor: string)
	-- Update player names
	self.whitePlayerLabel.Text = `White: {snapshot.players.White}`
	self.blackPlayerLabel.Text = `Black: {snapshot.players.Black}`

	-- Update turn indicator
	if snapshot.status ~= "InProgress" then
		self.turnIndicator.Text = snapshot.status
	elseif snapshot.activeColor == localPlayerColor then
		self.turnIndicator.Text = "Your Turn"
		self.turnIndicator.TextColor3 = Color3.fromRGB(0, 255, 0)
	else
		self.turnIndicator.Text = "Opponent's Turn"
		self.turnIndicator.TextColor3 = Color3.fromRGB(255, 255, 0)
	end

	-- Update Magic Move status
	self.whiteMagicLabel.Text = snapshot.magicState.whiteUsed and "Magic: USED" or "Magic: READY"
	self.whiteMagicLabel.TextColor3 = snapshot.magicState.whiteUsed and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(0, 255, 255)

	self.blackMagicLabel.Text = snapshot.magicState.blackUsed and "Magic: USED" or "Magic: READY"
	self.blackMagicLabel.TextColor3 = snapshot.magicState.blackUsed and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(0, 255, 255)
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

--[=[
	Cleans up the UI.
]=]
function UIController:destroy()
	if self.screenGui then
		self.screenGui:Destroy()
	end
end

return UIController
