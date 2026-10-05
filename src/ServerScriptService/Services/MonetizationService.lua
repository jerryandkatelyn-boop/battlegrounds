--!strict
local Players=game:GetService("Players")
local MarketplaceService=game:GetService("MarketplaceService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local Config=require(ReplicatedStorage.Shared.MonetizationConfig)
local Service={}
local ProfileService
local productById={}

local function refreshPasses(player)
	for _,pass in pairs(Config.Passes) do
		if type(pass.Id)=="number" and pass.Id>0 then
			task.spawn(function()
				local ok,owns=pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId,pass.Id)
				end)
				if ok then player:SetAttribute(pass.Attribute,owns==true) end
			end)
		else
			player:SetAttribute(pass.Attribute,false)
		end
	end
end

function Service:Init(profile)
	ProfileService=profile
	for _,product in pairs(Config.Products) do
		if type(product.Id)=="number" and product.Id>0 then productById[product.Id]=product end
	end
end

function Service:Start()
	Players.PlayerAdded:Connect(refreshPasses)
	for _,player in ipairs(Players:GetPlayers()) do refreshPasses(player) end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player,passId,purchased)
		if not purchased then return end
		for _,pass in pairs(Config.Passes) do
			if pass.Id==passId then
				player:SetAttribute(pass.Attribute,true)
				break
			end
		end
	end)

	MarketplaceService.ProcessReceipt=function(receipt)
		local product=productById[receipt.ProductId]
		if not product then
			warn("[Shatterbound] Unknown developer product receipt:",receipt.ProductId)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local player=Players:GetPlayerByUserId(receipt.PlayerId)
		if not player or not ProfileService:Get(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		ProfileService:AddCoins(player,product.Coins)
		ProfileService:Push(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return Service
