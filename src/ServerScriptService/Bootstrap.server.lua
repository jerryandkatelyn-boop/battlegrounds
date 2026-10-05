--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Shared=ReplicatedStorage:WaitForChild("Shared")
local Config=require(Shared.GameConfig)
local services=script.Parent:WaitForChild("Services")
local ProfileService=require(services.ProfileService)
local ArenaService=require(services.ArenaService)
local CombatService=require(services.CombatService)
local LeaderboardService=require(services.LeaderboardService)
local MonetizationService=require(services.MonetizationService)

Players.RespawnTime=3

local old=ReplicatedStorage:FindFirstChild(Config.RemoteFolderName)
if old then old:Destroy() end
local folder=Instance.new("Folder") folder.Name=Config.RemoteFolderName folder.Parent=ReplicatedStorage
local remotes={}
for _,name in ipairs({"Action","State","FX","Meta","Private"}) do
	local r=Instance.new("RemoteEvent") r.Name=name r.Parent=folder remotes[name]=r
end

local arena=ArenaService:Build()
local safeSpawn=arena:FindFirstChild("SafeSpawn")
local function configurePlayer(player)
	player:SetAttribute("PrivateServerOwner",game.PrivateServerOwnerId~=0 and player.UserId==game.PrivateServerOwnerId)
	if safeSpawn and safeSpawn:IsA("SpawnLocation") then player.RespawnLocation=safeSpawn end
end
Players.PlayerAdded:Connect(configurePlayer)
for _,p in ipairs(Players:GetPlayers()) do configurePlayer(p) end

LeaderboardService:Start(arena)
ProfileService:Init(remotes.State)
ProfileService:Start()
CombatService:Init(ProfileService,ArenaService,LeaderboardService,remotes)
CombatService:Start()

local metaLast={}
remotes.Meta.OnServerEvent:Connect(function(player,action,payload)
	if type(action)~="string" or #action>32 then return end
	local t=workspace:GetServerTimeNow()
	if t-(metaLast[player] or 0)<Config.RateLimits.Meta then return end
	metaLast[player]=t

	if action=="ClaimDaily" then
		local ok,message=ProfileService:ClaimDaily(player)
		remotes.State:FireClient(player,"Toast",message,ok)
	elseif action=="SelectCharacter" and type(payload)=="string" and #payload<=32 then
		ProfileService:SelectCharacter(player,payload)
	elseif action=="BuyCharacter" and type(payload)=="string" and #payload<=32 then
		local ok,message=ProfileService:PurchaseCharacter(player,payload)
		remotes.State:FireClient(player,"Toast",message,ok)
	elseif action=="RequestProfile" then
		ProfileService:Push(player)
	end
end)

Players.PlayerRemoving:Connect(function(player) metaLast[player]=nil end)
print(("[Shatterbound] server boot complete v%s"):format(Config.Version))
