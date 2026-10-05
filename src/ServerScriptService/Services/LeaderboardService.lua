--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Service = {}
local store = DataStoreService:GetOrderedDataStore("ShatterboundGlobalKills_v1")

local boardPart: BasePart? = nil
local listLabel: TextLabel? = nil

local function createBoardGui(part: BasePart)
	local existing = part:FindFirstChild("GlobalKillsGui")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = "GlobalKillsGui"
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(13, 15, 24)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.14, 0)
	title.BackgroundTransparency = 1
	title.Text = "GLOBAL IMPACT // KILLS"
	title.TextColor3 = Color3.fromRGB(125, 195, 255)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.new(0.06, 0, 0.17, 0)
	list.Size = UDim2.new(0.88, 0, 0.78, 0)
	list.BackgroundTransparency = 1
	list.TextColor3 = Color3.fromRGB(235, 238, 250)
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.Font = Enum.Font.GothamBold
	list.TextSize = 28
	list.Text = "Loading rankings..."
	list.Parent = frame

	listLabel = list
end

function Service:UpdatePlayer(player: Player, totalKills: number)
	task.spawn(function()
		local ok, err = pcall(function()
			store:SetAsync(tostring(player.UserId), totalKills)
		end)

		if not ok then
			warn("[Shatterbound] leaderboard write failed", err)
		end
	end)
end

function Service:Refresh()
	local list = listLabel
	if not boardPart or not list or not list.Parent then
		return
	end

	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, 10)
	end)

	if not ok then
		list.Text = "Rankings unavailable in this session."
		return
	end

	local lines = {}
	for rank, entry in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(entry.key)
		local displayName = "Player " .. entry.key

		if userId then
			pcall(function()
				displayName = Players:GetNameFromUserIdAsync(userId)
			end)
		end

		table.insert(lines, string.format("%02d  %-18s  %d", rank, displayName, entry.value))
	end

	if #lines > 0 then
		list.Text = table.concat(lines, "\n")
	else
		list.Text = "No ranked fighters yet."
	end
end

function Service:Start(arena: Model)
	for _, descendant in ipairs(arena:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("GlobalBoard") then
			boardPart = descendant
			createBoardGui(descendant)
			break
		end
	end

	self:Refresh()

	task.spawn(function()
		while true do
			task.wait(90)
			self:Refresh()
		end
	end)
end

return Service
