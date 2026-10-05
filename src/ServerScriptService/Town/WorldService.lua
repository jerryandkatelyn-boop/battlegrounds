--!nonstrict
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.TownShared.TownConfig)

local WorldService = {}

local function sign(parent, title, subtitle, accent)
	local gui = parent:FindFirstChild("TownSign") or Instance.new("SurfaceGui")
	gui.Name = "TownSign"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(1000, 210)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = parent
	gui:ClearAllChildren()
	local heading = Instance.new("TextLabel")
	heading.Name = "Heading"
	heading.BackgroundTransparency = 1
	heading.Position = UDim2.fromScale(0.04, 0.08)
	heading.Size = UDim2.fromScale(0.92, 0.57)
	heading.Font = Enum.Font.GothamBold
	heading.TextScaled = true
	heading.TextColor3 = Color3.fromRGB(242, 247, 245)
	heading.Text = title
	heading.Parent = gui
	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.BackgroundTransparency = 1
	detail.Position = UDim2.fromScale(0.04, 0.70)
	detail.Size = UDim2.fromScale(0.92, 0.22)
	detail.Font = Enum.Font.GothamMedium
	detail.TextScaled = true
	detail.TextColor3 = accent
	detail.Text = subtitle
	detail.Parent = gui
	return heading, detail
end

function WorldService.Start(town, queues)
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(140, 156, 166)
	Lighting.OutdoorAmbient = Color3.fromRGB(166, 179, 186)
	local atmosphere = Lighting:FindFirstChild("TinyTownAtmosphere") or Instance.new("Atmosphere")
	atmosphere.Name = "TinyTownAtmosphere"
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(211, 230, 235)
	atmosphere.Decay = Color3.fromRGB(166, 186, 189)
	atmosphere.Haze = 0.7
	atmosphere.Parent = Lighting
	local grade = Lighting:FindFirstChild("TinyTownGrade") or Instance.new("ColorCorrectionEffect")
	grade.Name = "TinyTownGrade"
	grade.Contrast = 0.06
	grade.Saturation = 0.03
	grade.TintColor = Color3.fromRGB(255, 251, 244)
	grade.Parent = Lighting
	local defaultBaseplate = workspace:FindFirstChild("Baseplate")
	if defaultBaseplate and defaultBaseplate:IsA("BasePart") then defaultBaseplate:Destroy() end
	local spawn = town.Plaza.TownSpawn
	-- Ensure a leftover default spawn cannot override the town entrance.
	for _, instance in ipairs(workspace:GetDescendants()) do
		if instance:IsA("SpawnLocation") and instance ~= spawn then instance.Enabled = false end
	end
	local function configure(player)
		player.RespawnLocation = spawn
		local function characterAdded(character)
			local root = character:WaitForChild("HumanoidRootPart", 10)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if root and humanoid and player.Character == character then
				humanoid.WalkSpeed = 16
				character:PivotTo(spawn.CFrame + Vector3.new(math.random(-3, 3), 3, 0))
			end
		end
		player.CharacterAdded:Connect(characterAdded)
		if player.Character then task.spawn(characterAdded, player.Character) end
	end
	Players.PlayerAdded:Connect(configure)
	for _, player in ipairs(Players:GetPlayers()) do configure(player) end
	local counterLabels = {}
	for _, destination in ipairs(Config.Destinations) do
		local building = town[destination.Building]
		sign(building.SignBoard, destination.Number .. "  " .. string.upper(destination.Name), destination.Tagline, destination.Accent)
		local heading, detail = sign(building.QueueDisplay, "WALK IN TO QUEUE", "Connecting...", destination.Accent)
		counterLabels[destination.Id] = { heading = heading, detail = detail }
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "QueuePrompt"
		prompt.ActionText = "Join queue"
		prompt.ObjectText = destination.Name
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = building.QueueAnchor
		prompt.Triggered:Connect(function(player) queues:Join(player, destination.Id) end)
	end
	local inside = {}
	Players.PlayerRemoving:Connect(function(player) inside[player] = nil end)
	task.spawn(function()
		local elapsed = 0
		while queues.running do
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local current = nil
				if root and humanoid and humanoid.Health > 0 then
					if root.Position.Y < -25 then character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0)) end
					for _, destination in ipairs(Config.Destinations) do
						local zone = town[destination.Building].QueueZone
						local point = zone.CFrame:PointToObjectSpace(root.Position)
						local half = zone.Size / 2
						if math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z then current = destination.Id break end
					end
				end
				if current and inside[player] ~= current then task.spawn(function() queues:Join(player, current) end) end
				inside[player] = current -- Leaving/reentering is required after cancellation.
			end
			elapsed += 0.4
			if elapsed >= 2 then
				elapsed = 0
				for id, labels in pairs(counterLabels) do
					local channel = queues.channels[id]
					labels.heading.Text = channel.available and "WALK IN TO QUEUE" or "OPENING SOON"
					labels.detail.Text = queues.preview and (channel.waiting .. " WAITING  /  STUDIO PREVIEW")
						or (not channel.available and "A NEW DESTINATION IS ON ITS WAY" or (channel.online and (channel.waiting .. " WAITING ACROSS ALL SERVERS") or "RECONNECTING QUEUE..."))
				end
			end
			task.wait(0.4)
		end
	end)
end

return WorldService
