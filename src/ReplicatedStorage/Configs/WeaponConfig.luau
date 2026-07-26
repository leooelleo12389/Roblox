local WeaponConfig = {
	Weapons = {
		Knife = {
			Name = "Knife",
			Type = "Melee",
			Damage = 35,
			Range = 8,
			Cooldown = 0.5,
			SwingSound = "rbxasset://sounds/swish.wav", -- Roblox local whoosh sound (always works)
			HitSound = "rbxasset://sounds/splat.wav",    -- Roblox local splat/flesh sound (always works)
		},
		Pistol = {
			Name = "Pistol",
			Type = "Ranged",
			Damage = 45,
			Range = 150,
			Cooldown = 0.35,
			FireSound = "rbxasset://sounds/impact_explosion_03.mp3", -- Roblox local thud sound (always works)
			ReloadSound = "rbxasset://sounds/switch.mp3",            -- Roblox local click sound (always works)
			MaxAmmo = 8,
			ReloadTime = 1.6
		}
	}
}

return WeaponConfig
