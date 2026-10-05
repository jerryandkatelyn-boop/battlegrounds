--!nonstrict
local Players = game:GetService("Players")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.TownShared.TownConfig)
local Policy = require(script.Parent.QueueConfig)
local State = require(script.Parent.QueueState)

local QueueService = {}
QueueService.__index = QueueService

local function clock() return workspace:GetServerTimeNow() end
local function guid() return HttpService:GenerateGUID(false) end

function QueueService.new(remotes, town)
	local self = setmetatable({}, QueueService)
	self.remotes = remotes
	self.town = town
	self.sessions = {}
	self.lastRequest = {}
	self.channels = {}
	self.preview = RunService:IsStudio() and Config.StudioPreview
	self.jobId = game.JobId ~= "" and game.JobId or "studio-" .. guid()
	self.running = true
	local usedIds = {}
	for _, destination in ipairs(Config.Destinations) do
		if destination.PlaceId > 0 then usedIds[destination.PlaceId] = (usedIds[destination.PlaceId] or 0) + 1 end
	end
	for _, destination in ipairs(Config.Destinations) do
		assert(destination.MinPlayers >= 1 and destination.MaxPlayers >= destination.MinPlayers and destination.MaxPlayers <= 50, "Invalid queue sizes")
		local building = town:FindFirstChild(destination.Building)
		local anchor = building and building:FindFirstChild("QueueAnchor")
		assert(anchor and anchor:IsA("BasePart"), "Missing queue entrance: " .. destination.Id)
		local available = self.preview or (destination.PlaceId > 0 and usedIds[destination.PlaceId] == 1 and destination.PlaceId ~= game.PlaceId)
		local key = string.format("%s:%s:%d:%d:%d", Policy.Namespace, destination.Id, destination.PlaceId, destination.MinPlayers, destination.MaxPlayers)
		self.channels[destination.Id] = {
			destination = destination, anchor = anchor, available = available, cached = State.New(),
			store = not self.preview and MemoryStoreService:GetHashMap(key) or nil,
			locked = false, failures = 0, nextPoll = 0, waiting = 0, online = available,
		}
		if not available then warn("[Tiny Town] Configure a unique destination PlaceId for " .. destination.Name) end
	end
	return self
end

-- Serialize requests on this server. UpdateAsync serializes the same destination
-- across EVERY lobby server. The returned committed value is the only authority.
function QueueService:_update(channel, transform)
	while channel.locked and self.running do task.wait() end
	if not self.running then return nil end
	channel.locked = true
	local now = clock()
	local function callback(previous)
		local state = State.Clone(previous)
		State.Prune(state, now, Policy)
		transform(state, now)
		return state
	end
	local ok, result = pcall(function()
		if self.preview then return callback(channel.cached) end
		return channel.store:UpdateAsync("state", callback, Policy.StateTTL)
	end)
	channel.locked = false
	if not ok or not result then
		channel.failures += 1
		channel.online = false
		channel.nextPoll = now + math.min(30, Policy.PollSeconds * 2 ^ math.min(channel.failures, 3))
		warn("[Tiny Town] Queue service temporarily unavailable: " .. channel.destination.Id .. " / " .. tostring(result))
		return nil
	end
	channel.failures = 0
	channel.online = true
	channel.cached = result
	channel.revision = (channel.revision or 0) + 1
	channel.waiting = #State.Waiting(result)
	return result
end

function QueueService:_toast(player, message)
	if player.Parent == Players then self.remotes.State:FireClient(player, "Toast", message) end
end

function QueueService:_status(player, session, stateName, extra)
	if player.Parent ~= Players then return end
	local payload = extra or {}
	payload.state = stateName
	payload.id = session and session.destinationId or nil
	payload.joinedAt = session and session.ticket.joinedAt or nil
	payload.preview = self.preview
	self.remotes.State:FireClient(player, "Queue", payload)
end

