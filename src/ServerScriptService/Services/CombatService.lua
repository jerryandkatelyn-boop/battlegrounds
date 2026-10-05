--!strict
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Shared=ReplicatedStorage:WaitForChild("Shared")
local Config=require(Shared.GameConfig)
local Catalog=require(Shared.CharacterCatalog)

local Service={}
local ProfileService
local ArenaService
local LeaderboardService
local ActionRemote
local StateRemote
local FXRemote
local PrivateRemote
local states={}
local privateRules={NoCooldowns=false,DamageMultiplier=1}

local function now() return workspace:GetServerTimeNow() end
local function getState(player)
	local s=states[player]
	if not s then
		s={Combo=0,LastM1=0,Cooldowns={},StunUntil=0,LastDamage=0,LastRequests={},UsingAbility=false}
		states[player]=s
	end
	return s
end

local function living(player)
	local c=player.Character
	local h=c and c:FindFirstChildOfClass("Humanoid")
	local r=c and c:FindFirstChild("HumanoidRootPart")
	if not c or not h or not r or h.Health<=0 then return nil end
	return c,h,r
end

local function limited(player,key,interval)
	local s=getState(player)
	local t=now()
	local last=s.LastRequests[key] or 0
	if t-last<interval then return true end
	s.LastRequests[key]=t
	return false
end

local function setUltimate(player,value)
	player:SetAttribute("Ultimate",math.clamp(value,0,Config.UltimateMax))
end

local function setMovement(player,speed)
	local c=player.Character
	local h=c and c:FindFirstChildOfClass("Humanoid")
	if h then h.WalkSpeed=speed end
end

local function stun(player,duration)
	local s=getState(player)
	s.StunUntil=math.max(s.StunUntil,now()+duration)
	player:SetAttribute("Stunned",true)
	setMovement(player,0)
	task.delay(duration,function()
		if player.Parent and getState(player).StunUntil<=now() then
			player:SetAttribute("Stunned",false)
			setMovement(player,player:GetAttribute("Blocking") and Config.BlockWalkSpeed or Config.WalkSpeed)
		end
	end)
end

local function canAct(player)
	local s=getState(player)
	if s.UsingAbility or s.StunUntil>now() then return false end
	local c=select(1,living(player))
	return c~=nil
end

local function modelsInBox(attackerCharacter,cf,size)
	local params=OverlapParams.new()
	params.FilterType=Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances={attackerCharacter}
	local result,seen={},{}
	for _,p in ipairs(workspace:GetPartBoundsInBox(cf,size,params)) do
		local m=p:FindFirstAncestorOfClass("Model")
		local h=m and m:FindFirstChildOfClass("Humanoid")
		if m and h and h.Health>0 and m~=attackerCharacter and not seen[m] then
			seen[m]=true
			table.insert(result,m)
		end
	end
	return result
end

local function isDummy(model) return model:GetAttribute("TrainingDummy")==true end
local function playerFromModel(model) return Players:GetPlayerFromCharacter(model) end

local function blockWorks(targetModel,attackerPos,guardBreak)
	if guardBreak then return false end
	local p=playerFromModel(targetModel)
	if not p or p:GetAttribute("Blocking")~=true then return false end
	local root=targetModel:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local d=attackerPos-root.Position
	if d.Magnitude<0.001 then return true end
	return root.CFrame.LookVector:Dot(d.Unit)>Config.BlockFrontDot
end

