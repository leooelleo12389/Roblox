local WeaponConfig = {
	Weapons = {
		Knife = {
			Name = "Knife",
			Type = "Melee",
			Damage = 35,
			Range = 8,
			Cooldown = 0.5,
			SwingSound = "rbxasset://sounds/action_jump.mp3",
			HitSound = "rbxasset://sounds/impact_water.mp3",
			
			-- ใส่ ID อนิเมชั่นที่คุณสร้างและส่งออกจาก Roblox Studio (ตามวิดีโอสอน)
			IdleAnim = "rbxassetid://YOUR_ID_HERE", -- ท่าถือมีด
			AttackAnims = {
				"rbxassetid://YOUR_ID_HERE", -- คอมโบ 1 (ฟันขึ้น)
				"rbxassetid://YOUR_ID_HERE", -- คอมโบ 2 (ฟันลง)
				"rbxassetid://YOUR_ID_HERE"  -- คอมโบ 3 (แทง)
			}
		},
		Pistol = {
			Name = "Pistol",
			Type = "Ranged",
			Damage = 45,
			Range = 150,
			Cooldown = 0.35,
			FireSound = "rbxasset://sounds/impact_explosion_03.mp3",
			ReloadSound = "rbxasset://sounds/volume_slider.ogg",
			MaxAmmo = 8,
			ReloadTime = 1.6,
			
			-- ใส่ ID อนิเมชั่นปืนพกถ้ามี
			IdleAnim = "rbxassetid://YOUR_ID_HERE", 
			AttackAnims = {
				"rbxassetid://YOUR_ID_HERE" -- ท่ายิงปืนถีบกลับ
			}
		}
	}
}

return WeaponConfig
