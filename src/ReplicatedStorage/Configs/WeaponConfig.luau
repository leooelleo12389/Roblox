local WeaponConfig = {
	Weapons = {
		Knife = {
			Name = "Knife",
			Type = "Melee",
			Damage = 35,
			Range = 8,
			Cooldown = 0.5,
			SwingSound = "rbxassetid://12222216", -- Roblox classic sword slash whoosh sound
			HitSound = "rbxassetid://12222222",    -- Roblox classic sword hit sound
		},
		Pistol = {
			Name = "Pistol",
			Type = "Ranged",
			Damage = 45,
			Range = 150,
			Cooldown = 0.35,
			FireSound = "rbxassetid://130770091",   -- Roblox classic pistol gunshot sound
			ReloadSound = "rbxassetid://131072986", -- Roblox classic weapon reload sound
			MaxAmmo = 8,
			ReloadTime = 1.6
		}
	}
}

return WeaponConfig