local function applyDamage(attacker,targetModel,rawDamage,opts)
	opts=opts or {}
	local attackerChar,_,attackerRoot=living(attacker)
	if not attackerChar or not attackerRoot then return false,false end
	local targetHum=targetModel:FindFirstChildOfClass("Humanoid")
	local targetRoot=targetModel:FindFirstChild("HumanoidRootPart")
	if not targetHum or not targetRoot or targetHum.Health<=0 then return false,false end

	local target=playerFromModel(targetModel)
	local attackerSafe=ArenaService:IsSafePosition(attackerRoot.Position)
	if attackerSafe and not isDummy(targetModel) then return false,false end
	if target and ArenaService:IsSafePosition(targetRoot.Position) then return false,false end
	if target and (target:GetAttribute("ProtectedUntil") or 0)>now() then return false,false end

	if blockWorks(targetModel,attackerRoot.Position,opts.GuardBreak==true) then
		FXRemote:FireAllClients("Block",targetRoot.Position)
		return false,true
	end

	local damage=math.max(0,rawDamage*privateRules.DamageMultiplier)
	local before=targetHum.Health
	targetHum:SetAttribute("LastAttackerUserId",attacker.UserId)
	targetHum:SetAttribute("LastAttackerAt",now())
	targetHum:TakeDamage(damage)
	local dealt=math.min(before,damage)

	if target then
		getState(target).LastDamage=now()
		if opts.Stun and opts.Stun>0 then stun(target,opts.Stun) end
	end
	if opts.Knockback then targetRoot.AssemblyLinearVelocity=opts.Knockback end

	if dealt>0 then
		setUltimate(attacker,(attacker:GetAttribute("Ultimate") or 0)+dealt*Config.UltimateGainPerDamage)
		ProfileService:AddXP(attacker,dealt*Config.Rewards.DamageXPScale)
		ProfileService:ProgressQuest(attacker,"Damage",dealt)
		FXRemote:FireAllClients("Hit",targetRoot.Position,dealt,opts.HitType or "Light")
	end
	return dealt>0,false
end

local function startCooldown(player,index,duration)
	if privateRules.NoCooldowns then return end
	getState(player).Cooldowns[index]=now()+duration
	StateRemote:FireClient(player,"Cooldown",index,duration)
end
local function ready(player,index)
	return privateRules.NoCooldowns or (getState(player).Cooldowns[index] or 0)<=now()
end

local function m1(player,requested)
	if limited(player,"M1",Config.RateLimits.M1) or not canAct(player) or player:GetAttribute("Blocking") then return end
	local s=getState(player)
	local t=now()
	if t-s.LastM1>Config.M1ResetWindow then s.Combo=0 end
	s.Combo=(s.Combo%4)+1
	s.LastM1=t
	local combo=s.Combo
	local character,hum,root=living(player)
	if not character or not hum or not root then return end

	local variant="Normal"
	if combo==4 and requested=="Uppercut" then
		variant="Uppercut"
	elseif combo==4 and requested=="Downslam" and hum.FloorMaterial==Enum.Material.Air then
		variant="Downslam"
	end
	StateRemote:FireClient(player,"M1",combo,variant)

	task.delay(Config.M1Windup,function()
		local c,_,r=living(player)
		if not c or not r then return end
		for _,model in ipairs(modelsInBox(c,r.CFrame*CFrame.new(0,0,-3.8),Vector3.new(6.5,6,7))) do
			local knock
			local hitType=combo==4 and "Heavy" or "Light"
			if combo==4 then
				if variant=="Uppercut" then
					knock=Vector3.new(r.CFrame.LookVector.X*18,Catalog.Kairo.M1.UppercutY,r.CFrame.LookVector.Z*18)
				elseif variant=="Downslam" then
					knock=Vector3.new(r.CFrame.LookVector.X*18,Catalog.Kairo.M1.DownslamY,r.CFrame.LookVector.Z*18)
				else
					knock=r.CFrame.LookVector*Catalog.Kairo.M1.FinalKnockback+Vector3.new(0,14,0)
				end
			end
			applyDamage(player,model,Catalog.Kairo.M1.Damage[combo],{Stun=combo==4 and 0.65 or 0.34,Knockback=knock,HitType=hitType})
		end
	end)
end

