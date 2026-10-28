-- Roblox marketplace integration. Cash products are durably recorded together
-- with their receipt IDs before ProcessReceipt acknowledges the purchase.
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local MonetizationService = {}

local profileStore = DataStoreService:GetDataStore("MedievalTycoon_Economy_v1")
local productsById = {}
local passesById = {}
local profiles = {}
local locks = {}
local saveScheduled = {}
local registeredPlayers = setmetatable({}, { __mode = "k" })
local initialized = false
local MAX_CASH = 2000000000

for _, product in ipairs(ShopConfig.Products) do
	if product.Id > 0 then productsById[product.Id] = product end
end
for _, pass in ipairs(ShopConfig.Passes) do
	if pass.Id > 0 then passesById[pass.Id] = pass end
end

local function keyFor(userId)
	return "Player_" .. tostring(userId)
end

local function normalizeProfile(raw)
	local profile = typeof(raw) == "table" and raw or {}
	local cash = tonumber(profile.Cash)
	profile.Cash = cash and math.clamp(math.floor(cash), 0, MAX_CASH) or Config.StartingCash
	profile.Receipts = typeof(profile.Receipts) == "table" and profile.Receipts or {}
	return profile
end

local function withUserLock(userId, callback)
	while locks[userId] do task.wait() end
	locks[userId] = true
	local ok, result = pcall(callback)
	locks[userId] = nil
	return ok, result
end

local function saveCash(player, cashValue)
	if not profiles[player] then return false end
	local ok, result = withUserLock(player.UserId, function()
		return profileStore:UpdateAsync(keyFor(player.UserId), function(raw)
			local profile = normalizeProfile(raw)
			profile.Cash = math.clamp(math.floor(cashValue), 0, MAX_CASH)
			return profile
		end)
	end)
	if not ok then
		warn(string.format("[Monetization] Could not save Cash for %d: %s", player.UserId, tostring(result)))
		return false
	end
	profiles[player] = normalizeProfile(result)
	return true
end

local function scheduleSave(player, cash)
	if saveScheduled[player] or not profiles[player] then return end
	saveScheduled[player] = true
	task.delay(12, function()
		saveScheduled[player] = nil
		if player.Parent == Players and cash.Parent then saveCash(player, cash.Value) end
	end)
end

local function loadEconomy(player, cash)
	if registeredPlayers[player] then return end
	registeredPlayers[player] = true
	player:SetAttribute("EconomyReady", false)
	player:SetAttribute("MonetizationReady", false)

	if RunService:IsStudio() then
		player:SetAttribute("EconomyReady", true)
		return
	end

	task.spawn(function()
		local lastError
		for attempt = 1, 6 do
			if player.Parent ~= Players then return end
			local ok, raw = pcall(function()
				return profileStore:GetAsync(keyFor(player.UserId))
			end)
			if ok then
				local profile = normalizeProfile(raw)
				profiles[player] = profile
				cash.Value = profile.Cash
				player:SetAttribute("EconomyReady", true)
				player:SetAttribute("MonetizationReady", true)
				cash.Changed:Connect(function(value) scheduleSave(player, cash) end)
				return
			end
			lastError = raw
			task.wait(math.min(attempt * 2, 10))
		end
		if player.Parent == Players then
			-- Keep the game playable during a Roblox data outage; Robux gold packs
			-- stay unavailable until a profile loads and can safely receive receipts.
			player:SetAttribute("EconomyReady", true)
			warn(string.format("[Monetization] Profile load unavailable for %d: %s", player.UserId, tostring(lastError)))
		end
	end)
end

