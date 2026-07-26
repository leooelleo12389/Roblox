local WeaponConfig = {
	Weapons = {
		Knife = {
			Name = "Knife",
			Type = "Melee",
			Damage = 35,
			Range = 8,
			Cooldown = 0.5,
			SwingSound = "rbxasset://sounds/action_jump.mp3", -- Local jump whoosh (PlaybackSpeed will be tuned locally)
			HitSound = "rbxasset://sounds/impact_water.mp3",    -- Local water splash sound (guaranteed to load)
		},
		Pistol = {
			Name = "Pistol",
			Type = "Ranged",
			Damage = 45,
			Range = 150,
			Cooldown = 0.35,
			FireSound = "rbxasset://sounds/impact_explosion_03.mp3", -- Local explosion thud (guaranteed to load)
			ReloadSound = "rbxasset://sounds/volume_slider.ogg",     -- Local slider click sound (guaranteed to load)
			MaxAmmo = 8,
			ReloadTime = 1.6
		}
	}
}

return WeaponConfig