function QueueService:Catalog(player)
	local entries = {}
	for _, destination in ipairs(Config.Destinations) do
		local channel = self.channels[destination.Id]
		table.insert(entries, { id = destination.Id, waiting = channel.waiting,
			status = not channel.available and "closed" or (channel.online and "online" or "unavailable") })
	end
	local payload = { destinations = entries, preview = self.preview }
	if player then self.remotes.State:FireClient(player, "Catalog", payload)
	else self.remotes.State:FireAllClients("Catalog", payload) end
end

function QueueService:CanInteract(player, channel)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root and humanoid and humanoid.Health > 0 and (root.Position - channel.anchor.Position).Magnitude <= Policy.InteractionDistance
end

function QueueService:Join(player, destinationId)
	if not self.running or player.Parent ~= Players or self.sessions[player] then return end
	local channel = self.channels[destinationId]
	if not channel or not self:CanInteract(player, channel) then return end
	local now = clock()
	if now - (self.lastRequest[player] or 0) < Policy.RequestCooldown then return end
	self.lastRequest[player] = now
	if not channel.available then self:_toast(player, "This destination is opening soon.") return end
	if not channel.online and now < channel.nextPoll then self:_toast(player, "This queue is reconnecting. Please try again shortly.") return end
	local session = {
		destinationId = destinationId,
		ticket = { id = guid(), userId = player.UserId, jobId = self.jobId, joinedAt = now, seenAt = now },
		status = "joining", cancel = false, transfer = nil,
	}
	self.sessions[player] = session -- Set before yielding so concurrent requests cannot enqueue twice.
	self:_status(player, session, "joining")
	local result = self:_update(channel, function(state) State.Join(state, session.ticket, Policy.QueueCapacity) end)
	local ticket = result and result.tickets[tostring(player.UserId)]
	if not ticket or ticket.id ~= session.ticket.id then
		if self.sessions[player] == session then self.sessions[player] = nil end
		self:_status(player, nil, "idle")
		self:_toast(player, result and "This queue is full. Try again in a moment." or "The queue is reconnecting. Please try again.")
		return
	end
	if player.Parent ~= Players or session.cancel then
		session.cancel = true
		self:_remove(player, session)
		return
	end
	session.status = "waiting"
	self:_process(channel, result)
	channel.nextPoll = 0
	self:Catalog()
end

function QueueService:_remove(player, session)
	local channel = self.channels[session.destinationId]
	local result = self:_update(channel, function(state) State.Remove(state, player.UserId, session.ticket.id) end)
	if result and self.sessions[player] == session then
		self.sessions[player] = nil
		self:_status(player, nil, "idle")
	end
	return result ~= nil
end

function QueueService:Leave(player)
	local session = self.sessions[player]
	if not session then return end
	if session.transfer and session.transfer.attempts > 0 then
		self:_toast(player, "Your teleport is already starting.")
		return
	end
	session.cancel = true
	self:_status(player, session, "leaving")
	if not self:_remove(player, session) then self:_toast(player, "Leaving the queue. Waiting for the connection to recover.") end
end

function QueueService:_failed(player, session, message)
	if self.sessions[player] ~= session then return end
	session.cancel = true
	session.transfer = nil
	self:_status(player, session, "leaving")
	self:_toast(player, message)
	task.spawn(function() self:_remove(player, session) end)
end

function QueueService:_retry(player, session, attemptId, delaySeconds)
	local transfer = session.transfer
	if not transfer or transfer.attemptId ~= attemptId or not transfer.inFlight then return end
	transfer.inFlight = false
	if transfer.attempts >= Policy.MaxTeleportAttempts or clock() + delaySeconds >= transfer.expiresAt then
		self:_failed(player, session, "We couldn't connect to that destination. Please join the queue again.")
		return
	end
	session.status = "retrying"
	self:_status(player, session, "retrying")
	task.delay(delaySeconds, function() self:_attempt(player, session) end)
end

