-- Player-facing Robux shop. Roblox owns the checkout and price display.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local COLORS = {
	ink = Color3.fromRGB(29, 25, 35), panel = Color3.fromRGB(44, 37, 49), card = Color3.fromRGB(59, 48, 59),
	gold = Color3.fromRGB(245, 184, 72), cream = Color3.fromRGB(255, 240, 210), muted = Color3.fromRGB(194, 180, 160),
	green = Color3.fromRGB(85, 154, 99), red = Color3.fromRGB(174, 91, 73),
}

local function make(className, properties, parent)
	local instance = Instance.new(className)
	for key, value in pairs(properties) do instance[key] = value end
	instance.Parent = parent
	return instance
end

local function round(parent, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, parent)
end

local gui = make("ScreenGui", {
	Name = "KingdomShop", ResetOnSpawn = false, IgnoreGuiInset = false,
	DisplayOrder = 8, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))

local openButton = make("TextButton", {
	Name = "OpenShop", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 76),
	Size = UDim2.fromOffset(144, 46), BackgroundColor3 = COLORS.ink, Text = "✦  ROYAL SHOP",
	TextColor3 = COLORS.cream, Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = true,
}, gui)
round(openButton, 12)
make("UIStroke", { Color = COLORS.gold, Thickness = 2, Transparency = 0.12 }, openButton)

local panel = make("Frame", {
	Name = "ShopPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.51),
	Size = UDim2.new(0.92, 0, 0.78, 0), BackgroundColor3 = COLORS.panel,
	Visible = false, ClipsDescendants = true,
}, gui)
make("UISizeConstraint", { MinSize = Vector2.new(300, 360), MaxSize = Vector2.new(590, 590) }, panel)
round(panel, 18)
make("UIStroke", { Color = COLORS.gold, Thickness = 2, Transparency = 0.22 }, panel)

make("TextLabel", {
	Name = "Title", Position = UDim2.new(0, 22, 0, 14), Size = UDim2.new(1, -76, 0, 38),
	BackgroundTransparency = 1, Text = "THE ROYAL TREASURY", TextColor3 = COLORS.cream,
	Font = Enum.Font.GothamBlack, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left,
}, panel)
local close = make("TextButton", {
	Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12),
	Size = UDim2.fromOffset(38, 38), BackgroundColor3 = COLORS.card, Text = "×",
	TextColor3 = COLORS.cream, Font = Enum.Font.GothamBold, TextSize = 24,
}, panel)
round(close, 10)

local tabs = make("Frame", { Position = UDim2.new(0, 18, 0, 62), Size = UDim2.new(1, -36, 0, 42), BackgroundTransparency = 1 }, panel)
local function makeTab(text, x)
	local button = make("TextButton", {
		Position = UDim2.new(x, 0, 0, 0), Size = UDim2.new(0.5, -5, 1, 0),
		BackgroundColor3 = COLORS.card, Text = text, TextColor3 = COLORS.muted,
		Font = Enum.Font.GothamBold, TextSize = 13,
	}, tabs)
	round(button, 10)
	return button
end
local goldTab = makeTab("GOLD PACKS", 0)
local passesTab = makeTab("ROYAL PASSES", 0.5)

local status = make("TextLabel", {
	Name = "Status", Position = UDim2.new(0, 20, 1, -42), Size = UDim2.new(1, -40, 0, 24),
	BackgroundTransparency = 1, Text = "Roblox checkout • Purchases use Robux",
	TextColor3 = COLORS.muted, Font = Enum.Font.Gotham, TextSize = 11, TextWrapped = true,
}, panel)

local function makeList(name)
	local list = make("ScrollingFrame", {
		Name = name, Position = UDim2.new(0, 18, 0, 116), Size = UDim2.new(1, -36, 1, -166),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
		ScrollBarImageColor3 = COLORS.gold, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, panel)
	make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	make("UIPadding", { PaddingBottom = UDim.new(0, 5), PaddingRight = UDim.new(0, 4) }, list)
	return list
end
local goldList = makeList("GoldPacks")
local passList = makeList("Passes")

local function setStatus(message, color)
	status.Text = message
	status.TextColor3 = color or COLORS.muted
end

local function priceFor(id, infoType)
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, infoType)
	end)
	if ok and info and info.PriceInRobux then return "R$ " .. tostring(info.PriceInRobux) end
	return "VIEW IN ROBLOX"
