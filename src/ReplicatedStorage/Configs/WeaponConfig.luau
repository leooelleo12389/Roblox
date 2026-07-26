local WeaponConfig = {
	Weapons = {
		Knife = {
			Name = "Knife",
			Type = "Melee",
			Damage = 35,
			Range = 8,
			Cooldown = 0.5,
			SwingSound = "rbxassetid://9117849182", -- Roblox official whoosh sound
			HitSound = "rbxassetid://9114220803",    -- Roblox official flesh impact sound
		},
		Pistol = {
			Name = "Pistol",
			Type = "Ranged",
			Damage = 45,
			Range = 150,
			Cooldown = 0.35,
			FireSound = "rbxassetid://9114223190",   -- Roblox official gun shot sound
			ReloadSound = "rbxassetid://9114227877", -- Roblox official weapon reload sound
			MaxAmmo = 8,
			ReloadTime = 1.6
		}
	}
}

return WeaponConfig
