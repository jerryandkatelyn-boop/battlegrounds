--!nonstrict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local Config = require(ReplicatedStorage:WaitForChild("TownShared"):WaitForChild("TownConfig"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild(Config.RemoteFolder, 20)
if not remotes then warn("[Tiny Town] Lobby server did not start. Check server Output.") return end
local Request = remotes:WaitForChild("Request")
local State = remotes:WaitForChild("State")
local town = workspace:WaitForChild("TinyTown")

local C = {
	Panel = Color3.fromRGB(23, 33, 42), Card = Color3.fromRGB(34, 46, 57),
	Text = Color3.fromRGB(241, 247, 245), Muted = Color3.fromRGB(161, 182, 188),
	Mint = Color3.fromRGB(103, 219, 176), Border = Color3.fromRGB(70, 91, 103),
}

local function make(className, parent, props)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do instance[key] = value end
	instance.Parent = parent
	return instance
end
local function corner(parent, radius) make("UICorner", parent, { CornerRadius = UDim.new(0, radius) }) end
local function stroke(parent, color, transparency)
	return make("UIStroke", parent, { Color = color, Thickness = 1, Transparency = transparency or 0.4 })
end
local function label(parent, text, size, color, position, dimensions, bold)
	return make("TextLabel", parent, { BackgroundTransparency = 1, Text = text, TextSize = size,
		Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium, TextColor3 = color or C.Text,
		TextXAlignment = Enum.TextXAlignment.Left, Position = position, Size = dimensions })
end
local function button(parent, text, position, dimensions, color)
	local result = make("TextButton", parent, { Text = text, TextSize = 14, Font = Enum.Font.GothamBold,
		TextColor3 = C.Text, BackgroundColor3 = color or C.Card, AutoButtonColor = false,
		Position = position, Size = dimensions, Selectable = true })
	corner(result, 10)
	local outline = stroke(result, C.Border)
	local function focus(active)
		TweenService:Create(outline, TweenInfo.new(0.12), { Transparency = active and 0 or 0.4, Color = active and C.Mint or C.Border }):Play()
	end
	result.MouseEnter:Connect(function() focus(true) end)
	result.MouseLeave:Connect(function() focus(false) end)
	result.SelectionGained:Connect(function() focus(true) end)
	result.SelectionLost:Connect(function() focus(false) end)
	return result
end

local previous = playerGui:FindFirstChild("TinyTownHUD")
if previous then previous:Destroy() end
local gui = make("ScreenGui", playerGui, { Name = "TinyTownHUD", ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10, IgnoreGuiInset = false })
local brand = make("Frame", gui, { Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(205, 56),
	BackgroundColor3 = C.Panel, BackgroundTransparency = 0.06 })
corner(brand, 14)
stroke(brand, C.Border, 0.65)
local brandMark = make("Frame", brand, { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = C.Mint })
corner(brandMark, 9)
label(brandMark, "T", 20, C.Panel, UDim2.fromOffset(9, 0), UDim2.fromOffset(24, 32), true)
label(brand, "TINY TOWN", 15, C.Text, UDim2.fromOffset(55, 8), UDim2.fromOffset(142, 24), true)
local badge = label(brand, "GLOBAL QUEUES", 10, C.Mint, UDim2.fromOffset(55, 31), UDim2.fromOffset(142, 14), true)
local menuButton = button(gui, "Destinations", UDim2.new(1, -158, 0, 16), UDim2.fromOffset(142, 46), C.Panel)
local hint = label(gui, "Walk into a building to find your next adventure.", 14, C.Text,
	UDim2.new(0.5, -250, 1, -48), UDim2.fromOffset(500, 28), false)
hint.TextXAlignment = Enum.TextXAlignment.Center
hint.TextStrokeTransparency = 0.7

local toast = make("TextLabel", gui, { Name = "Toast", AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 86), Size = UDim2.fromOffset(480, 58), Visible = false,
	BackgroundColor3 = C.Panel, BackgroundTransparency = 0.02, TextColor3 = C.Text,
	TextSize = 14, Font = Enum.Font.GothamMedium, TextWrapped = true, ZIndex = 5 })
corner(toast, 12)
make("UIPadding", toast, { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) })
local toastVersion = 0
local function showToast(message)
	toastVersion += 1
	local version = toastVersion
	toast.Text = message
	toast.Visible = true
	task.delay(5, function() if version == toastVersion then toast.Visible = false end end)
