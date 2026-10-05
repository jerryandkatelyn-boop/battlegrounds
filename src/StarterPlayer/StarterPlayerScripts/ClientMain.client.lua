--!strict
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ContextActionService=game:GetService("ContextActionService")
local UserInputService=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")\nlocal MarketplaceService=game:GetService("MarketplaceService")

local player=Players.LocalPlayer
local Config=require(ReplicatedStorage.Shared.GameConfig)\nlocal MonetizationConfig=require(ReplicatedStorage.Shared.MonetizationConfig)
local remotes=ReplicatedStorage:WaitForChild(Config.RemoteFolderName)
local Action=remotes:WaitForChild("Action")
local State=remotes:WaitForChild("State")
local FX=remotes:WaitForChild("FX")
local Meta=remotes:WaitForChild("Meta")
local Private=remotes:WaitForChild("Private")

local clientFolder=script.Parent:WaitForChild("Client")
local HUD=require(clientFolder.HUD)
local Effects=require(clientFolder.Effects)

local lockTarget=nil
local lockHighlight=nil
local jumpHeld=false
local currentHumanoid=nil
local currentRoot=nil
local currentCharacter=nil

local function variant()
	if currentHumanoid and currentHumanoid.FloorMaterial==Enum.Material.Air then return "Downslam" end
	if jumpHeld then return "Uppercut" end
	return "Normal"
end

local function attack() Action:FireServer("M1",variant()) end
local function block(v) Action:FireServer("Block",v==true) end
local function ability(i) Action:FireServer("Ability",i) end
local function ultimate() Action:FireServer("Ultimate") end

local function clearLock()
	lockTarget=nil
	if lockHighlight then lockHighlight:Destroy() lockHighlight=nil end
	if currentHumanoid then currentHumanoid.AutoRotate=true end
end

local function chooseLock()
	if lockTarget then clearLock() return end
	if not currentRoot then return end
	local best,bestDist=nil,80
	for _,other in ipairs(Players:GetPlayers()) do
		if other~=player and other.Character then
			local h=other.Character:FindFirstChildOfClass("Humanoid")
			local r=other.Character:FindFirstChild("HumanoidRootPart")
			if h and r and h.Health>0 and other:GetAttribute("InSafeZone")~=true then
				local d=(r.Position-currentRoot.Position).Magnitude
				if d<bestDist then best=other.Character bestDist=d end
			end
		end
	end
	if best then
		lockTarget=best
		if currentHumanoid then currentHumanoid.AutoRotate=false end
		lockHighlight=Instance.new("Highlight") lockHighlight.Name="LockTarget" lockHighlight.FillTransparency=0.82 lockHighlight.OutlineColor=Color3.fromRGB(110,190,255) lockHighlight.FillColor=Color3.fromRGB(90,120,180) lockHighlight.Parent=best
	end
end

local hud
hud=HUD.new({
	Attack=attack,
	Block=block,
	Ability=ability,
	Ultimate=ultimate,
	Lock=chooseLock,
	ClaimDaily=function() Meta:FireServer("ClaimDaily") end,
	SelectCharacter=function(id) Meta:FireServer("SelectCharacter",id) end,
	Settings=function(s) Effects:SetSettings(s) end,
	Private=function(command,value) Private:FireServer(command,value) end,
	PurchaseProduct=function(key)
		local item=MonetizationConfig.Products[key]
		if item and item.Id and item.Id>0 then
			MarketplaceService:PromptProductPurchase(player,item.Id)
		elseif hud then
			hud:Toast("Create this developer product and add its ID in MonetizationConfig.lua",false)
		end
	end,
	PurchasePass=function(key)
		local item=MonetizationConfig.Passes[key]
		if item and item.Id and item.Id>0 then
			MarketplaceService:PromptGamePassPurchase(player,item.Id)
		elseif hud then
			hud:Toast("Create this pass and add its ID in MonetizationConfig.lua",false)
		end
	end,
	Emote=function(name)
		if currentHumanoid then pcall(function() currentHumanoid:PlayEmote(name) end) end
	end,
})

local function connectCharacter(character)
	currentCharacter=character
	currentHumanoid=character:WaitForChild("Humanoid")
	currentRoot=character:WaitForChild("HumanoidRootPart")
	clearLock()
	currentHumanoid.HealthChanged:Connect(function(h) hud:SetHealth(h,currentHumanoid.MaxHealth) end)
	hud:SetHealth(currentHumanoid.Health,currentHumanoid.MaxHealth)
end
player.CharacterAdded:Connect(connectCharacter)
if player.Character then task.spawn(connectCharacter,player.Character) end

local function bind(name,keys,callback)
	ContextActionService:BindActionAtPriority(name,function(_,inputState)
		return callback(inputState)
	end,false,Enum.ContextActionPriority.High.Value,table.unpack(keys))
end

