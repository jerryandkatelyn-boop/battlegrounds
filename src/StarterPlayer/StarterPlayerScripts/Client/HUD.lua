--!strict
local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Catalog=require(ReplicatedStorage.Shared.CharacterCatalog)
local QuestConfig=require(ReplicatedStorage.Shared.QuestConfig)

local player=Players.LocalPlayer
local HUD={}
HUD.__index=HUD

local function corner(parent,r)
	local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 10) c.Parent=parent
end
local function stroke(parent,color,thick,trans)
	local s=Instance.new("UIStroke") s.Color=color s.Thickness=thick or 1 s.Transparency=trans or 0 s.Parent=parent
end
local function text(parent,value,size,font)
	local t=Instance.new("TextLabel") t.BackgroundTransparency=1 t.Text=value t.TextColor3=Color3.fromRGB(238,241,255)
	t.Font=font or Enum.Font.GothamBold t.TextSize=size or 16 t.TextWrapped=true t.Parent=parent return t
end
local function button(parent,value)
	local b=Instance.new("TextButton") b.AutoButtonColor=false b.Text=value b.TextColor3=Color3.fromRGB(245,247,255)
	b.Font=Enum.Font.GothamBlack b.TextSize=15 b.BackgroundColor3=Color3.fromRGB(28,32,46) b.BorderSizePixel=0 b.Parent=parent
	corner(b,10) stroke(b,Color3.fromRGB(92,155,220),1,0.35)
	b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(38,45,65)}):Play() end)
	b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(28,32,46)}):Play() end)
	return b
end

