--!strict
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")

local localPlayer=Players.LocalPlayer
local camera=workspace.CurrentCamera
local Effects={}

local settings={CameraShake=true,VFX=true,DamageNumbers=true}
local shake=0
local lastOffset=CFrame.new()

function Effects:SetSettings(nextSettings)
	for k,v in pairs(nextSettings) do if settings[k]~=nil then settings[k]=v==true end end
end

RunService:BindToRenderStep("ShatterboundCameraShake",Enum.RenderPriority.Camera.Value+1,function(dt)
	camera=workspace.CurrentCamera
	if not camera then return end
	camera.CFrame=camera.CFrame*lastOffset:Inverse()
	if settings.CameraShake and shake>0.01 then
		shake=math.max(0,shake-dt*9)
		local p=shake
		lastOffset=CFrame.new((math.random()-0.5)*p,(math.random()-0.5)*p,(math.random()-0.5)*p*0.35)*CFrame.Angles(math.rad((math.random()-0.5)*p),0,math.rad((math.random()-0.5)*p))
		camera.CFrame=camera.CFrame*lastOffset
	else
		lastOffset=CFrame.new()
	end
end)

local function neonPart(size,cf,color,shape)
	local p=Instance.new("Part")
	p.Anchored=true p.CanCollide=false p.CanQuery=false p.CanTouch=false
	p.Material=Enum.Material.Neon p.Color=color p.Transparency=0.08
	p.Size=size p.CFrame=cf p.Shape=shape or Enum.PartType.Block
	p.Parent=workspace.CurrentCamera or workspace
	return p
end

local function burst(position,color,scale)
	if not settings.VFX then return end
	local orb=neonPart(Vector3.new(1,1,1),CFrame.new(position),color,Enum.PartType.Ball)
	local tween=TweenService:Create(orb,TweenInfo.new(0.22,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=Vector3.new(scale,scale,scale),Transparency=1})
	tween:Play() Debris:AddItem(orb,0.3)

	for i=1,6 do
		local dir=CFrame.Angles(0,math.rad((i-1)*60),0).LookVector
		local streak=neonPart(Vector3.new(0.22,0.22,3.5),CFrame.lookAt(position,position+dir)*CFrame.new(0,0,-1.8),color)
		TweenService:Create(streak,TweenInfo.new(0.2),{CFrame=streak.CFrame*CFrame.new(0,0,-7),Transparency=1}):Play()
		Debris:AddItem(streak,0.25)
	end
end

local function ring(position,radius,color)
	if not settings.VFX then return end
	local p=neonPart(Vector3.new(0.25,1,1),CFrame.new(position)*CFrame.Angles(0,0,math.rad(90)),color,Enum.PartType.Cylinder)
	TweenService:Create(p,TweenInfo.new(0.35,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Size=Vector3.new(0.25,radius*2,radius*2),Transparency=1}):Play()
	Debris:AddItem(p,0.4)
end

