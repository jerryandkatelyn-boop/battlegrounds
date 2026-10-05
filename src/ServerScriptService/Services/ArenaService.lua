--!strict
local Workspace=game:GetService("Workspace")
local Lighting=game:GetService("Lighting")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage.Shared.GameConfig)

local Service={}
local arena

local function part(parent,name,size,cf,color,material,transparency)
	local p=Instance.new("Part")
	p.Name=name p.Anchored=true p.Size=size p.CFrame=cf p.Color=color
	p.Material=material or Enum.Material.Concrete p.Transparency=transparency or 0
	p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth p.Parent=parent
	return p
end

local function neon(parent,size,cf)
	return part(parent,"EnergyLine",size,cf,Color3.fromRGB(80,170,255),Enum.Material.Neon,0.12)
end

local function dummy(parent,pos,index)
	local m=Instance.new("Model") m.Name="TrainingDummy_"..index m:SetAttribute("TrainingDummy",true) m.Parent=parent
	local root=part(m,"HumanoidRootPart",Vector3.new(2,2,1),CFrame.new(pos+Vector3.new(0,3,0)),Color3.new(),Enum.Material.SmoothPlastic,1)
	local torso=part(m,"Torso",Vector3.new(3,4,1.5),CFrame.new(pos+Vector3.new(0,5,0)),Color3.fromRGB(35,40,52),Enum.Material.SmoothPlastic,0)
	local head=part(m,"Head",Vector3.new(2.2,2.2,2.2),CFrame.new(pos+Vector3.new(0,8.1,0)),Color3.fromRGB(220,220,230),Enum.Material.SmoothPlastic,0)
	root.Anchored=true torso.Anchored=true head.Anchored=true
	local h=Instance.new("Humanoid") h.MaxHealth=500 h.Health=500 h.DisplayName="Training Dummy" h.Parent=m
	m.PrimaryPart=root
	h.Died:Connect(function()
		task.delay(2,function()
			if m.Parent then
				local holder=m.Parent
				m:Destroy()
				dummy(holder,pos,index)
			end
		end)
	end)
end

function Service:IsSafePosition(pos)
	local c,s=Config.SafeZone.Center,Config.SafeZone.Size/2
	local d=pos-c
	return math.abs(d.X)<=s.X and math.abs(d.Y)<=s.Y and math.abs(d.Z)<=s.Z
end

function Service:Build()
	local old=Workspace:FindFirstChild("ShatterboundArena") if old then old:Destroy() end
	arena=Instance.new("Model") arena.Name="ShatterboundArena" arena.Parent=Workspace

	Lighting.ClockTime=18.2 Lighting.Brightness=2
	Lighting.Ambient=Color3.fromRGB(70,75,95) Lighting.OutdoorAmbient=Color3.fromRGB(95,100,120)

	part(arena,"ArenaFloor",Vector3.new(230,3,230),CFrame.new(0,-1.5,0),Color3.fromRGB(42,45,55),Enum.Material.Concrete,0)
	part(arena,"CenterPlate",Vector3.new(72,1,72),CFrame.new(0,0.1,0),Color3.fromRGB(52,55,67),Enum.Material.Slate,0)
	for i=-2,2 do
		neon(arena,Vector3.new(2,0.18,210),CFrame.new(i*42,0.12,0))
		neon(arena,Vector3.new(210,0.18,2),CFrame.new(0,0.13,i*42))
	end

	for _,pos in ipairs({Vector3.new(86,7,86),Vector3.new(-86,7,86),Vector3.new(86,7,-72),Vector3.new(-86,7,-72)}) do
		part(arena,"BrokenPillar",Vector3.new(14,14,14),CFrame.new(pos)*CFrame.Angles(0,math.rad(12),math.rad(4)),Color3.fromRGB(65,67,76),Enum.Material.Concrete,0)
		neon(arena,Vector3.new(14.2,0.25,1),CFrame.new(pos+Vector3.new(0,7.1,0)))
	end

	for _,z in ipairs({-102,102}) do part(arena,"BoundaryWall",Vector3.new(230,18,4),CFrame.new(0,9,z),Color3.fromRGB(29,31,40),Enum.Material.Concrete,0) end
	for _,x in ipairs({-102,102}) do part(arena,"BoundaryWall",Vector3.new(4,18,206),CFrame.new(x,9,0),Color3.fromRGB(29,31,40),Enum.Material.Concrete,0) end

	part(arena,"SafeDeck",Vector3.new(70,2,54),CFrame.new(0,1,Config.SafeZone.Center.Z),Color3.fromRGB(26,30,44),Enum.Material.Slate,0)
	local safe=part(arena,"SafeZone",Config.SafeZone.Size,CFrame.new(Config.SafeZone.Center),Color3.fromRGB(80,170,255),Enum.Material.ForceField,0.94)
	safe.CanCollide=false safe.CanQuery=false
	neon(arena,Vector3.new(70,0.3,2),CFrame.new(0,2.1,-138))

	local spawn=Instance.new("SpawnLocation")
	spawn.Name="SafeSpawn" spawn.Size=Vector3.new(14,1,14) spawn.CFrame=CFrame.new(0,2.2,-172)
	spawn.Anchored=true spawn.Neutral=true spawn.Duration=0 spawn.Transparency=1 spawn.CanCollide=false spawn.Parent=arena

	part(arena,"EntryBridge",Vector3.new(26,2,34),CFrame.new(0,1,-122),Color3.fromRGB(48,50,61),Enum.Material.Concrete,0)
	for i,x in ipairs({-22,0,22}) do dummy(arena,Vector3.new(x,2,-148),i) end

	local board=part(arena,"LeaderboardBoard",Vector3.new(32,16,1),CFrame.new(31,10,-189)*CFrame.Angles(0,math.rad(180),0),Color3.fromRGB(18,20,30),Enum.Material.SmoothPlastic,0)
	board:SetAttribute("GlobalBoard",true)

	local kill=part(arena,"KillPlane",Vector3.new(450,4,450),CFrame.new(0,Config.Arena.KillY,0),Color3.new(),Enum.Material.SmoothPlastic,1)
	kill.CanCollide=false
	kill.Touched:Connect(function(hit)
		local c=hit:FindFirstAncestorOfClass("Model")
		local h=c and c:FindFirstChildOfClass("Humanoid")
		if h then h.Health=0 end
	end)
	return arena
end

return Service
