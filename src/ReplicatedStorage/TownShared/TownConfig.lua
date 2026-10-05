--!strict
-- Each destination must be a DIFFERENT published place in this experience.
-- Set the four PlaceId values before testing real teleports.
local Config = {
	Name = "Tiny Town",
	RemoteFolder = "TinyTownRemotes",
	StudioPreview = true, -- Studio uses a local queue and never calls TeleportService.
	Destinations = {
		{ Id = "arena", Name = "Arena", Building = "Arena", Tagline = "Meet your next rivals", PlaceId = 0,
			MinPlayers = 2, MaxPlayers = 8, Accent = Color3.fromRGB(86, 172, 255), Number = "01" },
		{ Id = "dojo", Name = "Dojo", Building = "Dojo", Tagline = "Find your fighting partner", PlaceId = 0,
			MinPlayers = 2, MaxPlayers = 2, Accent = Color3.fromRGB(255, 145, 111), Number = "02" },
		{ Id = "rooftops", Name = "Rooftops", Building = "Rooftops", Tagline = "Take it to the skyline", PlaceId = 0,
			MinPlayers = 2, MaxPlayers = 6, Accent = Color3.fromRGB(177, 149, 255), Number = "03" },
		{ Id = "training", Name = "Training Lab", Building = "TrainingLab", Tagline = "Make your next breakthrough", PlaceId = 0,
			MinPlayers = 1, MaxPlayers = 6, Accent = Color3.fromRGB(103, 219, 176), Number = "04" },
	},
}

function Config.Find(id: string)
	for _, destination in ipairs(Config.Destinations) do
		if destination.Id == id then return destination end
	end
	return nil
end

return Config