local function debris(position,radius)
	if not settings.VFX then return end
	for i=1,math.clamp(math.floor(radius/2),5,10) do
		local angle=(i/math.clamp(math.floor(radius/2),5,10))*math.pi*2
		local dist=radius*(0.45+math.random()*0.35)
		local pos=position+Vector3.new(math.cos(angle)*dist,0.4,math.sin(angle)*dist)
		local s=1.2+math.random()*1.8
		local p=Instance.new("Part")
		p.Anchored=true p.CanCollide=false p.CanQuery=false p.Material=Enum.Material.Concrete
		p.Color=Color3.fromRGB(60,63,73) p.Size=Vector3.new(s,s*0.5,s) p.CFrame=CFrame.new(pos)*CFrame.Angles(math.random(),math.random(),math.random())
		p.Parent=workspace
		TweenService:Create(p,TweenInfo.new(0.45,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{CFrame=p.CFrame*CFrame.new(0,2+math.random()*3,0)}):Play()
		task.delay(3,function()
			if p.Parent then TweenService:Create(p,TweenInfo.new(0.5),{Transparency=1}):Play() Debris:AddItem(p,0.55) end
		end)
	end
end

local function damageNumber(position,amount,heavy)
	if not settings.DamageNumbers then return end
	local anchor=Instance.new("Part")
	anchor.Anchored=true anchor.CanCollide=false anchor.CanQuery=false anchor.Transparency=1 anchor.Size=Vector3.one anchor.CFrame=CFrame.new(position+Vector3.new(0,3,0)) anchor.Parent=workspace
	local gui=Instance.new("BillboardGui") gui.Size=UDim2.fromOffset(100,50) gui.AlwaysOnTop=true gui.Parent=anchor
	local label=Instance.new("TextLabel") label.Size=UDim2.fromScale(1,1) label.BackgroundTransparency=1 label.Text=tostring(math.floor(amount+0.5))
	label.Font=Enum.Font.GothamBlack label.TextScaled=true label.TextColor3=heavy and Color3.fromRGB(255,120,100) or Color3.fromRGB(240,245,255)
	label.TextStrokeTransparency=0.35 label.Parent=gui
	TweenService:Create(anchor,TweenInfo.new(0.55),{CFrame=anchor.CFrame*CFrame.new(0,2.5,0)}):Play()
	TweenService:Create(label,TweenInfo.new(0.55),{TextTransparency=1,TextStrokeTransparency=1}):Play()
	Debris:AddItem(anchor,0.6)
end

function Effects:Handle(kind,...)
	local args={...}
	if kind=="Swing" then
		local fighter,combo,variantName,pos=args[1],args[2],args[3],args[4]
		if settings.VFX and pos then
			local side=(combo%2==0) and -1 or 1
			local slash=neonPart(Vector3.new(0.18,3.2,6.5),CFrame.new(pos+Vector3.new(side*1.4,1.2,0))*CFrame.Angles(0,math.rad(side*28),math.rad(side*32)),variantName=="Uppercut" and Color3.fromRGB(190,135,255) or Color3.fromRGB(100,185,255))
			TweenService:Create(slash,TweenInfo.new(0.13),{Transparency=1,Size=Vector3.new(0.05,4.2,8.2)}):Play()
			Debris:AddItem(slash,0.16)
		end
	elseif kind=="Hit" then
		local pos,damage,hitType=args[1],args[2],args[3]
		local heavy=hitType~="Light"
		burst(pos,heavy and Color3.fromRGB(255,105,95) or Color3.fromRGB(110,190,255),heavy and 5.5 or 3.2)
		damageNumber(pos,damage,heavy)
		shake=math.max(shake,heavy and 0.9 or 0.38)
	elseif kind=="Block" then
		local pos=args[1]
		ring(pos,5,Color3.fromRGB(120,200,255))
		shake=math.max(shake,0.35)
	elseif kind=="Ability" then
		local player,index,pos=args[1],args[2],args[3]
		if index==1 then ring(pos,7,Color3.fromRGB(100,185,255))
		elseif index==2 then burst(pos,Color3.fromRGB(175,130,255),6)
		elseif index==3 then ring(pos,12,Color3.fromRGB(255,120,100)) end
		if player==localPlayer then shake=math.max(shake,0.55) end
	elseif kind=="Crater" then
		local pos,radius=args[1],args[2]
		ring(pos,radius,Color3.fromRGB(255,120,95))
		debris(pos,radius)
		shake=math.max(shake,1.2)
	elseif kind=="Ultimate" then
		local player,pos=args[1],args[2]
		ring(pos,18,Color3.fromRGB(120,190,255))
		ring(pos,11,Color3.fromRGB(255,100,120))
		if player==localPlayer then shake=math.max(shake,1.35) end
	elseif kind=="Execution" then
		local _,_,pos=args[1],args[2],args[3]
		burst(pos,Color3.fromRGB(255,75,95),14)
		ring(pos,22,Color3.fromRGB(255,235,180))
		shake=math.max(shake,2.0)
	end
end

return Effects
