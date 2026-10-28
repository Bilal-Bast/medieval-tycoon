local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local dots = {}
local targetPosition
local lastOrigin
local lastRouteAt = 0
local visibleCount = 0
local closeEnough = 10
local beaconRange = 260
local beaconParts = {}

local guideFolder = Instance.new("Folder")
guideFolder.Name = "LocalUpgradeGuidance"
guideFolder.Parent = Workspace

local screen = Instance.new("ScreenGui")
screen.Name = "NextUpgradeHUD"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "NextUpgradePanel"
panel.Position = UDim2.fromOffset(24, 100)
panel.Size = UDim2.fromOffset(320, 66)
panel.BackgroundColor3 = Color3.fromRGB(36, 27, 20)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screen

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

local header = Instance.new("TextLabel")
header.BackgroundTransparency = 1
header.Position = UDim2.fromOffset(10, 4)
header.Size = UDim2.new(1, -20, 0, 15)
header.Font = Enum.Font.GothamBold
header.Text = "NEXT UPGRADE"
header.TextColor3 = Color3.fromRGB(237, 177, 82)
header.TextSize = 11
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = panel

local details = Instance.new("TextLabel")
details.BackgroundTransparency = 1
details.Position = UDim2.fromOffset(10, 19)
details.Size = UDim2.new(1, -20, 0, 42)
details.Font = Enum.Font.GothamMedium
details.TextColor3 = Color3.fromRGB(255, 244, 218)
details.TextSize = 14
details.TextXAlignment = Enum.TextXAlignment.Left
details.TextYAlignment = Enum.TextYAlignment.Center
details.TextWrapped = true
details.Parent = panel

local function formatCurrency(value)
	local text = tostring(math.floor(value))
	local reversed = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return reversed:gsub("^,", "")
end

local function getDot(index)
	local marker = dots[index]
	if marker then return marker end
	local base = Instance.new("Part")
	base.Name = "TrailStone"
	base.Size = Vector3.new(2.8, 0.16, 2.8)
	base.Anchored = true
	base.CanCollide = false
	base.CanTouch = false
	base.CanQuery = false
	base.CastShadow = false
	base.Material = Enum.Material.Slate
	base.Color = Color3.fromRGB(75, 63, 45)
	base.Transparency = 0.08
	base.Parent = guideFolder
	local rune = Instance.new("Part")
	rune.Name = "TrailRune"
	rune.Size = Vector3.new(0.84, 0.08, 0.84)
	rune.Anchored = true
	rune.CanCollide = false
	rune.CanTouch = false
	rune.CanQuery = false
	rune.CastShadow = false
	rune.Material = Enum.Material.Neon
	rune.Color = Color3.fromRGB(255, 205, 48)
	rune.Transparency = 0.02
	rune.Parent = guideFolder
	marker = { Base = base, Rune = rune }
	dots[index] = marker
	return marker
end

