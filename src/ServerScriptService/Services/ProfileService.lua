--!strict
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("GameConfig"))
local QuestConfig = require(Shared:WaitForChild("QuestConfig"))
local CharacterCatalog = require(Shared:WaitForChild("CharacterCatalog"))

local Service = {}
local STORE = DataStoreService:GetDataStore("ShatterboundProfiles_v1")
local profiles = {}
local stateRemote

local DEFAULT = {
	Schema=1,
	Stats={Kills=0,Deaths=0,PlayMinutes=0,BestStreak=0},
	Economy={Coins=0},
	Progression={Level=1,XP=0},
	Character={Selected=Config.DefaultCharacter,Owned={[Config.DefaultCharacter]=true}},
	Daily={LastClaimDay=-1,Streak=0},
	Quests={DailyKey=-1,WeeklyKey=-1,Daily={},Weekly={}},
}

local function copy(v)
	if type(v) ~= "table" then return v end
	local o = {}
	for k,x in pairs(v) do o[k]=copy(x) end
	return o
end

local function merge(a,b)
	local out=copy(a)
	if type(b)~="table" then return out end
	for k,v in pairs(b) do
		if type(v)=="table" and type(out[k])=="table" then out[k]=merge(out[k],v) else out[k]=v end
	end
	return out
end

local function dayKey() return math.floor(os.time()/86400) end
local function weekKey() return math.floor(os.time()/604800) end
local function xpNeeded(level) return 250 + math.max(0,level-1)*110 end

local function resetBucket(profile,name,defs)
	local bucket={}
	for _,q in ipairs(defs) do bucket[q.Id]={Progress=0,Complete=false} end
	profile.Quests[name]=bucket
end

local function ensureQuestResets(profile)
	local d,w=dayKey(),weekKey()
	if profile.Quests.DailyKey~=d then profile.Quests.DailyKey=d resetBucket(profile,"Daily",QuestConfig.Daily) end
	if profile.Quests.WeeklyKey~=w then profile.Quests.WeeklyKey=w resetBucket(profile,"Weekly",QuestConfig.Weekly) end
end

function Service:Init(remote) stateRemote=remote end
function Service:Get(player) return profiles[player] end

function Service:Push(player)
	local p=profiles[player]
	if p and stateRemote then stateRemote:FireClient(player,"Profile",copy(p)) end
end

function Service:AddXP(player,amount)
	local p=profiles[player]
	if not p then return end
	p.Progression.XP += math.max(0,math.floor(amount))
	while p.Progression.XP >= xpNeeded(p.Progression.Level) do
		p.Progression.XP -= xpNeeded(p.Progression.Level)
		p.Progression.Level += 1
		p.Economy.Coins += 75
		if stateRemote then stateRemote:FireClient(player,"Announcement",("LEVEL %d"):format(p.Progression.Level)) end
	end
	local ls=player:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Level") then ls.Level.Value=p.Progression.Level end
end

function Service:AddCoins(player,amount)
	local p=profiles[player]
	if p then p.Economy.Coins += math.max(0,math.floor(amount)) end
end

function Service:ProgressQuest(player,eventName,amount)
	local p=profiles[player]
	if not p then return end
	ensureQuestResets(p)
	for _,group in ipairs({{"Daily",QuestConfig.Daily},{"Weekly",QuestConfig.Weekly}}) do
		for _,info in ipairs(group[2]) do
			if info.Event==eventName then
				local q=p.Quests[group[1]][info.Id]
				if q and not q.Complete then
					q.Progress=math.min(info.Goal,q.Progress+amount)
					if q.Progress>=info.Goal then
						q.Complete=true
						p.Economy.Coins += info.Coins
						self:AddXP(player,info.XP)
						if stateRemote then stateRemote:FireClient(player,"Announcement",string.upper(group[1]).." QUEST COMPLETE") end
					end
				end
			end
		end
	end
end