end

local function addCard(list, item, isPass, order)
	local card = make("Frame", {
		Name = item.Key, Size = UDim2.new(1, -4, 0, 112), BackgroundColor3 = COLORS.card,
		LayoutOrder = order,
	}, list)
	round(card, 13)
	make("UIStroke", { Color = Color3.fromRGB(111, 91, 75), Thickness = 1, Transparency = 0.55 }, card)
	make("TextLabel", {
		Position = UDim2.new(0, 15, 0, 11), Size = UDim2.new(1, -148, 0, 24),
		BackgroundTransparency = 1, Text = item.Name, TextColor3 = COLORS.cream,
		Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	local detail = isPass and item.Description or (item.Description .. "  •  +" .. tostring(item.Amount) .. " gold")
	make("TextLabel", {
		Position = UDim2.new(0, 15, 0, 39), Size = UDim2.new(1, -148, 0, 53),
		BackgroundTransparency = 1, Text = detail, TextColor3 = COLORS.muted,
		Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, card)
	local button = make("TextButton", {
		Name = "Purchase", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -11, 0.5, 0),
		Size = UDim2.fromOffset(119, 42), BackgroundColor3 = item.Id > 0 and COLORS.green or COLORS.red,
		Text = item.Id > 0 and "LOADING…" or "SETUP NEEDED", TextColor3 = COLORS.cream,
		Font = Enum.Font.GothamBold, TextSize = 11, TextWrapped = true, AutoButtonColor = item.Id > 0,
	}, card)
	round(button, 10)

	local ownedAttribute = isPass and item.Attribute or nil
	local function refreshOwned()
		if isPass and player:GetAttribute(ownedAttribute) == true then
			button.Text = "OWNED  ✓"
			button.BackgroundColor3 = Color3.fromRGB(78, 92, 71)
			button.Active = false
			return true
		end
		return false
	end
	if item.Id > 0 then
		task.spawn(function()
			local price = priceFor(item.Id, isPass and Enum.InfoType.GamePass or Enum.InfoType.Product)
			if button.Parent then
				if not refreshOwned() then button.Text = price end
			end
		end)
	else
		button.Active = false
		button.BackgroundColor3 = Color3.fromRGB(111, 73, 67)
	end

	if isPass then
		player:GetAttributeChangedSignal(ownedAttribute):Connect(refreshOwned)
	end
	button.Activated:Connect(function()
		if item.Id <= 0 or refreshOwned() then return end
		if not isPass and player:GetAttribute("MonetizationReady") ~= true then
			setStatus("Your treasury is still loading. Try again in a moment.", COLORS.gold)
			return
		end
		local ok, err = pcall(function()
			if isPass then
				MarketplaceService:PromptGamePassPurchase(player, item.Id)
			else
				MarketplaceService:PromptProductPurchase(player, item.Id)
			end
		end)
		if not ok then
			warn("[Royal Shop] Could not open Roblox purchase prompt: " .. tostring(err))
			setStatus("Roblox could not open checkout. Please try again.", COLORS.red)
		else
			setStatus("Complete your purchase in Roblox's secure checkout.")
		end
	end)
end

for index, product in ipairs(ShopConfig.Products) do addCard(goldList, product, false, index) end
for index, pass in ipairs(ShopConfig.Passes) do addCard(passList, pass, true, index) end

local function selectTab(showGold)
	goldList.Visible = showGold
	passList.Visible = not showGold
	goldTab.BackgroundColor3 = showGold and COLORS.gold or COLORS.card
	goldTab.TextColor3 = showGold and COLORS.ink or COLORS.muted
	passesTab.BackgroundColor3 = showGold and COLORS.card or COLORS.gold
	passesTab.TextColor3 = showGold and COLORS.muted or COLORS.ink
	setStatus(showGold and "Roblox checkout • Purchases use Robux" or "Permanent benefits • Roblox checkout uses Robux")
end
selectTab(true)

openButton.Activated:Connect(function() panel.Visible = not panel.Visible end)
close.Activated:Connect(function() panel.Visible = false end)
goldTab.Activated:Connect(function() selectTab(true) end)
passesTab.Activated:Connect(function() selectTab(false) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Escape and panel.Visible then panel.Visible = false end
end)
