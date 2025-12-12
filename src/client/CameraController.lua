--!strict
--[=[
	Manages the 3D camera for the game.
	@module CameraController
]=]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraController = {}
CameraController.__index = CameraController

local ORBIT_SPEED = 0.5
local ZOOM_SPEED = 10

--[=[
	Initializes the CameraController.
	@param boardAnchor CFrame The CFrame of the board to focus on.
]=]
function CameraController.new(boardAnchor: CFrame)
	local self = setmetatable({}, CameraController)

	self.camera = workspace.CurrentCamera
	self.boardAnchor = boardAnchor
	self.connections = {}

	-- Camera properties
	self.distance = 50
	self.pitch = -30
	self.yaw = 0

	self:_setDefaultCamera()
	self:_start()

	return self
end

function CameraController:_setDefaultCamera()
	self.camera.CameraType = Enum.CameraType.Scriptable
	self.camera.FieldOfView = 70
end

function CameraController:_updateCamera()
	local rotation = CFrame.Angles(math.rad(self.pitch), math.rad(self.yaw), 0)
	local position = self.boardAnchor.Position + rotation:VectorToWorldSpace(Vector3.new(0, 0, self.distance))
	self.camera.CFrame = CFrame.lookAt(position, self.boardAnchor.Position)
end

function CameraController:_start()
	-- Basic orbit controls
	local lastInputPos
	local isDragging = false

	self.connections.InputBegan = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			isDragging = true
			lastInputPos = input.Position
		end
	end)

	self.connections.InputEnded = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			isDragging = false
		end
	end)

	self.connections.InputChanged = UserInputService.InputChanged:Connect(function(input)
		if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - lastInputPos
			self.yaw -= delta.X * ORBIT_SPEED
			self.pitch = math.clamp(self.pitch - delta.Y * ORBIT_SPEED, -80, -10)
			lastInputPos = input.Position
		end
	end)

	self.connections.RenderStepped = RunService.RenderStepped:Connect(function()
		self:_updateCamera()
	end)
end

--[=[
	Plays a subtle camera shake/nudge effect for emphasis.
]=]
function CameraController:playEmphasis()
	local originalPitch = self.pitch
	local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
	local tween = TweenService:Create(self, tweenInfo, { pitch = originalPitch - 2 })
	tween:Play()
end

function CameraController:destroy()
	for _, conn in pairs(self.connections) do
		conn:Disconnect()
	end
	table.clear(self.connections)
	self.camera.CameraType = Enum.CameraType.Fixed
	self.camera = nil
end

return CameraController
