--!strict
-- Keep IDs at 0 until the matching items are created for THIS experience.
-- These offers are intentionally convenience/cosmetic focused; combat power is never sold.
return {
	Passes = {
		VIP = {
			Id = 0,
			Name = "VIP Fighter",
			Description = "Cosmetic VIP status and future VIP-only visual rewards.",
			Attribute = "VIP",
		},
		EmotePack = {
			Id = 0,
			Name = "Emote Pack",
			Description = "Extra cosmetic emotes. No combat advantages.",
			Attribute = "PremiumEmotes",
		},
	},
	Products = {
		Coins500 = {Id = 0, Coins = 500, Name = "500 Coins"},
		Coins1700 = {Id = 0, Coins = 1700, Name = "1,700 Coins"},
		Coins6000 = {Id = 0, Coins = 6000, Name = "6,000 Coins"},
	},
}