function HUD.new(callbacks)
	local self=setmetatable({},HUD)
	self.Callbacks=callbacks
	self.Settings={CameraShake=true,VFX=true,DamageNumbers=true}
	self.Cooldowns={}

	local gui=Instance.new("ScreenGui") gui.Name="ShatterboundHUD" gui.ResetOnSpawn=false gui.IgnoreGuiInset=true gui.DisplayOrder=20 gui.Parent=player:WaitForChild("PlayerGui")
	self.Gui=gui

	local safe=text(gui,"SAFE ZONE",18,Enum.Font.GothamBlack)
	safe.Name="Safe" safe.AnchorPoint=Vector2.new(0.5,0) safe.Position=UDim2.new(0.5,0,0,18) safe.Size=UDim2.fromOffset(180,34)
	safe.TextColor3=Color3.fromRGB(120,210,255) safe.Visible=false
	self.Safe=safe

	local top=Instance.new("Frame") top.Position=UDim2.fromOffset(22,22) top.Size=UDim2.fromOffset(300,78) top.BackgroundColor3=Color3.fromRGB(14,17,27) top.BackgroundTransparency=0.08 top.BorderSizePixel=0 top.Parent=gui
	corner(top,14) stroke(top,Color3.fromRGB(70,105,155),1,0.25)

	local name=text(top,"KAIRO // THE IMPACT HEIR",15,Enum.Font.GothamBlack) name.Position=UDim2.fromOffset(14,8) name.Size=UDim2.new(1,-28,0,22) name.TextXAlignment=Enum.TextXAlignment.Left
	local hpBack=Instance.new("Frame") hpBack.Position=UDim2.fromOffset(14,39) hpBack.Size=UDim2.new(1,-28,0,20) hpBack.BackgroundColor3=Color3.fromRGB(38,40,50) hpBack.BorderSizePixel=0 hpBack.Parent=top corner(hpBack,6)
	local hp=Instance.new("Frame") hp.Size=UDim2.fromScale(1,1) hp.BackgroundColor3=Color3.fromRGB(235,78,92) hp.BorderSizePixel=0 hp.Parent=hpBack corner(hp,6)
	local hpText=text(hpBack,"100 / 100",13,Enum.Font.GothamBlack) hpText.Size=UDim2.fromScale(1,1)
	self.HealthFill=hp self.HealthText=hpText

	local stats=text(gui,"LV 1   •   0 COINS   •   0 KILLS",14,Enum.Font.GothamBold)
	stats.AnchorPoint=Vector2.new(1,0) stats.Position=UDim2.new(1,-24,0,26) stats.Size=UDim2.fromOffset(320,28) stats.TextXAlignment=Enum.TextXAlignment.Right
	self.Stats=stats

	local abilityBar=Instance.new("Frame") abilityBar.Name="AbilityBar" abilityBar.AnchorPoint=Vector2.new(0.5,1) abilityBar.Position=UDim2.new(0.5,0,1,-28)
	abilityBar.Size=UDim2.fromOffset(590,92) abilityBar.BackgroundTransparency=1 abilityBar.Parent=gui
	local abilityScale=Instance.new("UIScale") abilityScale.Name="ResponsiveScale" abilityScale.Parent=abilityBar
	local function updateScale()
		local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
		abilityScale.Scale=math.clamp(viewport.X/900,0.58,1)
	end
	updateScale()
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale) end
	self.AbilityButtons={}
	for i=1,3 do
		local b=button(abilityBar,"")
		b.Size=UDim2.fromOffset(138,72) b.Position=UDim2.fromOffset((i-1)*148,0)
		local key=text(b,tostring(i),12,Enum.Font.GothamBlack) key.Position=UDim2.fromOffset(9,5) key.Size=UDim2.fromOffset(22,18) key.TextColor3=Color3.fromRGB(115,185,255)
		local info=Catalog.Kairo.Abilities[i]
		local title=text(b,string.upper(info.Name),13,Enum.Font.GothamBlack) title.Position=UDim2.fromOffset(8,25) title.Size=UDim2.new(1,-16,0,32)
		local cd=text(b,"",24,Enum.Font.GothamBlack) cd.Name="Cooldown" cd.Size=UDim2.fromScale(1,1) cd.TextColor3=Color3.fromRGB(255,220,220)
		b.Activated:Connect(function() callbacks.Ability(i) end)
		self.AbilityButtons[i]=b
	end

	local ult=button(abilityBar,"")
	ult.Size=UDim2.fromOffset(138,72) ult.Position=UDim2.fromOffset(452,0)
	local ultTitle=text(ult,"HEAVENBREAKER",13,Enum.Font.GothamBlack) ultTitle.Position=UDim2.fromOffset(8,18) ultTitle.Size=UDim2.new(1,-16,0,22)
	local ultPct=text(ult,"0%",18,Enum.Font.GothamBlack) ultPct.Position=UDim2.fromOffset(8,40) ultPct.Size=UDim2.new(1,-16,0,23) ultPct.TextColor3=Color3.fromRGB(120,195,255)
	ult.Activated:Connect(callbacks.Ultimate)
	self.UltimateButton=ult self.UltimateText=ultPct

	local utility=Instance.new("Frame") utility.AnchorPoint=Vector2.new(1,1) utility.Position=UDim2.new(1,-20,1,-28) utility.Size=UDim2.fromOffset(220,150) utility.BackgroundTransparency=1 utility.Parent=gui
	local lock=button(utility,"LOCK  [T]") lock.Size=UDim2.fromOffset(100,48) lock.Position=UDim2.fromOffset(112,0) lock.Activated:Connect(callbacks.Lock)
	local menu=button(utility,"MENU  [M]") menu.Size=UDim2.fromOffset(100,48) menu.Position=UDim2.fromOffset(112,56) menu.Activated:Connect(function() self:ToggleMenu() end)
	local emote=button(utility,"EMOTE [V]") emote.Size=UDim2.fromOffset(100,38) emote.Position=UDim2.fromOffset(112,112) emote.Activated:Connect(function() self:ToggleEmotes() end)

	if UserInputService.TouchEnabled then
		local attack=button(gui,"ATTACK") attack.AnchorPoint=Vector2.new(1,1) attack.Position=UDim2.new(1,-26,1,-190) attack.Size=UDim2.fromOffset(112,72) attack.Activated:Connect(callbacks.Attack)
		local blockBtn=button(gui,"BLOCK") blockBtn.AnchorPoint=Vector2.new(1,1) blockBtn.Position=UDim2.new(1,-148,1,-190) blockBtn.Size=UDim2.fromOffset(96,62)
		blockBtn.MouseButton1Down:Connect(function() callbacks.Block(true) end)
		blockBtn.MouseButton1Up:Connect(function() callbacks.Block(false) end)
		self.MobileAttack=attack self.MobileBlock=blockBtn
	end

	self:BuildMenu()
	self:BuildEmotes()
	return self
