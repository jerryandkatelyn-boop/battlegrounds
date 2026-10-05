--!strict
return {
	Namespace = "TinyTown-v1",
	PollSeconds = 5,
	StateTTL = 150,
	TicketTimeout = 45,
	ReservationTimeout = 30,
	ReadyTimeout = 120,
	CountdownSeconds = 5,
	BatchWaitSeconds = 12,
	QueueCapacity = 48, -- Bounded atomic state stays comfortably under the 32 KB item limit.
	MaxActiveMatches = 4,
	RequestCooldown = 0.75,
	MaxTeleportAttempts = 3,
	TeleportTimeout = 22,
	RetryDelay = 3,
	FloodRetryDelay = 15,
	InteractionDistance = 18,
}
