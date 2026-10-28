local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local actionRemote = ReplicatedStorage:WaitForChild("WeaponAction")
local noticeRemote = ReplicatedStorage:WaitForChild("WeaponNotice")
local connectedTools = {}
local characterConnection
local backpackConnection

local function getAimPoint()
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local viewport = camera.ViewportSize
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
		return ray.Origin + ray.Direction * 200
	end
	local screenPoint = UserInputService:GetMouseLocation()
	local ray = camera:ScreenPointToRay(screenPoint.X, screenPoint.Y)
	return ray.Origin + ray.Direction * 200
end

local function connectTool(tool)
	if not tool:IsA("Tool") or connectedTools[tool] then return end
	local activated = tool.Activated:Connect(function()
		if tool.Parent ~= player.Character then return end
		local weaponId = tool:GetAttribute("WeaponId")
		if not weaponId then return end
		if tool:GetAttribute("WeaponKind") == "Ranged" then
			local aimPoint = getAimPoint()
			if aimPoint then actionRemote:FireServer(tool, aimPoint) end
		else
			local toolAnimation = Instance.new("StringValue")
			toolAnimation.Name = "toolanim"
			toolAnimation.Value = "Slash"
			toolAnimation.Parent = tool
			task.delay(0.3, function()
				if toolAnimation.Parent then toolAnimation:Destroy() end
			end)
			actionRemote:FireServer(tool)
		end
	end)
	connectedTools[tool] = activated
	tool.Destroying:Connect(function()
		if connectedTools[tool] then
			connectedTools[tool]:Disconnect()
			connectedTools[tool] = nil
		end
	end)
end

local function bindCharacter(character)
	if characterConnection then characterConnection:Disconnect() end
	for _, child in ipairs(character:GetChildren()) do connectTool(child) end
	characterConnection = character.ChildAdded:Connect(connectTool)
end

local function bindBackpack()
	local backpack = player:WaitForChild("Backpack")
	if backpackConnection then backpackConnection:Disconnect() end
	for _, child in ipairs(backpack:GetChildren()) do connectTool(child) end
	backpackConnection = backpack.ChildAdded:Connect(connectTool)
end

if player.Character then bindCharacter(player.Character) end
player.CharacterAdded:Connect(bindCharacter)
bindBackpack()
player.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then bindBackpack() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "WeaponNoticeUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.Name = "Notice"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0.12, -16)
panel.Size = UDim2.fromOffset(380, 54)
panel.BackgroundColor3 = Color3.fromRGB(37, 29, 22)
panel.BackgroundTransparency = 1
panel.Visible = false
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 9)
corner.Parent = panel
local outline = Instance.new("UIStroke")
outline.Name = "NoticeBorder"
outline.Color = Color3.fromRGB(210, 169, 83)
outline.Thickness = 1.6
outline.Transparency = 1
outline.Parent = panel
local label = Instance.new("TextLabel")
label.Name = "Message"
label.Size = UDim2.new(1, -24, 1, -10)
label.Position = UDim2.new(0, 12, 0, 5)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBold
label.TextColor3 = Color3.fromRGB(255, 238, 198)
label.TextSize = 16
label.TextWrapped = true
label.TextTransparency = 1
label.Parent = panel
local currentTween
local noticeCounter = 0

noticeRemote.OnClientEvent:Connect(function(message, kind)
	if typeof(message) ~= "string" then return end
	noticeCounter += 1
	local thisNotice = noticeCounter
	if currentTween then currentTween:Cancel() end
	label.Text = message
	outline.Color = kind == "Warning" and Color3.fromRGB(220, 105, 77) or Color3.fromRGB(210, 169, 83)
	panel.Visible = true
	currentTween = TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.12, 0), BackgroundTransparency = 0.04,
	})
	currentTween:Play()
	TweenService:Create(label, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
	TweenService:Create(outline, TweenInfo.new(0.15), { Transparency = 0.05 }):Play()
	task.delay(2.6, function()
		if thisNotice ~= noticeCounter then return end
		currentTween = TweenService:Create(panel, TweenInfo.new(0.2), {
			Position = UDim2.new(0.5, 0, 0.12, -12), BackgroundTransparency = 1,
		})
		currentTween:Play()
		TweenService:Create(label, TweenInfo.new(0.18), { TextTransparency = 1 }):Play()
		TweenService:Create(outline, TweenInfo.new(0.18), { Transparency = 1 }):Play()
		task.delay(0.22, function()
			if thisNotice == noticeCounter then panel.Visible = false end
		end)
	end)
end)
