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

local old=ReplicatedStorage:FindFirstChild(Config.RemoteFolderName)
if old then old:Destroy() end
local folder=Instance.new("Folder") folder.Name=Config.RemoteFolderName folder.Parent=ReplicatedStorage
local remotes={}
for _,name in ipairs({"Action","State","FX","Meta","Private"}) do
	local r=Instance.new("RemoteEvent") r.Name=name r.Parent=folder remotes[name]=r
end

local arena=ArenaService:Build()
LeaderboardService:Start(arena)
ProfileService:Init(remotes.State)
ProfileService:Start()
CombatService:Init(ProfileService,ArenaService,LeaderboardService,remotes)
CombatService:Start()

remotes.Meta.OnServerEvent:Connect(function(player,action,payload)
	if type(action)~="string" or #action>32 then return end
	if action=="ClaimDaily" then
		local ok,message=ProfileService:ClaimDaily(player)
		remotes.State:FireClient(player,"Toast",message,ok)
	elseif action=="SelectCharacter" and type(payload)=="string" and #payload<=32 then
		ProfileService:SelectCharacter(player,payload)
	elseif action=="RequestProfile" then
		ProfileService:Push(player)
	end
end)

local function markOwner(player)
	player:SetAttribute("PrivateServerOwner",game.PrivateServerOwnerId~=0 and player.UserId==game.PrivateServerOwnerId)
end
Players.PlayerAdded:Connect(markOwner)
for _,p in ipairs(Players:GetPlayers()) do markOwner(p) end

print(("[Shatterbound] server boot complete v%s"):format(Config.Version))