local function ability(player,index)
	if type(index)~="number" or index%1~=0 or index<1 or index>3 then return end
	if limited(player,"Ability",Config.RateLimits.Ability) or not canAct(player) or player:GetAttribute("Blocking") or not ready(player,index) then return end
	local char=Catalog[player:GetAttribute("SelectedCharacter") or Config.DefaultCharacter]
	if not char then return end
	local info=char.Abilities[index]
	if not info then return end
	local c,_,root=living(player)
	if not c or not root then return end

	local s=getState(player)
	s.UsingAbility=true
	startCooldown(player,index,info.Cooldown)
	ProfileService:ProgressQuest(player,"Abilities",1)
	FXRemote:FireAllClients("Ability",player,index,root.Position)

	if index==1 then
		root.AssemblyLinearVelocity=root.CFrame.LookVector*72+Vector3.new(0,3,0)
		task.delay(0.13,function()
			local c2,_,r2=living(player)
			if not c2 or not r2 then return end
			for _,model in ipairs(modelsInBox(c2,r2.CFrame*CFrame.new(0,0,-5),Vector3.new(7,7,10))) do
				applyDamage(player,model,info.Damage,{Stun=0.75,Knockback=r2.CFrame.LookVector*48+Vector3.new(0,10,0),HitType="Rush"})
			end
		end)
		task.delay(0.48,function() if player.Parent then getState(player).UsingAbility=false end end)
	elseif index==2 then
		task.delay(0.12,function()
			local c2,_,r2=living(player)
			if not c2 or not r2 then return end
			for _,model in ipairs(modelsInBox(c2,r2.CFrame*CFrame.new(0,0,-3.5),Vector3.new(7,8,7))) do
				applyDamage(player,model,info.Damage,{Stun=0.9,Knockback=r2.CFrame.LookVector*14+Vector3.new(0,78,0),HitType="Uppercut"})
			end
		end)
		task.delay(0.52,function() if player.Parent then getState(player).UsingAbility=false end end)
	else
		task.delay(0.22,function()
			local c2,_,r2=living(player)
			if not c2 or not r2 then return end
			for _,model in ipairs(modelsInBox(c2,CFrame.new(r2.Position),Vector3.new(28,10,28))) do
				local tr=model:FindFirstChild("HumanoidRootPart")
				if tr and (tr.Position-r2.Position).Magnitude<=14 then
					local dir=tr.Position-r2.Position
					dir=dir.Magnitude>0.1 and dir.Unit or r2.CFrame.LookVector
					applyDamage(player,model,info.Damage,{Stun=1.05,Knockback=dir*58+Vector3.new(0,25,0),GuardBreak=true,HitType="Crater"})
				end
			end
			FXRemote:FireAllClients("Crater",r2.Position,14)
		end)
		task.delay(0.72,function() if player.Parent then getState(player).UsingAbility=false end end)
	end
end

local function ultimate(player)
	if limited(player,"Ultimate",Config.RateLimits.Ultimate) or not canAct(player) or player:GetAttribute("Blocking") then return end
	if (player:GetAttribute("Ultimate") or 0)<Config.UltimateMax then return end
	local char=Catalog[player:GetAttribute("SelectedCharacter") or Config.DefaultCharacter]
	local c,_,root=living(player)
	if not char or not c or not root then return end
	setUltimate(player,0)
	getState(player).UsingAbility=true
	FXRemote:FireAllClients("Ultimate",player,root.Position)

	task.delay(0.32,function()
		local c2,_,r2=living(player)
		if not c2 or not r2 then return end
		local impact=r2.Position+r2.CFrame.LookVector*9
		for _,model in ipairs(modelsInBox(c2,CFrame.new(impact),Vector3.new(26,16,26))) do
			local tr=model:FindFirstChild("HumanoidRootPart")
			if tr and (tr.Position-impact).Magnitude<=15 then
				local hum=model:FindFirstChildOfClass("Humanoid")
				local execute=hum and hum.Health<=char.Ultimate.ExecutionThreshold
				local dir=tr.Position-r2.Position
				dir=dir.Magnitude>0.1 and dir.Unit or r2.CFrame.LookVector
				local hit=applyDamage(player,model,char.Ultimate.Damage,{Stun=1.4,Knockback=dir*76+Vector3.new(0,35,0),GuardBreak=true,HitType="Ultimate"})
				if hit and execute then FXRemote:FireAllClients("Execution",player,model,tr.Position) end
			end
		end
		FXRemote:FireAllClients("Crater",impact,18)
	end)
	task.delay(0.95,function() if player.Parent then getState(player).UsingAbility=false end end)
end

local function block(player,enabled)
	if type(enabled)~="boolean" or limited(player,"Block",Config.RateLimits.Block) then return end
	if enabled and not canAct(player) then return end
	player:SetAttribute("Blocking",enabled)
	setMovement(player,enabled and Config.BlockWalkSpeed or Config.WalkSpeed)
end

