local WeaponConfig = {
	Weapons = {
		Fists = {
			Name = "Fists",
			Type = "Melee",
			Damage = 25,
			Range = 6,
			Cooldown = 0.4,
			SwingSound = "rbxasset://sounds/action_jump.mp3", -- เสียงวู้ชลมปล่อยหมัด (pitched up)
			HitSound = "rbxasset://sounds/impact_water.mp3", -- เสียงกระทบเนื้อเยื่อซอมบี้
			
			-- ใส่ ID อนิเมชั่นสำหรับการต่อสู้ด้วยหมัด (หากต้องการนำเข้าคีย์เฟรมเอง)
			IdleAnim = "rbxassetid://YOUR_ID_HERE",
			AttackAnims = {
				"rbxassetid://YOUR_ID_HERE", -- คอมโบ 1 (หมัดขวาตรง)
				"rbxassetid://YOUR_ID_HERE", -- คอมโบ 2 (หมัดซ้ายตรง)
				"rbxassetid://YOUR_ID_HERE"  -- คอมโบ 3 (อัปเปอร์คัทขวา)
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
			
			IdleAnim = "rbxassetid://YOUR_ID_HERE", 
			AttackAnims = {
				"rbxassetid://YOUR_ID_HERE"
			}
		}
	}
}

return WeaponConfig