local function makeBeaconPart(name, shape, size, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 1
	part.Parent = guideFolder
	table.insert(beaconParts, part)
	return part
end

local beam = makeBeaconPart("NextUpgradeBeam", Enum.PartType.Cylinder, Vector3.new(0.22, 5.2, 5.2), Color3.fromRGB(255, 194, 35))
local diamond = makeBeaconPart("NextUpgradeDiamond", Enum.PartType.Block, Vector3.new(2.2, 2.2, 2.2), Color3.fromRGB(255, 230, 95))
local beaconLight = Instance.new("PointLight")
beaconLight.Color = Color3.fromRGB(255, 194, 35)
beaconLight.Range = 34
beaconLight.Brightness = 2.5
beaconLight.Enabled = false
beaconLight.Parent = diamond

local function hideBeacon()
	for _, part in ipairs(beaconParts) do part.Transparency = 1 end
	beaconLight.Enabled = false
end

local function updateBeacon(target, distance)
	if distance > beaconRange or distance <= closeEnough then
		hideBeacon()
		return
	end
	local pulse = 0.5 + 0.5 * math.sin(os.clock() * 3.3)
	beam.CFrame = CFrame.new(target + Vector3.new(0, 0.16, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Transparency = 0.12 + pulse * 0.12
	diamond.Size = Vector3.new(2.0 + pulse * 0.32, 2.0 + pulse * 0.32, 2.0 + pulse * 0.32)
	diamond.CFrame = CFrame.new(target + Vector3.new(0, 5.5 + pulse * 0.45, 0)) * CFrame.Angles(0, math.rad(45 + os.clock() * 32), math.rad(45))
	diamond.Transparency = 0.02
	beaconLight.Enabled = true
end

local function hideTrail()
	visibleCount = 0
	for _, marker in ipairs(dots) do
		marker.Base.Transparency = 1
		marker.Rune.Transparency = 1
	end
end

local function rayToGround(point, character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, guideFolder }
	params.IgnoreWater = true
	local result = Workspace:Raycast(point + Vector3.new(0, 18, 0), Vector3.new(0, -60, 0), params)
	return result and result.Position.Y + 0.09 or point.Y + 0.15
end

local function samplePath(points, character)
	local samples = {}
	for segment = 1, #points - 1 do
		local startPoint = points[segment]
		local endPoint = points[segment + 1]
		local flatStart = Vector3.new(startPoint.X, 0, startPoint.Z)
		local flatEnd = Vector3.new(endPoint.X, 0, endPoint.Z)
		local delta = flatEnd - flatStart
		local steps = math.max(1, math.ceil(delta.Magnitude / 6))
		for step = 0, steps - 1 do
			local point = startPoint:Lerp(endPoint, step / steps)
			if #samples == 0 or (point - samples[#samples]).Magnitude >= 6 then
				table.insert(samples, Vector3.new(point.X, rayToGround(point, character), point.Z))
			end
			if #samples >= 48 then return samples end
		end
	end
	table.insert(samples, Vector3.new(points[#points].X, rayToGround(points[#points], character), points[#points].Z))
	return samples
end

local function updateRoute(root, target)
	local waypoints = { root.Position }
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 7,
	})
	local ok = pcall(function() path:ComputeAsync(root.Position, target) end)
	if ok and path.Status == Enum.PathStatus.Success then
		waypoints = {}
		for _, waypoint in ipairs(path:GetWaypoints()) do
			table.insert(waypoints, waypoint.Position)
		end
	else
		table.insert(waypoints, target)
	end

	local samples = samplePath(waypoints, root.Parent)
	visibleCount = #samples
	for index, position in ipairs(samples) do
		local marker = getDot(index)
		local nearTarget = index >= #samples - 3
		marker.Base.CFrame = CFrame.new(position)
		marker.Rune.CFrame = CFrame.new(position + Vector3.new(0, 0.13, 0)) * CFrame.Angles(0, math.rad(45), 0)
		marker.Base.Transparency = 0.025 + 0.012 * math.min(index, 8)
		marker.Rune.Color = nearTarget and Color3.fromRGB(255, 242, 135) or Color3.fromRGB(255, 205, 48)
		marker.Rune.Transparency = nearTarget and 0.01 or 0.08
	end
	for index = #samples + 1, #dots do
		dots[index].Base.Transparency = 1
		dots[index].Rune.Transparency = 1
	end
	lastOrigin = root.Position
	lastRouteAt = os.clock()
end

local function refreshHUD(character, target)
	local name = player:GetAttribute("NextUpgradeName")
	local cost = player:GetAttribute("NextUpgradeCost")
	if typeof(name) ~= "string" or typeof(cost) ~= "number" or not target then
		panel.Visible = false
		return
	end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local distance = root and math.floor((root.Position - target).Magnitude + 0.5) or nil
	details.Text = string.format("%s\n$%s%s", name, formatCurrency(cost), distance and string.format("   ·   %d studs", distance) or "")
	panel.Visible = true
end

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local target = player:GetAttribute("NextUpgradeTarget")
	if not root or typeof(target) ~= "Vector3" or not player:GetAttribute("NextUpgradeId") then
		targetPosition = nil
		lastOrigin = nil
		hideTrail()
		hideBeacon()
		refreshHUD(character, nil)
		return
	end

	refreshHUD(character, target)
	local distance = (root.Position - target).Magnitude
	updateBeacon(target, distance)
	if distance <= closeEnough then
		targetPosition = target
		hideTrail()
		return
	end

	local targetChanged = targetPosition == nil or (targetPosition - target).Magnitude > 1
	local playerMoved = lastOrigin == nil or (root.Position - lastOrigin).Magnitude > 5
	if targetChanged or playerMoved then targetPosition = target end
	if (targetChanged or playerMoved) and os.clock() - lastRouteAt >= 0.65 then
		updateRoute(root, target)
	end
end)

player:GetAttributeChangedSignal("NextUpgradeId"):Connect(function()
	targetPosition = nil
	lastOrigin = nil
	lastRouteAt = 0
	hideTrail()
end)

player:GetAttributeChangedSignal("NextUpgradeTarget"):Connect(function()
	targetPosition = nil
	lastOrigin = nil
	lastRouteAt = 0
	hideTrail()
end)

player.CharacterAdded:Connect(function()
	targetPosition = nil
	lastOrigin = nil
	lastRouteAt = 0
	hideTrail()
	hideBeacon()
end)
