--!strict
local DataStoreService=game:GetService("DataStoreService")
local Players=game:GetService("Players")
local Service={}
local store=DataStoreService:GetOrderedDataStore("ShatterboundGlobalKills_v1")
local boardPart

local function guiFor(part)
	local old=part:FindFirstChild("GlobalKillsGui") if old then old:Destroy() end
	local gui=Instance.new("SurfaceGui") gui.Name="GlobalKillsGui" gui.Face=Enum.NormalId.Front gui.PixelsPerStud=40 gui.Parent=part
	local f=Instance.new("Frame") f.Size=UDim2.fromScale(1,1) f.BackgroundColor3=Color3.fromRGB(13,15,24) f.BorderSizePixel=0 f.Parent=gui
	local t=Instance.new("TextLabel") t.Size=UDim2.new(1,0,0.14,0) t.BackgroundTransparency=1 t.Text="GLOBAL IMPACT // KILLS" t.TextColor3=Color3.fromRGB(125,195,255) t.Font=Enum.Font.GothamBlack t.TextScaled=true t.Parent=f
	local l=Instance.new("TextLabel") l.Name="List" l.Position=UDim2.new(0.06,0,0.17,0) l.Size=UDim2.new(0.88,0,0.78,0) l.BackgroundTransparency=1 l.TextColor3=Color3.fromRGB(235,238,250) l.TextXAlignment=Enum.TextXAlignment.Left l.TextYAlignment=Enum.TextYAlignment.Top l.Font=Enum.Font.GothamBold l.TextSize=28 l.Text="Loading rankings..." l.Parent=f
	return l
end

function Service:UpdatePlayer(player,totalKills)
	task.spawn(function()
		local ok,err=pcall(function() store:SetAsync(tostring(player.UserId),totalKills) end)
		if not ok then warn("[Shatterbound] leaderboard write failed",err) end
	end)
end

function Service:Refresh()
	if not boardPart then return end
\tlocal list=listLabel\n\tif not list or not list.Parent then return end

	local ok,pages=pcall(function() return store:GetSortedAsync(false,10) end)
	if not ok then list.Text="Rankings unavailable in this session." return end
	local lines={}
	for rank,entry in ipairs(pages:GetCurrentPage()) do
		local uid=tonumber(entry.key)
		local name="Player "..entry.key
		if uid then pcall(function() name=Players:GetNameFromUserIdAsync(uid) end) end
		table.insert(lines,string.format("%02d  %-18s  %d",rank,name,entry.value))
	end
	list.Text=#lines>0 and table.concat(lines,"\n") or "No ranked fighters yet."
end

function Service:Start(arena)
	for _,d in ipairs(arena:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("GlobalBoard") then boardPart=d guiFor(d) break end
	end
	self:Refresh()
	task.spawn(function() while task.wait(90) do self:Refresh() end end)
end

return Service