function Service:AddKill(player,streak)
	local p=profiles[player]
	if not p then return end
	p.Stats.Kills += 1
	p.Stats.BestStreak=math.max(p.Stats.BestStreak,streak)
	p.Economy.Coins += Config.Rewards.KillCoins
	self:AddXP(player,Config.Rewards.KillXP)
	self:ProgressQuest(player,"Kills",1)
	self:Push(player)
end

function Service:AddDeath(player)
	local p=profiles[player]
	if p then p.Stats.Deaths += 1 self:Push(player) end
end

function Service:ClaimDaily(player)
	local p=profiles[player]
	if not p then return false,"Profile unavailable" end
	local today=dayKey()
	if p.Daily.LastClaimDay==today then return false,"Already claimed today" end
	p.Daily.Streak = p.Daily.LastClaimDay==today-1 and math.clamp(p.Daily.Streak+1,1,7) or 1
	p.Daily.LastClaimDay=today
	local rewards={100,125,150,200,250,325,500}
	local coins=rewards[p.Daily.Streak] or 100
	p.Economy.Coins += coins
	self:AddXP(player,100+p.Daily.Streak*20)
	self:Push(player)
	return true,("Daily reward: +%d coins"):format(coins)
end

function Service:SelectCharacter(player,id)
	local p=profiles[player]
	if not p or type(id)~="string" or p.Character.Owned[id]~=true then return false end
	p.Character.Selected=id
	player:SetAttribute("SelectedCharacter",id)
	self:Push(player)
	return true
end

function Service:PurchaseCharacter(player,id)
	local p=profiles[player]
	local info=type(id)=="string" and CharacterCatalog[id] or nil
	if not p or not info then return false,"Unknown fighter" end
	if p.Character.Owned[id] then return false,"Already owned" end
	local price=math.max(0,tonumber(info.Price) or 0)
	if p.Economy.Coins<price then return false,"Not enough coins" end
	p.Economy.Coins-=price
	p.Character.Owned[id]=true
	self:Push(player)
	return true,("Unlocked %s"):format(info.DisplayName or id)
end

function Service:Save(player)
	local p=profiles[player]
	if not p then return false end
	local snapshot=copy(p)
	local ok,err=pcall(function()
		STORE:UpdateAsync("u_"..player.UserId,function() return snapshot end)
	end)
	if not ok then warn("[Shatterbound] save failed",player.Name,err) end
	return ok
end

function Service:Load(player)
	if profiles[player] then return end
	local loaded
	local ok,err=pcall(function() loaded=STORE:GetAsync("u_"..player.UserId) end)
	if not ok then warn("[Shatterbound] load failed; session profile used",player.Name,err) end
	local p=merge(DEFAULT,loaded)
	ensureQuestResets(p)
	profiles[player]=p
	player:SetAttribute("SelectedCharacter",p.Character.Selected)
	player:SetAttribute("Ultimate",0)
	player:SetAttribute("Streak",0)

	local ls=Instance.new("Folder") ls.Name="leaderstats" ls.Parent=player
	for _,name in ipairs({"Kills","Streak","Level"}) do local v=Instance.new("IntValue") v.Name=name v.Parent=ls end
	ls.Kills.Value=p.Stats.Kills
	ls.Level.Value=p.Progression.Level
	self:Push(player)
end

function Service:Start()
	Players.PlayerAdded:Connect(function(p) self:Load(p) end)
	Players.PlayerRemoving:Connect(function(p) self:Save(p) profiles[p]=nil end)
	for _,p in ipairs(Players:GetPlayers()) do task.spawn(function() self:Load(p) end) end

	task.spawn(function()
		while task.wait(60) do
			for p,profile in pairs(profiles) do
				if p.Parent then
					profile.Stats.PlayMinutes += 1
					self:ProgressQuest(p,"PlayMinutes",1)
					self:Push(p)
					task.spawn(function() self:Save(p) end)
				end
			end
		end
	end)

	game:BindToClose(function()
		for p in pairs(profiles) do self:Save(p) end
	end)
end

return Service
