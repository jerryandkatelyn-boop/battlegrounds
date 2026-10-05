--!strict
-- Pure state transitions. No yielding, API calls, randomness, or callback side effects.
-- MemoryStore UpdateAsync can replay these functions during contention.
local QueueState = {}

export type Ticket = {
	id: string, userId: number, jobId: string, joinedAt: number, seenAt: number, matchId: string?,
}
export type Match = {
	id: string, owner: string, status: string, createdAt: number, expiresAt: number,
	code: string?, launchAt: number?,
}
export type State = { tickets: { [string]: Ticket }, matches: { [string]: Match } }

function QueueState.New(): State
	return { tickets = {}, matches = {} }
end

function QueueState.Clone(previous: State?): State
	local state = QueueState.New()
	if previous then
		for key, ticket in pairs(previous.tickets) do state.tickets[key] = table.clone(ticket) end
		for key, match in pairs(previous.matches) do state.matches[key] = table.clone(match) end
	end
	return state
end

function QueueState.Count(state: State): number
	local count = 0
	for _ in pairs(state.tickets) do count += 1 end
	return count
end

function QueueState.Waiting(state: State): { Ticket }
	local result = {}
	for _, ticket in pairs(state.tickets) do
		if not ticket.matchId then table.insert(result, ticket) end
	end
	table.sort(result, function(a, b)
		if a.joinedAt == b.joinedAt then return a.id < b.id end
		return a.joinedAt < b.joinedAt
	end)
	return result
end

function QueueState.Prune(state: State, now: number, policy)
	for key, ticket in pairs(state.tickets) do
		if now - ticket.seenAt >= policy.TicketTimeout then state.tickets[key] = nil end
	end
	for id, match in pairs(state.matches) do
		local members = 0
		for _, ticket in pairs(state.tickets) do
			if ticket.matchId == id then members += 1 end
		end
		if match.expiresAt <= now or members == 0 then
			state.matches[id] = nil
			for key, ticket in pairs(state.tickets) do
				if ticket.matchId == id then
					-- A ready assignment must never turn back into a new match while a
					-- teleport might still be in flight. Remove it and require rejoining.
					if match.status == "ready" then state.tickets[key] = nil
					else ticket.matchId = nil end
				end
			end
		end
	end
end

function QueueState.Join(state: State, ticket: Ticket, capacity: number): boolean
	local key = tostring(ticket.userId)
	local existing = state.tickets[key]
	if existing then
		-- Idempotent only for this exact session; never replace another server's ticket.
		return existing.id == ticket.id
	end
	if QueueState.Count(state) >= capacity then return false end
	state.tickets[key] = table.clone(ticket)
	return true
end

function QueueState.Remove(state: State, userId: number, ticketId: string): boolean
	local key = tostring(userId)
	local ticket = state.tickets[key]
	if not ticket or ticket.id ~= ticketId then return false end
	state.tickets[key] = nil
	return true
end

function QueueState.Heartbeat(state: State, userId: number, ticketId: string, now: number)
	local ticket = state.tickets[tostring(userId)]
	if ticket and ticket.id == ticketId then ticket.seenAt = now end
end

function QueueState.Claim(state: State, now: number, owner: string, matchId: string, destination, policy): Match?
	local active = 0
	for _ in pairs(state.matches) do active += 1 end
	if active >= policy.MaxActiveMatches or state.matches[matchId] then return nil end
	local waiting = QueueState.Waiting(state)
	if #waiting < destination.MinPlayers then return nil end
	if #waiting < destination.MaxPlayers and now - waiting[1].joinedAt < policy.BatchWaitSeconds then return nil end
	local match: Match = {
		id = matchId, owner = owner, status = "reserving", createdAt = now,
		expiresAt = now + policy.ReservationTimeout,
	}
	state.matches[matchId] = match
	for index = 1, math.min(#waiting, destination.MaxPlayers) do waiting[index].matchId = matchId end
	return match
end

function QueueState.Commit(state: State, matchId: string, owner: string, code: string, now: number, destination, policy): boolean
	local match = state.matches[matchId]
	if not match or match.owner ~= owner or match.status ~= "reserving" or match.expiresAt <= now then return false end
	local count = 0
	for _, ticket in pairs(state.tickets) do if ticket.matchId == matchId then count += 1 end end
	if count < destination.MinPlayers then
		QueueState.Abort(state, matchId, owner)
		return false
	end
	match.status = "ready"
	match.code = code
	match.launchAt = now + policy.CountdownSeconds
	match.expiresAt = now + policy.ReadyTimeout
	return true
end

function QueueState.Abort(state: State, matchId: string, owner: string): boolean
	local match = state.matches[matchId]
	if not match or match.owner ~= owner or match.status ~= "reserving" then return false end
	state.matches[matchId] = nil
	for _, ticket in pairs(state.tickets) do if ticket.matchId == matchId then ticket.matchId = nil end end
	return true
end

return QueueState