function QueueService:_attempt(player, session)
	if self.sessions[player] ~= session or session.cancel or player.Parent ~= Players then return end
	local transfer = session.transfer
	if not transfer or transfer.inFlight then return end
	if clock() >= transfer.expiresAt then self:_failed(player, session, "This departure expired. Please join the queue again.") return end
	if self.preview then
		self:_toast(player, "Studio preview complete! Live departures work in the published Roblox app.")
		session.cancel = true
		self:_remove(player, session)
		return
	end
	local destination = self.channels[session.destinationId].destination
	transfer.attempts += 1
	transfer.inFlight = true
	transfer.attemptId = guid()
	local attemptId = transfer.attemptId
	session.status = "teleporting"
	self:_status(player, session, "teleporting")
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = transfer.code -- Never sent through our remotes or teleport data.
	options:SetTeleportData({ tinyTown = true, destination = destination.Id, matchId = transfer.matchId,
		sourcePlaceId = game.PlaceId, attemptId = attemptId })
	local ok, errorMessage = pcall(function() TeleportService:TeleportAsync(destination.PlaceId, { player }, options) end)
	if not ok then
		warn("[Tiny Town] Teleport request failed: " .. tostring(errorMessage))
		self:_retry(player, session, attemptId, Policy.RetryDelay)
		return
	end
	task.delay(Policy.TeleportTimeout, function()
		if self.sessions[player] == session and player.Parent == Players then self:_retry(player, session, attemptId, Policy.RetryDelay) end
	end)
end

function QueueService:_process(channel, state)
	local waiting = State.Waiting(state)
	local positions = {}
	for index, ticket in ipairs(waiting) do positions[ticket.id] = index end
	for player, session in pairs(self.sessions) do
		if session.destinationId ~= channel.destination.Id or session.cancel or session.status == "joining" then continue end
		local ticket = state.tickets[tostring(player.UserId)]
		if not ticket or ticket.id ~= session.ticket.id then
			self.sessions[player] = nil
			self:_status(player, nil, "idle")
			self:_toast(player, "Your queue connection expired. Please join again.")
			continue
		end
		local match = ticket.matchId and state.matches[ticket.matchId]
		if match and match.status == "ready" and not session.transfer then
			session.transfer = { matchId = match.id, code = match.code, launchAt = match.launchAt,
				expiresAt = match.expiresAt, attempts = 0, inFlight = false }
			session.status = "countdown"
			self:_status(player, session, "countdown", { launchAt = match.launchAt })
			task.delay(math.max(0, match.launchAt - clock()), function() self:_attempt(player, session) end)
		elseif not session.transfer then
			session.status = match and "reserving" or "waiting"
			self:_status(player, session, session.status, { waiting = #waiting, position = positions[ticket.id],
				minPlayers = self.preview and 1 or channel.destination.MinPlayers })
		end
	end
end

function QueueService:_reserve(channel, matchId)
	local code
	if self.preview then code = "studio-preview"
	else
		local ok, result = pcall(function() return TeleportService:ReserveServerAsync(channel.destination.PlaceId) end)
		if ok then code = result else warn("[Tiny Town] Reservation failed: " .. tostring(result)) end
	end
	local destination = table.clone(channel.destination)
	if self.preview then destination.MinPlayers = 1 end
	local result = self:_update(channel, function(state, now)
		if code then State.Commit(state, matchId, self.jobId, code, now, destination, Policy)
		else State.Abort(state, matchId, self.jobId) end
	end)
	if result then self:_process(channel, result) end
end

