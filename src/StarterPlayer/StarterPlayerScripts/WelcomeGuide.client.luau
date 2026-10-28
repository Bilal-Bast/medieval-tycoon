-- A compact, dismissible guide explains the first useful action and adapts as
-- players claim a realm and advance through the kingdom upgrade path.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local dismissed = false

local function formatGold(value)
	local text = tostring(math.floor(value))
	while true do
		local updated, replacements = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		text = updated
		if replacements == 0 then return text end
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = "WelcomeGuide"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 3
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "GuideCard"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.45, 0, 0, -100)
panel.Size = UDim2.new(0.9, 0, 0, 80)
panel.BackgroundColor3 = Color3.fromRGB(34, 29, 25)
panel.BackgroundTransparency = 0.06
panel.BorderSizePixel = 0
panel.Visible = true
panel.Parent = gui

local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MinSize = Vector2.new(290, 80)
sizeLimit.MaxSize = Vector2.new(460, 80)
sizeLimit.Parent = panel
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel
local border = Instance.new("UIStroke")
border.Color = Color3.fromRGB(228, 177, 79)
border.Thickness = 1.6
border.Transparency = 0.12
border.Parent = panel
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(51, 39, 29)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(29, 37, 36)),
})
gradient.Rotation = 8
gradient.Parent = panel

local accent = Instance.new("Frame")
accent.Name = "Accent"
accent.Position = UDim2.fromOffset(0, 10)
accent.Size = UDim2.new(0, 4, 1, -20)
accent.BackgroundColor3 = Color3.fromRGB(241, 187, 84)
accent.BorderSizePixel = 0
accent.Parent = panel
local accentCorner = Instance.new("UICorner")
accentCorner.CornerRadius = UDim.new(1, 0)
accentCorner.Parent = accent

local step = Instance.new("TextLabel")
step.Name = "Step"
step.Position = UDim2.fromOffset(18, 7)
step.Size = UDim2.new(1, -62, 0, 16)
step.BackgroundTransparency = 1
step.Font = Enum.Font.GothamBold
step.TextColor3 = Color3.fromRGB(245, 194, 102)
step.TextSize = 10
step.TextXAlignment = Enum.TextXAlignment.Left
step.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromOffset(18, 21)
title.Size = UDim2.new(1, -62, 0, 24)
title.BackgroundTransparency = 1
title.Font = Enum.Font.Garamond
title.TextColor3 = Color3.fromRGB(255, 246, 223)
title.TextSize = 20
title.TextTruncate = Enum.TextTruncate.AtEnd
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local detail = Instance.new("TextLabel")
detail.Name = "Detail"
detail.Position = UDim2.fromOffset(19, 48)
detail.Size = UDim2.new(1, -34, 0, 23)
detail.BackgroundTransparency = 1
detail.Font = Enum.Font.Gotham
detail.TextColor3 = Color3.fromRGB(216, 207, 186)
detail.TextSize = 12
detail.TextTruncate = Enum.TextTruncate.AtEnd
detail.TextXAlignment = Enum.TextXAlignment.Left
detail.Parent = panel

local close = Instance.new("TextButton")
close.Name = "Dismiss"
close.Position = UDim2.new(1, -34, 0, 6)
close.Size = UDim2.fromOffset(26, 26)
close.BackgroundColor3 = Color3.fromRGB(68, 53, 39)
close.BackgroundTransparency = 0.12
close.BorderSizePixel = 0
close.Font = Enum.Font.GothamBold
close.Text = "×"
close.TextColor3 = Color3.fromRGB(255, 236, 199)
close.TextSize = 20
close.AutoButtonColor = true
close.Parent = panel
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 7)
closeCorner.Parent = close

local function refresh()
	if dismissed then return end
	local realm = player:GetAttribute("TycoonId")
	local nextName = player:GetAttribute("NextUpgradeName")
	local nextCost = player:GetAttribute("NextUpgradeCost")
	local hasWeapon = player:GetAttribute("OwnsWeapon_KnightSword")
		or player:GetAttribute("OwnsWeapon_ForceLaser")
		or player:GetAttribute("OwnsWeapon_PlasmaSword")

	if typeof(realm) ~= "string" then
		step.Text = "STEP 1 OF 3   •   CLAIM"
		title.Text = "Your kingdom is waiting"
		detail.Text = "Touch a gold realm seal to claim your castle and start building."
	elseif typeof(nextName) == "string" and typeof(nextCost) == "number" then
		step.Text = "STEP 2 OF 3   •   BUILD"
		title.Text = "Next: " .. nextName
		detail.Text = string.format("Follow the golden trail  •  %s gold  •  Your upgrades earn more.", formatGold(nextCost))
		if not hasWeapon then
			detail.Text ..= "  Zombies lurk by the plaza!"
		end
	else
		step.Text = "STEP 3 OF 3   •   PROSPER"
		title.Text = "A realm worthy of a ruler"
		detail.Text = "Grow your prosperity, gear up, and defeat plaza zombies for bonus gold."
	end
end

local function watchAttribute(name)
	player:GetAttributeChangedSignal(name):Connect(refresh)
end
for _, name in ipairs({ "TycoonId", "NextUpgradeName", "NextUpgradeCost", "OwnsWeapon_KnightSword",
	"OwnsWeapon_ForceLaser", "OwnsWeapon_PlasmaSword" }) do
	watchAttribute(name)
end

close.Activated:Connect(function()
	dismissed = true
	TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.45, 0, 0, -100), BackgroundTransparency = 1,
	}):Play()
	task.delay(0.24, function()
		if gui.Parent then gui.Enabled = false end
	end)
end)

refresh()
TweenService:Create(panel, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
	Position = UDim2.new(0.45, 0, 0, 4),
}):Play()