end

function HUD:BuildMenu()
	local gui=self.Gui
	local panel=Instance.new("Frame") panel.Name="Menu" panel.AnchorPoint=Vector2.new(0.5,0.5) panel.Position=UDim2.fromScale(0.5,0.5) panel.Size=UDim2.new(0.82,0,0.72,0)
	panel.BackgroundColor3=Color3.fromRGB(13,16,25) panel.BackgroundTransparency=0.03 panel.BorderSizePixel=0 panel.Visible=false panel.Parent=gui
	corner(panel,18) stroke(panel,Color3.fromRGB(80,165,235),2,0.25)
	local max=Instance.new("UISizeConstraint") max.MaxSize=Vector2.new(900,620) max.MinSize=Vector2.new(540,390) max.Parent=panel

	local title=text(panel,"SHATTERBOUND // FIGHTER HUB",25,Enum.Font.GothamBlack) title.Position=UDim2.fromOffset(24,18) title.Size=UDim2.new(1,-48,0,36) title.TextXAlignment=Enum.TextXAlignment.Left
	local close=button(panel,"×") close.AnchorPoint=Vector2.new(1,0) close.Position=UDim2.new(1,-18,0,16) close.Size=UDim2.fromOffset(42,38) close.TextSize=24 close.Activated:Connect(function() panel.Visible=false end)

	local tabs={"PROFILE","DAILY","QUESTS","CHARACTER","SETTINGS"}
	local bodies={}
	for i,label in ipairs(tabs) do
		local b=button(panel,label) b.Position=UDim2.new(0,22,0,70+(i-1)*52) b.Size=UDim2.fromOffset(138,42)
		local body=Instance.new("Frame") body.Name=label body.Position=UDim2.new(0,180,0,72) body.Size=UDim2.new(1,-202,1,-94) body.BackgroundTransparency=1 body.Visible=i==1 body.Parent=panel bodies[label]=body
		b.Activated:Connect(function() for _,v in pairs(bodies) do v.Visible=false end body.Visible=true end)
	end
	self.Menu=panel self.Bodies=bodies

	local profile=text(bodies.PROFILE,"Loading profile...",18,Enum.Font.GothamBold) profile.Size=UDim2.fromScale(1,1) profile.TextXAlignment=Enum.TextXAlignment.Left profile.TextYAlignment=Enum.TextYAlignment.Top
	self.ProfileText=profile

	local dailyTitle=text(bodies.DAILY,"DAILY REWARD",26,Enum.Font.GothamBlack) dailyTitle.Size=UDim2.new(1,0,0,50) dailyTitle.TextXAlignment=Enum.TextXAlignment.Left
	local dailyInfo=text(bodies.DAILY,"Return each day to build a 7-day streak.",17,Enum.Font.GothamBold) dailyInfo.Position=UDim2.fromOffset(0,62) dailyInfo.Size=UDim2.new(1,0,0,80) dailyInfo.TextXAlignment=Enum.TextXAlignment.Left
	local claim=button(bodies.DAILY,"CLAIM TODAY") claim.Position=UDim2.fromOffset(0,158) claim.Size=UDim2.fromOffset(220,52) claim.Activated:Connect(self.Callbacks.ClaimDaily)
	self.DailyInfo=dailyInfo

	local quests=text(bodies.QUESTS,"Loading quests...",16,Enum.Font.GothamBold) quests.Size=UDim2.fromScale(1,1) quests.TextXAlignment=Enum.TextXAlignment.Left quests.TextYAlignment=Enum.TextYAlignment.Top
	self.QuestText=quests

	local charTitle=text(bodies.CHARACTER,"KAIRO // THE IMPACT HEIR",28,Enum.Font.GothamBlack) charTitle.Size=UDim2.new(1,0,0,50) charTitle.TextXAlignment=Enum.TextXAlignment.Left
	local charDesc=text(bodies.CHARACTER,Catalog.Kairo.Description.."\n\nStarter Fighter • Close Range • Kinetic Impact",18,Enum.Font.GothamBold) charDesc.Position=UDim2.fromOffset(0,62) charDesc.Size=UDim2.new(1,0,0,150) charDesc.TextXAlignment=Enum.TextXAlignment.Left charDesc.TextYAlignment=Enum.TextYAlignment.Top
	local select=button(bodies.CHARACTER,"EQUIP KAIRO") select.Position=UDim2.fromOffset(0,225) select.Size=UDim2.fromOffset(220,52) select.Activated:Connect(function() self.Callbacks.SelectCharacter("Kairo") end)

	local settingsBody=bodies.SETTINGS
	local y=0
	for _,item in ipairs({{"CameraShake","CAMERA SHAKE"},{"VFX","HIGH IMPACT VFX"},{"DamageNumbers","DAMAGE NUMBERS"}}) do
		local key,label=item[1],item[2]
		local b=button(settingsBody,label..": ON") b.Position=UDim2.fromOffset(0,y) b.Size=UDim2.fromOffset(290,48)
		b.Activated:Connect(function()
			self.Settings[key]=not self.Settings[key]
			b.Text=label..": "..(self.Settings[key] and "ON" or "OFF")
			self.Callbacks.Settings(self.Settings)
		end)
		y+=58
	end

	if player:GetAttribute("PrivateServerOwner") then
		local pTitle=text(settingsBody,"PRIVATE SERVER",18,Enum.Font.GothamBlack) pTitle.Position=UDim2.fromOffset(0,y+10) pTitle.Size=UDim2.fromOffset(300,30) pTitle.TextXAlignment=Enum.TextXAlignment.Left
		local heal=button(settingsBody,"HEAL ALL") heal.Position=UDim2.fromOffset(0,y+48) heal.Size=UDim2.fromOffset(140,44) heal.Activated:Connect(function() self.Callbacks.Private("HealAll") end)
		local fill=button(settingsBody,"FILL ULT") fill.Position=UDim2.fromOffset(150,y+48) fill.Size=UDim2.fromOffset(140,44) fill.Activated:Connect(function() self.Callbacks.Private("FillUltimate") end)
		local noCd=false
		local cooldowns=button(settingsBody,"COOLDOWNS: ON") cooldowns.Position=UDim2.fromOffset(0,y+100) cooldowns.Size=UDim2.fromOffset(290,44)
		cooldowns.Activated:Connect(function()
			noCd=not noCd
			cooldowns.Text="COOLDOWNS: "..(noCd and "OFF" or "ON")
			self.Callbacks.Private("NoCooldowns",noCd)
		end)
		local damage=1
		local damageBtn=button(settingsBody,"DAMAGE: 1.0x") damageBtn.Position=UDim2.fromOffset(0,y+152) damageBtn.Size=UDim2.fromOffset(290,44)
		damageBtn.Activated:Connect(function()
			damage=damage==1 and 1.5 or damage==1.5 and 2 or 1
			damageBtn.Text=("DAMAGE: %.1fx"):format(damage)
			self.Callbacks.Private("DamageMultiplier",damage)
		end)
	end
