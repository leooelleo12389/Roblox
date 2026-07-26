local CombatService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local WeaponConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("WeaponConfig"))
local WeaponRemotes = require(ReplicatedStorage:WaitForChild("Network"):WaitForChild("WeaponRemotes"))

local lastPlayerAttack = {} -- เก็บเวลาสกัดสแปมแฮก { [player] = tick() }

-- ฟังก์ชันสร้างเสียงสปอว์นในพิกัด 3 มิติ (3D Sound Replication)
local function play3DSound(soundId, position, volume, playbackSpeed)
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
	sound.PlaybackSpeed = playbackSpeed or 1.0
	sound.RollOffMaxDistance = 150
	sound.RollOffMinDistance = 10
	sound.Parent = part
	sound:Play()
	
	Debris:AddItem(part, sound.TimeLength > 0 and (sound.TimeLength / sound.PlaybackSpeed) + 1 or 3)
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
	
	-- 🗡️ 1. สร้างมีดจำลองแบบ Procedural (รุ่นมีใบมีด, กระบังมือ และด้ามไม้)
	if not backpack:FindFirstChild("Knife") then
		local knife = Instance.new("Tool")
		knife.Name = "Knife"
		knife.Grip = CFrame.new(0, -0.2, 0) * CFrame.Angles(0, math.rad(-90), 0)
		
		-- ด้ามจับหลัก (Handle)
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.25, 1.0, 0.35)
		handle.Color = Color3.fromRGB(85, 55, 35) -- สีไม้เข้ม
		handle.Material = Enum.Material.Wood
		handle.Parent = knife
		
		-- กระบังมือ (Guard)
		local guard = Instance.new("Part")
		guard.Name = "Guard"
		guard.Size = Vector3.new(0.35, 0.1, 0.6)
		guard.Color = Color3.fromRGB(130, 130, 135)
		guard.Material = Enum.Material.Metal
		guard.CanCollide = false
		guard.CanTouch = false
		guard.CanQuery = false
		guard.Position = handle.Position + Vector3.new(0, 0.55, 0)
		guard.Parent = knife
		
		local guardWeld = Instance.new("WeldConstraint")
		guardWeld.Part0 = handle
		guardWeld.Part1 = guard
		guardWeld.Parent = handle
		
		-- ใบมีด (Blade)
		local blade = Instance.new("Part")
		blade.Name = "Blade"
		blade.Size = Vector3.new(0.1, 1.2, 0.3)
		blade.Color = Color3.fromRGB(200, 200, 205) -- สีเงินเมทัล
		blade.Material = Enum.Material.Metal
		blade.CanCollide = false
		blade.CanTouch = false
		blade.CanQuery = false
		blade.Position = handle.Position + Vector3.new(0, 1.15, 0.05)
		blade.Parent = knife
		
		local bladeWeld = Instance.new("WeldConstraint")
		bladeWeld.Part0 = handle
		bladeWeld.Part1 = blade
		bladeWeld.Parent = handle
		
		-- ปลายมีดเฉียง (Blade Tip)
		local tip = Instance.new("WedgePart")
		tip.Name = "Tip"
		tip.Size = Vector3.new(0.1, 0.3, 0.3)
		tip.Color = Color3.fromRGB(200, 200, 205)
		tip.Material = Enum.Material.Metal
		tip.CanCollide = false
		tip.CanTouch = false
		tip.CanQuery = false
		tip.CFrame = blade.CFrame * CFrame.new(0, 0.75, 0) * CFrame.Angles(0, 0, math.rad(180))
		tip.Parent = knife
		
		local tipWeld = Instance.new("WeldConstraint")
		tipWeld.Part0 = handle
		tipWeld.Part1 = tip
		tipWeld.Parent = handle
		
		knife.Parent = backpack
	end
	
	-- 🔫 2. สร้างปืนพกจำลองแบบ Procedural (รุ่นโมเดลสมจริง มีด้ามจับ, ลำกล้อง, โกร่งไกปืน)
	if not backpack:FindFirstChild("Pistol") then
		local pistol = Instance.new("Tool")
		pistol.Name = "Pistol"
		pistol.Grip = CFrame.new(0, -0.4, 0.3) * CFrame.Angles(math.rad(-15), 0, 0)
		
		-- ด้ามจับปืนหลัก (Handle)
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.3, 0.9, 0.35)
		handle.Color = Color3.fromRGB(30, 30, 32)
		handle.Material = Enum.Material.SmoothPlastic
		handle.Parent = pistol
		
		-- สไลด์ปืนหลัก (Slide)
		local slide = Instance.new("Part")
		slide.Name = "Slide"
		slide.Size = Vector3.new(0.32, 0.4, 1.3)
		slide.Color = Color3.fromRGB(50, 50, 53)
		slide.Material = Enum.Material.Metal
		slide.CanCollide = false
		slide.CanTouch = false
		slide.CanQuery = false
		slide.CFrame = handle.CFrame * CFrame.new(0, 0.55, -0.2)
		slide.Parent = pistol
		
		local slideWeld = Instance.new("WeldConstraint")
		slideWeld.Part0 = handle
		slideWeld.Part1 = slide
		slideWeld.Parent = handle
		
		-- ลำกล้องปืนทรงกระบอก (Barrel)
		local barrel = Instance.new("Part")
		barrel.Name = "Barrel"
		barrel.Shape = Enum.PartType.Cylinder
		barrel.Size = Vector3.new(0.65, 0.2, 0.2)
		barrel.Color = Color3.fromRGB(15, 15, 15)
		barrel.Material = Enum.Material.Metal
		barrel.CanCollide = false
		barrel.CanTouch = false
		barrel.CanQuery = false
		barrel.CFrame = slide.CFrame * CFrame.new(0, 0.1, -0.6) * CFrame.Angles(0, math.rad(90), 0)
		barrel.Parent = pistol
		
		local barrelWeld = Instance.new("WeldConstraint")
		barrelWeld.Part0 = handle
		barrelWeld.Part1 = barrel
		barrelWeld.Parent = handle
		
		-- โกร่งไกปืน (Trigger Guard)
		local guard = Instance.new("Part")
		guard.Name = "TriggerGuard"
		guard.Size = Vector3.new(0.1, 0.25, 0.3)
		guard.Color = Color3.fromRGB(30, 30, 32)
		guard.Material = Enum.Material.SmoothPlastic
		guard.CanCollide = false
		guard.CanTouch = false
		guard.CanQuery = false
		guard.CFrame = handle.CFrame * CFrame.new(0, 0.35, -0.25)
		guard.Parent = pistol
		
		local guardWeld = Instance.new("WeldConstraint")
		guardWeld.Part0 = handle
		guardWeld.Part1 = guard
		guardWeld.Parent = handle
		
		-- จุดปากกระบอกอ้างอิงแสงยิงกระสุน (Muzzle)
		local muzzle = Instance.new("Part")
		muzzle.Name = "Muzzle"
		muzzle.Size = Vector3.new(0.1, 0.1, 0.1)
		muzzle.Transparency = 1
		muzzle.CanCollide = false
		muzzle.CanTouch = false
		muzzle.CanQuery = false
		muzzle.CFrame = slide.CFrame * CFrame.new(0, 0.1, -0.95)
		muzzle.Parent = pistol
		
		local muzzleWeld = Instance.new("WeldConstraint")
		muzzleWeld.Part0 = handle
		muzzleWeld.Part1 = muzzle
		muzzleWeld.Parent = handle
		
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
				-- เสียงโจมตีสิ่งมีชีวิต (เร่งระดับความสูงของเสียงน้ำกระเซ็นโลคอลให้กลายเป็นเสียงมีดฟันเข้าเนื้อ)
				play3DSound(weaponData.HitSound, hitPos, 0.5, 1.6)
				spawnHitParticle(hitPos, true)
			else
				-- เสียงมีดฟันโดนกำแพงไม้/ปูน (ใช้เสียงตุ๊บแบบ local)
				play3DSound("rbxasset://sounds/action_jump_land.mp3", hitPos, 0.4)
				spawnHitParticle(hitPos, false)
			end
		elseif attackType == "Ranged" then
			if isOrganicHit then
				-- เสียงยิงเข้าเนื้อเยื่อ (ใช้เสียงสปาชเนื้อเปียกโลคอลแบบเร่งความเร็ว)
				play3DSound("rbxasset://sounds/impact_water.mp3", hitPos, 0.55, 1.6)
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
