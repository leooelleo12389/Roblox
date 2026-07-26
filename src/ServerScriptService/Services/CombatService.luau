local CombatService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local WeaponConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("WeaponConfig"))
local WeaponRemotes = require(ReplicatedStorage:WaitForChild("Network"):WaitForChild("WeaponRemotes"))

local lastPlayerAttack = {} -- เก็บเวลาสกัดสแปมแฮก { [player] = tick() }

-- ฟังก์ชันสร้างเสียงสปอว์นในพิกัด 3 มิติ (3D Sound Replication)
local function play3DSound(soundId, position, volume)
	local part = Instance.new("Part")
	part.Name = "3DSoundSource"
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = workspace
	
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.RollOffMaxDistance = 150
	sound.RollOffMinDistance = 10
	sound.Parent = part
	sound:Play()
	
	Debris:AddItem(part, sound.TimeLength > 0 and sound.TimeLength + 1 or 3)
end

-- ฟังก์ชันสปอว์นเอฟเฟกต์อนุภาคเมื่อโจมตีโดนเป้าหมาย (Particle Splash Effect)
local function spawnHitParticle(position, isOrganic)
	local part = Instance.new("Part")
	part.Name = "HitEffectPart"
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Position = position
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = workspace
	
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	
	local particles = Instance.new("ParticleEmitter")
	particles.Rate = 0
	particles.Lifetime = NumberRange.new(0.15, 0.4)
	particles.Speed = NumberRange.new(4, 9)
	particles.SpreadAngle = Vector2.new(180, 180)
	
	if isOrganic then
		-- สีแดงเลือดสยองขวัญ (สาดเศษซากซอมบี้)
		particles.Color = ColorSequence.new(Color3.fromRGB(160, 5, 5))
		particles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 0)
		})
	else
		-- สีเทาฝุ่นหินหรือเศษไม้สลัว
		particles.Color = ColorSequence.new(Color3.fromRGB(160, 160, 160))
		particles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 0)
		})
	end
	
	particles.Parent = attachment
	particles:Emit(10) -- พ่นสะเก็ดเม็ดอนุภาค 10 เม็ดพร้อมกัน
	
	Debris:AddItem(part, 0.8)
end

-- ฟังก์ชันแจกจ่ายอาวุธเริ่มต้นทดสอบใน Backpack ผู้เล่น
local function giveDefaultWeapons(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	
	-- 🗡️ 1. สร้างมีดจำลองแบบ Procedural
	if not backpack:FindFirstChild("Knife") then
		local knife = Instance.new("Tool")
		knife.Name = "Knife"
		knife.Grip = CFrame.new(0, -0.4, 0)
		
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.3, 1.8, 0.3)
		handle.Color = Color3.fromRGB(180, 180, 185)
		handle.Material = Enum.Material.Metal
		handle.Parent = knife
		
		knife.Parent = backpack
	end
	
	-- 🔫 2. สร้างปืนพกจำลองแบบ Procedural
	if not backpack:FindFirstChild("Pistol") then
		local pistol = Instance.new("Tool")
		pistol.Name = "Pistol"
		pistol.Grip = CFrame.new(0, -0.4, 0.4) * CFrame.Angles(math.rad(-10), 0, 0)
		
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.4, 0.8, 1.4)
		handle.Color = Color3.fromRGB(45, 45, 48)
		handle.Material = Enum.Material.Metal
		handle.Parent = pistol
		
		-- จุดปากกระบอกสำหรับใช้อ้างอิงปล่อยเส้นกระสุนเรืองแสง
		local muzzle = Instance.new("Part")
		muzzle.Name = "Muzzle"
		muzzle.Size = Vector3.new(0.1, 0.1, 0.1)
		muzzle.Transparency = 1
		muzzle.CanCollide = false
		muzzle.CanTouch = false
		muzzle.CanQuery = false
		muzzle.CFrame = handle.CFrame * CFrame.new(0, 0.25, -0.7)
		
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = muzzle
		weld.Parent = handle
		
		muzzle.Parent = pistol
		pistol.Parent = backpack
	end
end