local function grantDeveloperProduct(receiptInfo)
	local product = productsById[receiptInfo.ProductId]
	if not product then
		warn(string.format("[Monetization] No configured product for developer product ID %d", receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player or not profiles[player] or player:GetAttribute("MonetizationReady") ~= true then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local cash = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
	if not cash or not cash:IsA("IntValue") then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local receiptKey = tostring(receiptInfo.PurchaseId)
	local wasNewReceipt = false
	local ok, updated = withUserLock(player.UserId, function()
		return profileStore:UpdateAsync(keyFor(player.UserId), function(raw)
			local profile = normalizeProfile(raw)
			if profile.Receipts[receiptKey] == true then
				wasNewReceipt = false
				return profile
			end
			profile.Receipts[receiptKey] = true
			profile.Cash = math.min(MAX_CASH, profile.Cash + product.Amount)
			wasNewReceipt = true
			return profile
		end)
	end)
	if not ok or typeof(updated) ~= "table" then
		warn(string.format("[Monetization] Receipt save failed for %s: %s", receiptKey, tostring(updated)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	profiles[player] = normalizeProfile(updated)
	if wasNewReceipt then
		cash.Value = math.min(MAX_CASH, cash.Value + product.Amount)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function setRoyalStyle(player, enabled)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not character then return end
	local oldHighlight = character:FindFirstChild("RoyalStyleHighlight")
	local oldTag = head and head:FindFirstChild("RoyalStyleTag")
	if oldHighlight then oldHighlight:Destroy() end
	if oldTag then oldTag:Destroy() end
	if not enabled then return end

	local highlight = Instance.new("Highlight")
	highlight.Name = "RoyalStyleHighlight"
	highlight.Adornee = character
	highlight.FillColor = Color3.fromRGB(255, 196, 75)
	highlight.FillTransparency = 0.88
	highlight.OutlineColor = Color3.fromRGB(255, 214, 119)
	highlight.OutlineTransparency = 0.18
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character
	if head then
		local tag = Instance.new("BillboardGui")
		tag.Name = "RoyalStyleTag"
		tag.Adornee = head
		tag.Size = UDim2.fromOffset(150, 28)
		tag.StudsOffset = Vector3.new(0, 2.9, 0)
		tag.MaxDistance = 70
		tag.AlwaysOnTop = false
		tag.Parent = head
		local label = Instance.new("TextLabel")
		label.Name = "Title"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.Text = "✦  ROYAL PATRON  ✦"
		label.TextColor3 = Color3.fromRGB(255, 215, 121)
		label.TextStrokeColor3 = Color3.fromRGB(45, 32, 16)
		label.TextStrokeTransparency = 0.25
		label.TextSize = 12
		label.Parent = tag
	end
end

local function applyPass(player, pass, ownsPass)
	player:SetAttribute(pass.Attribute, ownsPass)
	if pass.Key == "RoyalStyle" then setRoyalStyle(player, ownsPass) end
end

local function checkPasses(player)
	for _, pass in ipairs(ShopConfig.Passes) do
		if pass.Id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and player.Parent == Players then applyPass(player, pass, owns) end
		end
	end
end

function MonetizationService.RegisterPlayer(player, cash)
	loadEconomy(player, cash)
	if player:GetAttribute("EconomyReady") == nil then player:SetAttribute("EconomyReady", false) end
	if player:GetAttribute("OwnsPass_DoubleGold") == nil then player:SetAttribute("OwnsPass_DoubleGold", false) end
	if player:GetAttribute("OwnsPass_RoyalStyle") == nil then player:SetAttribute("OwnsPass_RoyalStyle", false) end
	player.CharacterAdded:Connect(function()
		task.defer(function()
			if player.Parent == Players and player:GetAttribute("OwnsPass_RoyalStyle") then setRoyalStyle(player, true) end
		end)
	end)
	if initialized then task.spawn(checkPasses, player) end
end

function MonetizationService.Initialize()
	if initialized then return end
	initialized = true
	MarketplaceService.ProcessReceipt = grantDeveloperProduct
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = passesById[passId]
		if purchased and pass then task.spawn(checkPasses, player) end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local cash = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
		if cash and profiles[player] then saveCash(player, cash.Value) end
		profiles[player] = nil
		saveScheduled[player] = nil
		registeredPlayers[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(checkPasses, player) end
	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			local cash = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
			if cash and profiles[player] then
				pending += 1
				task.spawn(function()
					saveCash(player, cash.Value)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do task.wait(0.1) end
	end)
end

return MonetizationService