end

function HUD:BuildEmotes()
	local f=Instance.new("Frame") f.Name="Emotes" f.AnchorPoint=Vector2.new(0.5,0.5) f.Position=UDim2.fromScale(0.5,0.5) f.Size=UDim2.fromOffset(330,330) f.BackgroundColor3=Color3.fromRGB(15,18,28) f.BackgroundTransparency=0.08 f.Visible=false f.Parent=self.Gui
	corner(f,165) stroke(f,Color3.fromRGB(110,175,240),2,0.2)
	local names={"wave","cheer","laugh","dance"}
	for i,name in ipairs(names) do
		local angle=((i-1)/4)*math.pi*2-math.pi/2
		local b=button(f,string.upper(name)) b.AnchorPoint=Vector2.new(0.5,0.5) b.Size=UDim2.fromOffset(100,52)
		b.Position=UDim2.new(0.5,math.cos(angle)*100,0.5,math.sin(angle)*100)
		b.Activated:Connect(function() self.Callbacks.Emote(name) f.Visible=false end)
	end
	self.Emotes=f
end

function HUD:ToggleMenu() self.Menu.Visible=not self.Menu.Visible self.Emotes.Visible=false end
function HUD:ToggleEmotes() self.Emotes.Visible=not self.Emotes.Visible self.Menu.Visible=false end