bind("SB_Attack",{Enum.UserInputType.MouseButton1,Enum.KeyCode.ButtonR2},function(state)
	if state==Enum.UserInputState.Begin then attack() end
	return Enum.ContextActionResult.Sink
end)
bind("SB_Block",{Enum.KeyCode.F,Enum.KeyCode.ButtonL2},function(state)
	if state==Enum.UserInputState.Begin then block(true) elseif state==Enum.UserInputState.End then block(false) end
	return Enum.ContextActionResult.Sink
end)
bind("SB_Ability1",{Enum.KeyCode.One,Enum.KeyCode.ButtonX},function(state) if state==Enum.UserInputState.Begin then ability(1) end return Enum.ContextActionResult.Sink end)
bind("SB_Ability2",{Enum.KeyCode.Two,Enum.KeyCode.ButtonY},function(state) if state==Enum.UserInputState.Begin then ability(2) end return Enum.ContextActionResult.Sink end)
bind("SB_Ability3",{Enum.KeyCode.Three,Enum.KeyCode.ButtonB},function(state) if state==Enum.UserInputState.Begin then ability(3) end return Enum.ContextActionResult.Sink end)
bind("SB_Ultimate",{Enum.KeyCode.G,Enum.KeyCode.ButtonL1},function(state) if state==Enum.UserInputState.Begin then ultimate() end return Enum.ContextActionResult.Sink end)
bind("SB_Lock",{Enum.KeyCode.T,Enum.KeyCode.ButtonR3},function(state) if state==Enum.UserInputState.Begin then chooseLock() end return Enum.ContextActionResult.Sink end)
bind("SB_Menu",{Enum.KeyCode.M,Enum.KeyCode.ButtonSelect},function(state) if state==Enum.UserInputState.Begin then hud:ToggleMenu() end return Enum.ContextActionResult.Sink end)
bind("SB_Emote",{Enum.KeyCode.V,Enum.KeyCode.DPadDown},function(state) if state==Enum.UserInputState.Begin then hud:ToggleEmotes() end return Enum.ContextActionResult.Sink end)

UserInputService.InputBegan:Connect(function(input,gpe)
	if input.KeyCode==Enum.KeyCode.Space or input.KeyCode==Enum.KeyCode.ButtonA then jumpHeld=true end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode==Enum.KeyCode.Space or input.KeyCode==Enum.KeyCode.ButtonA then jumpHeld=false end
end)

local function fallbackPunch(combo,variantName)
	if not currentCharacter then return end
	local upper=currentCharacter:FindFirstChild("UpperTorso") or currentCharacter:FindFirstChild("Torso")
	if not upper then return end
	local right=upper:FindFirstChild("RightShoulder")
	local left=upper:FindFirstChild("LeftShoulder")
	local waist=upper:FindFirstChild("Waist")
	local joint=(combo%2==1 and right or left)
	if not joint or not joint:IsA("Motor6D") then return end
	local target=CFrame.Angles(math.rad(variantName=="Uppercut" and -95 or -55),0,math.rad(combo%2==1 and -25 or 25))
	TweenService:Create(joint,TweenInfo.new(0.07,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Transform=target}):Play()
	if waist and waist:IsA("Motor6D") then TweenService:Create(waist,TweenInfo.new(0.07),{Transform=CFrame.Angles(0,math.rad(combo%2==1 and -18 or 18),0)}):Play() end
	task.delay(0.1,function()
		if joint.Parent then TweenService:Create(joint,TweenInfo.new(0.12),{Transform=CFrame.new()}):Play() end
		if waist and waist.Parent then TweenService:Create(waist,TweenInfo.new(0.12),{Transform=CFrame.new()}):Play() end
	end)
end

State.OnClientEvent:Connect(function(kind,...)
	local a={...}
	if kind=="Profile" then hud:UpdateProfile(a[1])
	elseif kind=="Cooldown" then hud:StartCooldown(a[1],a[2])
	elseif kind=="M1" then fallbackPunch(a[1],a[2])
	elseif kind=="Toast" then hud:Toast(a[1],a[2])
	elseif kind=="Announcement" then hud:Toast(a[1],true) end
end)

FX.OnClientEvent:Connect(function(kind,...)
	local a={...}
	if kind=="Kill" then
		local killer,victim,streak=a[1],a[2],a[3]
		if killer and victim then
			hud:Toast(("%s shattered %s%s"):format(killer.DisplayName,victim.DisplayName,streak>=5 and ("  •  "..streak.." STREAK") or ""),true)
		end
	elseif kind=="Announcement" then
		hud:Toast(a[1],true)
	else
		Effects:Handle(kind,...)
	end
end)

player:GetAttributeChangedSignal("Ultimate"):Connect(function() hud:SetUltimate(player:GetAttribute("Ultimate") or 0) end)
player:GetAttributeChangedSignal("InSafeZone"):Connect(function() hud:SetSafe(player:GetAttribute("InSafeZone")==true) end)
hud:SetUltimate(player:GetAttribute("Ultimate") or 0)
hud:SetSafe(player:GetAttribute("InSafeZone")==true)

RunService.RenderStepped:Connect(function()
	if lockTarget and currentRoot then
		local hum=lockTarget:FindFirstChildOfClass("Humanoid")
		local targetRoot=lockTarget:FindFirstChild("HumanoidRootPart")
		if not hum or hum.Health<=0 or not targetRoot or (targetRoot.Position-currentRoot.Position).Magnitude>95 then clearLock() return end
		local look=Vector3.new(targetRoot.Position.X,currentRoot.Position.Y,targetRoot.Position.Z)
		if (look-currentRoot.Position).Magnitude>0.1 then currentRoot.CFrame=CFrame.lookAt(currentRoot.Position,look) end
	end
end)

workspace.CurrentCamera.FieldOfView=74
Meta:FireServer("RequestProfile")
print("[Shatterbound] client ready")
