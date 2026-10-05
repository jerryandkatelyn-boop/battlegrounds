--!strict
return {
	Kairo = {
		Id = "Kairo",
		DisplayName = "Kairo",
		Title = "The Impact Heir",
		Description = "A relentless close-range fighter who turns momentum into explosive impact.",
		Price = 0,
		Starter = true,
		MaxHealth = 100,
		M1 = {Damage = {4,4,5,7}, FinalKnockback = 52, UppercutY = 72, DownslamY = -72},
		Abilities = {
			[1] = {Name = "Breakpoint Rush", Description = "Burst forward and drive a kinetic strike through your target.", Cooldown = 8, Damage = 18, GuardBreak = false},
			[2] = {Name = "Rising Comet", Description = "A crushing launcher that sends the enemy skyward.", Cooldown = 10, Damage = 20, GuardBreak = false},
			[3] = {Name = "Faultline Crash", Description = "Smash the ground and rupture the space around you.", Cooldown = 13, Damage = 24, GuardBreak = true},
		},
		Ultimate = {Name = "Heavenbreaker", Description = "Cash in a full Impact Gauge for one catastrophic finishing blow.", Damage = 46, GuardBreak = true, ExecutionThreshold = 46},
	},
}