function Service:SetupCharacter(player,character)
	local hum=character:WaitForChild("Humanoid",8)
	local root=character:WaitForChild("HumanoidRootPart",8)
	if not hum or not root then return end
	hum.MaxHealth=Config.BaseHealth hum.Health=Config.BaseHealth hum.WalkSpeed=Config.WalkSpeed hum.JumpPower=Config.JumpPower
	player:SetAttribute("Blocking",false) player:SetAttribute("Stunned",false)
	player:SetAttribute("ProtectedUntil",now()+Config.SpawnProtection)
	setUltimate(player,0)

	hum.Died:Connect(function()
		ProfileService:AddDeath(player)
		player:SetAttribute("Streak",0)
		local ls=player:FindFirstChild("leaderstats")
		if ls and ls:FindFirstChild("Streak") then ls.Streak.Value=0 end
		local attackerId=hum:GetAttribute("LastAttackerUserId")
		local attackedAt=hum:GetAttribute("LastAttackerAt") or 0
		if type(attackerId)=="number" and now()-attackedAt<=12 then
			local killer=Players:GetPlayerByUserId(attackerId)
			if killer and killer~=player then
				local streak=(killer:GetAttribute("Streak") or 0)+1
				killer:SetAttribute("Streak",streak)
				local kls=killer:FindFirstChild("leaderstats")
				if kls then
					if kls:FindFirstChild("Streak") then kls.Streak.Value=streak end
					if kls:FindFirstChild("Kills") then kls.Kills.Value+=1 end
				end
				ProfileService:AddKill(killer,streak)
				local kp=ProfileService:Get(killer)
				if kp then LeaderboardService:UpdatePlayer(killer,kp.Stats.Kills) end
				FXRemote:FireAllClients("Kill",killer,player,streak)
			end
		end
	end)
end

function Service:Init(profile,arena,leaderboard,remotes)
	ProfileService=profile ArenaService=arena LeaderboardService=leaderboard
	ActionRemote=remotes.Action StateRemote=remotes.State FXRemote=remotes.FX PrivateRemote=remotes.Private

	ActionRemote.OnServerEvent:Connect(function(player,action,payload)
		if type(action)~="string" or #action>24 then return end
		if action=="M1" then if payload==nil or type(payload)=="string" then m1(player,payload) end
		elseif action=="Block" then block(player,payload)
		elseif action=="Ability" then ability(player,payload)
		elseif action=="Ultimate" then ultimate(player) end
	end)

	PrivateRemote.OnServerEvent:Connect(function(player,command,value)
		if game.PrivateServerOwnerId==0 or player.UserId~=game.PrivateServerOwnerId then return end
		if limited(player,"Private",Config.RateLimits.Private) or type(command)~="string" then return end
		if command=="HealAll" then
			for _,p in ipairs(Players:GetPlayers()) do local _,h=living(p) if h then h.Health=h.MaxHealth end end
		elseif command=="FillUltimate" then
			for _,p in ipairs(Players:GetPlayers()) do setUltimate(p,Config.UltimateMax) end
		elseif command=="NoCooldowns" and type(value)=="boolean" then
			privateRules.NoCooldowns=value
			FXRemote:FireAllClients("Announcement","PRIVATE SERVER: COOLDOWNS "..(value and "OFF" or "ON"))
		elseif command=="DamageMultiplier" and type(value)=="number" then
			privateRules.DamageMultiplier=math.clamp(value,0.25,3)
			FXRemote:FireAllClients("Announcement",("PRIVATE SERVER: %.2fx DAMAGE"):format(privateRules.DamageMultiplier))
		end
	end)
end

function Service:Start()
	local function hook(p)
		p.CharacterAdded:Connect(function(c) Service:SetupCharacter(p,c) end)
		if p.Character then task.spawn(function() Service:SetupCharacter(p,p.Character) end) end
	end
	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(p) states[p]=nil end)
	for _,p in ipairs(Players:GetPlayers()) do hook(p) end

	RunService.Heartbeat:Connect(function(dt)
		for _,p in ipairs(Players:GetPlayers()) do
			local c,h,r=living(p)
			if c and h and r then
				p:SetAttribute("InSafeZone",ArenaService:IsSafePosition(r.Position))
				local s=getState(p)
				if h.Health<h.MaxHealth and now()-s.LastDamage>=Config.RegenDelay then h.Health=math.min(h.MaxHealth,h.Health+Config.RegenPerSecond*dt) end
			end
		end
	end)
end

return Service