function CombatService.Init()
	print("CombatService: บูตระบบจัดการการต่อสู้ฝั่ง Server สำเร็จ!")
	
	-- ดักจับผู้เล่นสปอว์นตัวละครเพื่อสวมอุปกรณ์
	local function onPlayerAdded(player)
		player.CharacterAdded:Connect(function(char)
			task.wait(0.5) -- รอจนแน่ใจว่าโหลด Backpack สำเร็จ
			giveDefaultWeapons(player)
		end)
		
		if player.Character then
			task.spawn(giveDefaultWeapons, player)
		end
	end
	
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, p)
	end
	
	-- จัดการคำขอรหัส RemoteEvent โจมตีของอาวุธ
	WeaponRemotes.WeaponAttack.OnServerEvent:Connect(function(player, attackType, weaponName, targetHumanoid, hitInstance, hitPos)
		local char = player.Character
		if not char or not char:FindFirstChild("Humanoid") or char.Humanoid.Health <= 0 then return end
		
		-- 1. ตรวจสอบข้อมูลสเปคอาวุธจาก Config
		local weaponData = WeaponConfig.Weapons[weaponName]
		if not weaponData then return end
		
		-- 2. สกัดสแปมโจมตีรวดเร็วเกินจริง (Anti-Cheat Cooldown check)
		local lastAttack = lastPlayerAttack[player] or 0
		if tick() - lastAttack < (weaponData.Cooldown - 0.05) then
			warn("[CombatService]: " .. player.Name .. " พยายามทำความเร็วโจมตีเกินเวลาคูลดาวน์สเปคอาวุธ!")
			return
		end
		lastPlayerAttack[player] = tick()
		
		-- 3. ตรวจสอบระยะพิกัดโจมตีจริงป้องกันการใช้โปรแกรมวาร์ปฟัน (Anti-Cheat Distance check)
		local playerPos = char.PrimaryPart.Position
		local distance = (playerPos - hitPos).Magnitude
		
		-- เผื่อค่าดีเลย์เซิร์ฟเวอร์ (Latency buffer) ประมาณ 18 สตัด
		local maxRangeBuffer = weaponData.Range + 18
		if distance > maxRangeBuffer then
			warn("[CombatService]: " .. player.Name .. " โจมตีไกลผิดปกติ! ระยะห่างจริง: " .. tostring(distance))
			return
		end
		
		-- 4. ประมวลผลความเสียหาย (Apply Damage)
		local isOrganicHit = false
		if targetHumanoid and targetHumanoid.Health > 0 then
			-- ห้ามโจมตีตัวเอง
			if targetHumanoid.Parent ~= char then
				targetHumanoid:TakeDamage(weaponData.Damage)
				isOrganicHit = true
				print(string.format("[CombatService]: %s โจมตีโดน %s! หักพลังชีวิต: %d | เหลือ HP: %.1f", player.Name, targetHumanoid.Parent.Name, weaponData.Damage, targetHumanoid.Health))
			end
		end
		
		-- 5. จำลองเสียงพาดฟันโดนเป้าหมายและสาดอนุภาคเอฟเฟกต์
		if attackType == "Melee" then
			if isOrganicHit then
				-- เสียงโจมตีสิ่งมีชีวิต
				play3DSound(weaponData.HitSound, hitPos, 0.5)
				spawnHitParticle(hitPos, true)
			else
				-- เสียงมีดฟันโดนกำแพงไม้/ปูน (ใช้เสียงตุ๊บแบบ local)
				play3DSound("rbxasset://sounds/action_jump_land.mp3", hitPos, 0.4)
				spawnHitParticle(hitPos, false)
			end
		elseif attackType == "Ranged" then
			if isOrganicHit then
				-- เสียงยิงเข้าเนื้อเยื่อ (ใช้ไฟล์เสียงปะทะเนื้อแบบ local)
				play3DSound("rbxasset://sounds/splat.wav", hitPos, 0.5)
				spawnHitParticle(hitPos, true)
			else
				-- เสียงกระสุนยิงปะทะกำแพงไม้/ปูน (ใช้เสียงตุ๊บแบบ local)
				play3DSound("rbxasset://sounds/action_jump_land.mp3", hitPos, 0.45)
				spawnHitParticle(hitPos, false)
			end
		end
	end)
	
	-- เคลียร์แคชข้อมูลเมื่อผู้เล่นออกจากเซิร์ฟเวอร์
	Players.PlayerRemoving:Connect(function(player)
		lastPlayerAttack[player] = nil
	end)
end

return CombatService
