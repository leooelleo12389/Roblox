local WeaponConfig = {
	Weapons = {
		Knife = {
			Name = "Knife",
			Type = "Melee",
			Damage = 35,
			Range = 8,
			Cooldown = 0.5,
			SwingSound = "rbxasset://sounds/swish.wav", -- standard built-in sound
			HitSound = "rbxassetid://566593606",        -- stab sound ID
		},
		Pistol = {
			Name = "Pistol",
			Type = "Ranged",
			Damage = 45,
			Range = 150,
			Cooldown = 0.35,
			FireSound = "rbxassetid://333465389",       -- standard pistol fire sound ID
			ReloadSound = "rbxassetid://131072986",     -- pistol reload sound ID
			MaxAmmo = 8,
			ReloadTime = 1.6
		}
	}
}

return WeaponConfig