end

local menu = make("Frame", gui, { Name = "DestinationMenu", AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(460, 560), Visible = false,
	BackgroundColor3 = C.Panel, ZIndex = 2 })
corner(menu, 18)
stroke(menu, C.Border)
label(menu, "WHERE TO NEXT?", 12, C.Mint, UDim2.fromOffset(22, 16), UDim2.new(1, -90, 0, 20), true)
label(menu, "Pick a destination", 24, C.Text, UDim2.fromOffset(22, 40), UDim2.new(1, -90, 0, 34), true)
local menuSubtitle = label(menu, "Queues connect players across every town server.", 12, C.Muted,
	UDim2.fromOffset(22, 82), UDim2.new(1, -44, 0, 30), false)
menuSubtitle.TextWrapped = true
local closeButton = button(menu, "X", UDim2.new(1, -56, 0, 20), UDim2.fromOffset(34, 34))
local scroll = make("ScrollingFrame", menu, { Name = "Destinations", Position = UDim2.fromOffset(16, 122),
	Size = UDim2.new(1, -32, 1, -138), BackgroundTransparency = 1, BorderSizePixel = 0,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 3, ScrollBarImageColor3 = C.Mint, ScrollingDirection = Enum.ScrollingDirection.Y })
make("UIListLayout", scroll, { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
make("UIPadding", scroll, { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 4) })
local cards = {}
local catalog = {}
local queue = { state = "idle" }
local selectedDestination = nil
local waypoint = nil
local waypointHighlight = nil

local function clearWaypoint()
	selectedDestination = nil
	if waypoint then waypoint:Destroy() waypoint = nil end
	if waypointHighlight then waypointHighlight:Destroy() waypointHighlight = nil end
end
local function toggleMenu(value)
	if value == nil then value = not menu.Visible end
	menu.Visible = value
	if menu.Visible and UserInputService.GamepadEnabled then GuiService.SelectedObject = cards[Config.Destinations[1].Id].button
	elseif not menu.Visible then
		local selected = GuiService.SelectedObject
		if selected and selected:IsDescendantOf(menu) then GuiService.SelectedObject = nil end
	end
end

local function guideTo(destination)
	local status = catalog[destination.Id]
	if status and status.status == "closed" then showToast("This destination is opening soon.") return end
	local anchor = town[destination.Building].QueueAnchor
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and (root.Position - anchor.Position).Magnitude <= 18 then
		Request:FireServer("Join", destination.Id)
		toggleMenu(false)
		return
	end
	clearWaypoint()
	selectedDestination = destination
	waypoint = make("BillboardGui", anchor, { Name = "DestinationMarker", Adornee = anchor, AlwaysOnTop = true,
		Size = UDim2.fromOffset(180, 52), StudsOffset = Vector3.new(0, 11, 0), MaxDistance = 300 })
	local marker = make("TextLabel", waypoint, { BackgroundColor3 = C.Panel, BackgroundTransparency = 0.1,
		Size = UDim2.fromScale(1, 1), Text = destination.Name, TextColor3 = destination.Accent,
		TextSize = 16, Font = Enum.Font.GothamBold, TextWrapped = true })
	corner(marker, 12)
	waypointHighlight = make("Highlight", anchor, { Adornee = town[destination.Building].WelcomeMat,
		FillColor = destination.Accent, FillTransparency = 0.65, OutlineColor = destination.Accent,
		OutlineTransparency = 0.1, DepthMode = Enum.HighlightDepthMode.Occluded })
	toggleMenu(false)
	showToast("Follow the " .. destination.Name .. " marker. Walk onto its queue pad to join.")
end

for index, destination in ipairs(Config.Destinations) do
	local card = button(scroll, "", UDim2.new(), UDim2.new(1, -4, 0, 92))
	card.Name = destination.Id
	card.LayoutOrder = index
	local number = make("TextLabel", card, { Position = UDim2.fromOffset(12, 15), Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = destination.Accent, Text = destination.Number, Font = Enum.Font.GothamBold,
		TextSize = 18, TextColor3 = C.Panel })
	corner(number, 12)
	label(card, destination.Name, 17, C.Text, UDim2.fromOffset(72, 10), UDim2.new(1, -94, 0, 26), true)
	label(card, destination.Tagline, 11, C.Muted, UDim2.fromOffset(72, 37), UDim2.new(1, -92, 0, 18), false)
	local count = label(card, "Connecting...", 11, destination.Accent, UDim2.fromOffset(72, 62), UDim2.new(1, -92, 0, 18), true)
	cards[destination.Id] = { button = card, count = count }
	card.Activated:Connect(function() guideTo(destination) end)
end
for index, destination in ipairs(Config.Destinations) do
	local card = cards[destination.Id].button
	card.NextSelectionUp = index == 1 and closeButton or cards[Config.Destinations[index - 1].Id].button
	card.NextSelectionDown = index == #Config.Destinations and closeButton or cards[Config.Destinations[index + 1].Id].button
end
closeButton.NextSelectionDown = cards[Config.Destinations[1].Id].button
closeButton.NextSelectionUp = cards[Config.Destinations[#Config.Destinations].Id].button

local queuePanel = make("Frame", gui, { Name = "ActiveQueue", AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(430, 114), BackgroundColor3 = C.Panel, Visible = false })
corner(queuePanel, 16)
local queueStroke = stroke(queuePanel, C.Mint, 0.25)
local queueTitle = label(queuePanel, "Arena", 18, C.Text, UDim2.fromOffset(18, 14), UDim2.new(1, -136, 0, 26), true)
local queueStatus = label(queuePanel, "Finding players...", 12, C.Muted, UDim2.fromOffset(18, 43), UDim2.new(1, -38, 0, 28), false)
queueStatus.TextWrapped = true
local queueDetail = label(queuePanel, "", 11, C.Mint, UDim2.fromOffset(18, 80), UDim2.new(1, -36, 0, 18), false)
local leaveButton = button(queuePanel, "Leave", UDim2.new(1, -99, 0, 13), UDim2.fromOffset(82, 34))
local progressTrack = make("Frame", queuePanel, { BackgroundColor3 = C.Card, BorderSizePixel = 0,
	Position = UDim2.fromOffset(18, 73), Size = UDim2.new(1, -36, 0, 3) })
local progress = make("Frame", progressTrack, { BackgroundColor3 = C.Mint, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) })

menuButton.Activated:Connect(function() toggleMenu() end)
closeButton.Activated:Connect(function() toggleMenu(false) end)
leaveButton.Activated:Connect(function() Request:FireServer("Leave") end)
ContextActionService:BindAction("TinyTownMenu", function(_, inputState)
	if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then toggleMenu() end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.M, Enum.KeyCode.ButtonY)
ContextActionService:BindAction("TinyTownBack", function(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if menu.Visible then toggleMenu(false) return Enum.ContextActionResult.Sink end
	if queue.state ~= "idle" and queue.state ~= "teleporting" and queue.state ~= "retrying" then
		Request:FireServer("Leave") return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.ButtonB)

local function applyQueue(payload)
	queue = payload
	queuePanel.Visible = payload.state ~= "idle"
	hint.Visible = payload.state == "idle"
	if payload.id then
		local destination = Config.Find(payload.id)
		if destination then
			queueTitle.Text = destination.Name
			queueStroke.Color = destination.Accent
			progress.BackgroundColor3 = destination.Accent
			queueDetail.TextColor3 = destination.Accent
		end
	end
	leaveButton.Visible = payload.state == "waiting" or payload.state == "reserving" or payload.state == "countdown"
	if payload.state ~= "idle" then clearWaypoint() end
	if payload.state == "teleporting" then
		local loading = make("ScreenGui", nil, { Name = "TinyTownDeparture", IgnoreGuiInset = true })
		local background = make("Frame", loading, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Panel })
		local title = label(background, "YOUR NEXT ADVENTURE", 26, C.Text, UDim2.fromScale(0.1, 0.4), UDim2.fromScale(0.8, 0.1), true)
		title.TextXAlignment = Enum.TextXAlignment.Center
		local subtitle = label(background, queueTitle.Text, 18, C.Mint, UDim2.fromScale(0.1, 0.53), UDim2.fromScale(0.8, 0.06), false)
		subtitle.TextXAlignment = Enum.TextXAlignment.Center
		TeleportService:SetTeleportGui(loading)
	end
end

State.OnClientEvent:Connect(function(kind, payload)
	if kind == "Toast" then showToast(payload)
	elseif kind == "Queue" then applyQueue(payload)
	elseif kind == "Catalog" then
		badge.Text = payload.preview and "STUDIO / LOCAL PREVIEW" or "GLOBAL QUEUES"
		menuSubtitle.Text = payload.preview and "Preview the town and queue flow. Live travel runs in the Roblox app." or "Queues connect players across every town server."
		for _, entry in ipairs(payload.destinations) do
			catalog[entry.id] = entry
			local card = cards[entry.id]
			if card then
				card.count.Text = entry.status == "closed" and "Opening soon" or (entry.status == "unavailable" and "Reconnecting..." or (entry.waiting .. " waiting  /  " .. (payload.preview and "local preview" or "all servers")))
			end
		end
	end
end)

local viewportConnection
local function resize()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local view = camera.ViewportSize
	menu.Size = UDim2.fromOffset(math.min(460, view.X - 28), math.max(200, math.min(560, view.Y - 112)))
	toast.Size = UDim2.fromOffset(math.min(480, view.X - 28), 58)
	queuePanel.Size = UDim2.fromOffset(math.min(430, view.X - (UserInputService.TouchEnabled and 96 or 28)), 114)
	hint.Size = UDim2.fromOffset(math.min(500, view.X - 50), 38)
	hint.Position = UDim2.new(0.5, -hint.Size.X.Offset / 2, 1, -54)
	hint.TextSize = view.X < 500 and 11 or 14
	brand.Size = UDim2.fromOffset(view.X < 450 and 170 or 205, 56)
	brand.ClipsDescendants = true
	badge.Size = UDim2.fromOffset(brand.Size.X.Offset - 60, 14)
	badge.TextSize = view.X < 450 and 8 or 10
	if UserInputService.TouchEnabled then queuePanel.Position = UDim2.new(0.5, 0, 1, -116) end
end
local function watchCamera()
	if viewportConnection then viewportConnection:Disconnect() end
	local camera = workspace.CurrentCamera
	if camera then
		camera.FieldOfView = 70
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	end
	resize()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()
local uiElapsed = 0
RunService.Heartbeat:Connect(function(delta)
	uiElapsed += delta
	if uiElapsed < 0.1 then return end
	uiElapsed = 0
	local elapsed = math.max(0, math.floor(workspace:GetServerTimeNow() - (queue.joinedAt or workspace:GetServerTimeNow())))
	if queue.state == "waiting" then
		queueStatus.Text = "Finding your group..."
		queueDetail.Text = string.format("%d:%02d  /  #%s in queue  /  %d waiting", math.floor(elapsed / 60), elapsed % 60, tostring(queue.position or "-"), queue.waiting or 0)
		progress.Size = UDim2.fromScale(math.min(1, (queue.waiting or 0) / math.max(1, queue.minPlayers or 1)), 1)
	elseif queue.state == "countdown" then
		local seconds = math.max(0, math.ceil((queue.launchAt or 0) - workspace:GetServerTimeNow()))
		queueStatus.Text = "Your group is ready. Departing in " .. seconds .. "..."
		queueDetail.Text = queue.preview and "LOCAL PREVIEW / LIVE TRAVEL IN APP" or "Shared departure / All town servers"
		progress.Size = UDim2.fromScale(1 - math.clamp(seconds / 5, 0, 1), 1)
	else
		queueStatus.Text = ({ joining = "Joining queue...", leaving = "Leaving queue...", reserving = "Preparing your destination...",
			teleporting = "Connecting to your destination...", retrying = "Connection interrupted. Trying again..." })[queue.state] or ""
		queueDetail.Text = queue.preview and "LOCAL STUDIO PREVIEW" or "CROSS-SERVER DEPARTURE"
		progress.Size = UDim2.fromScale(queue.state == "teleporting" and 1 or 0.2, 1)
	end
	if selectedDestination and waypoint then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local distance = (root.Position - town[selectedDestination.Building].QueueAnchor.Position).Magnitude
			waypoint:FindFirstChildOfClass("TextLabel").Text = selectedDestination.Name .. "\n" .. math.floor(distance) .. " studs"
		end
	end
end)

Request:FireServer("Snapshot")
print("[Tiny Town] Client interface ready")