function QueueService:_poll(channel)
	local active = false
	for _, session in pairs(self.sessions) do if session.destinationId == channel.destination.Id then active = true break end end
	if not active then
		if not self.preview then
			local revision = channel.revision or 0
			local ok, result = pcall(function() return channel.store:GetAsync("state") end)
			if ok and revision == (channel.revision or 0) then
				channel.online = true
				channel.cached = State.Clone(result)
				State.Prune(channel.cached, clock(), Policy)
				channel.waiting = #State.Waiting(channel.cached)
			elseif not ok and revision == (channel.revision or 0) then channel.online = false end
		end
		channel.nextPoll = clock() + 20 + math.random()
		-- A player may have joined while the idle read was yielding.
		for _, session in pairs(self.sessions) do
			if session.destinationId == channel.destination.Id then channel.nextPoll = 0 break end
		end
		return
	end
	local matchId = guid()
	local destination = table.clone(channel.destination)
	if self.preview then destination.MinPlayers = 1 end
	-- Capture heartbeats before UpdateAsync: callbacks do not read changing local sessions.
	local localTickets = {}
	for player, session in pairs(self.sessions) do
		if session.destinationId == destination.Id then
			table.insert(localTickets, { userId = player.UserId, id = session.ticket.id, cancel = session.cancel or player.Parent ~= Players })
		end
	end
	local result = self:_update(channel, function(state, now)
		for _, ticket in ipairs(localTickets) do
			if ticket.cancel then State.Remove(state, ticket.userId, ticket.id)
			else State.Heartbeat(state, ticket.userId, ticket.id, now) end
		end
		State.Claim(state, now, self.jobId, matchId, destination, Policy)
	end)
	if not result then return end
	channel.nextPoll = clock() + Policy.PollSeconds + math.random()
	for player, session in pairs(self.sessions) do
		if session.destinationId == destination.Id and session.cancel then
			local ticket = result.tickets[tostring(player.UserId)]
			if not ticket or ticket.id ~= session.ticket.id then self.sessions[player] = nil self:_status(player, nil, "idle") end
		end
	end
	self:_process(channel, result)
	local claimed = result.matches[matchId]
	if claimed and claimed.owner == self.jobId then task.spawn(function() self:_reserve(channel, matchId) end) end
end

function QueueService:Start()
	self.remotes.Request.OnServerEvent:Connect(function(player, action, payload)
		if type(action) ~= "string" or #action > 16 then return end
		if action == "Join" then
			if type(payload) == "string" and #payload <= 24 then self:Join(player, payload) end
		elseif action == "Leave" or action == "Snapshot" then
			local now = clock()
			if now - (self.lastRequest[player] or 0) < Policy.RequestCooldown then return end
			self.lastRequest[player] = now
			if action == "Leave" then self:Leave(player)
			else
				self:Catalog(player)
				local session = self.sessions[player]
				self:_status(player, session, session and session.status or "idle", session and session.transfer and { launchAt = session.transfer.launchAt } or nil)
			end
		end
	end)
	TeleportService.TeleportInitFailed:Connect(function(player, result, _, placeId, options)
		local session = self.sessions[player]
		local transfer = session and session.transfer
		if not transfer or not transfer.inFlight or not options then return end
		local destination = self.channels[session.destinationId].destination
		if placeId ~= destination.PlaceId or options.ReservedServerAccessCode ~= transfer.code then return end
		local data = options:GetTeleportData()
		if type(data) ~= "table" or data.attemptId ~= transfer.attemptId then return end
		if result == Enum.TeleportResult.Flooded or result == Enum.TeleportResult.Failure then
			self:_retry(player, session, transfer.attemptId, result == Enum.TeleportResult.Flooded and Policy.FloodRetryDelay or Policy.RetryDelay)
		else self:_failed(player, session, "That destination couldn't be reached. Please try another queue.") end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local session = self.sessions[player]
		if session then session.cancel = true task.spawn(function() self:_remove(player, session) end) end
		self.lastRequest[player] = nil
	end)
	task.spawn(function()
		while self.running do
			for _, destination in ipairs(Config.Destinations) do
				local channel = self.channels[destination.Id]
				if channel.available and not channel.polling and clock() >= channel.nextPoll then
					channel.polling = true
					task.spawn(function()
						local ok, errorMessage = pcall(function() self:_poll(channel) end)
						channel.polling = false
						if not ok then channel.nextPoll = clock() + 10 warn("[Tiny Town] Queue tick: " .. tostring(errorMessage)) end
					end)
				end
			end
			self:Catalog()
			task.wait(2)
		end
	end)
	game:BindToClose(function()
		-- A crashed server is handled by heartbeats/leases. A clean shutdown removes its tickets.
		local remaining = 0
		for player, session in pairs(self.sessions) do
			remaining += 1
			session.cancel = true
			task.spawn(function() self:_remove(player, session) remaining -= 1 end)
		end
		local deadline = clock() + 8
		while remaining > 0 and clock() < deadline do task.wait(0.1) end
		self.running = false
	end)
end

return QueueService