function HUD:SetHealth(current,maxHealth)
	local ratio=maxHealth>0 and math.clamp(current/maxHealth,0,1) or 0
	TweenService:Create(self.HealthFill,TweenInfo.new(0.12),{Size=UDim2.fromScale(ratio,1)}):Play()
	self.HealthText.Text=("%d / %d"):format(math.ceil(current),math.ceil(maxHealth))
end

function HUD:SetUltimate(value)
	local pct=math.floor(math.clamp(value,0,100)+0.5)
	self.UltimateText.Text=pct.."%"
	self.UltimateButton.BackgroundColor3=pct>=100 and Color3.fromRGB(76,45,76) or Color3.fromRGB(28,32,46)
end

function HUD:SetSafe(value) self.Safe.Visible=value==true end

function HUD:StartCooldown(index,duration)
	local b=self.AbilityButtons[index] if not b then return end
	local label=b:FindFirstChild("Cooldown")
	local finish=time()+duration
	task.spawn(function()
		while b.Parent and time()<finish do
			if label then label.Text=string.format("%.1f",math.max(0,finish-time())) end
			task.wait(0.05)
		end
		if label then label.Text="" end
	end)
end

function HUD:UpdateProfile(profile)
	if not profile then return end
	local s,e,p=profile.Stats,profile.Economy,profile.Progression
	self.Stats.Text=("LV %d   •   %d COINS   •   %d KILLS"):format(p.Level,e.Coins,s.Kills)
	local kd=s.Deaths>0 and s.Kills/s.Deaths or s.Kills
	self.ProfileText.Text=("LEVEL %d\nXP: %d\n\nKILLS: %d\nDEATHS: %d\nK/D: %.2f\nBEST STREAK: %d\nPLAYTIME: %d MIN\n\nCOINS: %d"):format(p.Level,p.XP,s.Kills,s.Deaths,kd,s.BestStreak,s.PlayMinutes,e.Coins)
	self.DailyInfo.Text=("Current streak: %d / 7\nReturn each day for increasing coin and XP rewards."):format(profile.Daily.Streak)

	local lines={"DAILY"}
	for _,q in ipairs(QuestConfig.Daily) do
		local data=profile.Quests.Daily[q.Id]
		table.insert(lines,("%s  %d/%d%s"):format(q.Text,data and math.floor(data.Progress) or 0,q.Goal,data and data.Complete and "  ✓" or ""))
	end
	table.insert(lines,"\nWEEKLY")
	for _,q in ipairs(QuestConfig.Weekly) do
		local data=profile.Quests.Weekly[q.Id]
		table.insert(lines,("%s  %d/%d%s"):format(q.Text,data and math.floor(data.Progress) or 0,q.Goal,data and data.Complete and "  ✓" or ""))
	end
	self.QuestText.Text=table.concat(lines,"\n")
end

function HUD:Toast(message,positive)
	local label=text(self.Gui,tostring(message),18,Enum.Font.GothamBlack)
	label.AnchorPoint=Vector2.new(0.5,0) label.Position=UDim2.new(0.5,0,0,70) label.Size=UDim2.fromOffset(480,52)
	label.BackgroundTransparency=0.08 label.BackgroundColor3=positive==false and Color3.fromRGB(85,35,45) or Color3.fromRGB(25,55,75)
	corner(label,12) stroke(label,Color3.fromRGB(120,190,255),1,0.3)
	label.TextTransparency=1 TweenService:Create(label,TweenInfo.new(0.15),{TextTransparency=0}):Play()
	task.delay(2.2,function() if label.Parent then TweenService:Create(label,TweenInfo.new(0.25),{TextTransparency=1,BackgroundTransparency=1}):Play() task.delay(0.3,function() if label.Parent then label:Destroy() end end) end end)
end

return HUD
