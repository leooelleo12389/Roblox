local WeaponController = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ตัวแปรควบคุมการขยับแขนขวาในมุมมองบุคคลที่หนึ่ง
local rightShoulder = nil
local originalShoulderC0 = nil
local armSwingOffset = CFrame.new()

local WeaponConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("WeaponConfig"))
local WeaponRemotes = require(ReplicatedStorage:WaitForChild("Network"):WaitForChild("WeaponRemotes"))
local SurvivalUIController = require(ReplicatedStorage:WaitForChild("Controllers"):WaitForChild("SurvivalUIController"))

local currentTool = nil
local currentWeaponData = nil
local ammoCount = {} -- เก็บลำดับกระสุนของปืนแต่ละกระบอก { [WeaponName] = ammo }
local isReloading = false
local lastAttackTime = 0
local currentComboIndex = 1
local lastComboTime = 0

-- ฟังก์ชันสร้างเส้นวิถีกระสุนเรืองแสง (Bullet Tracer effect)
local function createBulletTracer(from, to)
	local tracer = Instance.new("Part")
	tracer.Name = "Tracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanTouch = false
	tracer.CanQuery = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 220, 100) -- สีทองเรืองแสง
	
	local distance = (to - from).Magnitude
	tracer.Size = Vector3.new(0.08, 0.08, distance)
	tracer.CFrame = CFrame.new(from:Lerp(to, 0.5), to)
	tracer.Parent = workspace
	
	-- อนิเมชั่นย่อส่วนและจางหายอย่างรวดเร็ว
	local tweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(tracer, tweenInfo, {
		Size = Vector3.new(0, 0, distance),
		Transparency = 1
	})
	tween:Play()
	Debris:AddItem(tracer, 0.15)
end

-- ฟังก์ชันทำเสียงประจุเสียงปืนในตำแหน่งกล้อง
local function playSoundLocal(soundId, volume, playbackSpeed)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = playbackSpeed or 1.0
	sound.Parent = camera
	sound:Play()
	Debris:AddItem(sound, 3)
end

-- ฟังก์ชันสำหรับเซ็ตค่า C0 ของไหล่ขวาอย่างปลอดภัย (รองรับการเปิดใช้งาน Avatar Joint Upgrade ใน Roblox Studio)
local function setShoulderC0(cframe)
	if not rightShoulder then return end
	local success, _ = pcall(function()
		rightShoulder.C0 = cframe
	end)
	if not success then
		pcall(function()
			rightShoulder.Attachment0.CFrame = cframe
		end)
	end
end

-- อนิเมชั่นแกว่งมีดฟันแบบ Procedural (ส่าย RightGrip Joint ตามจังหวะคอมโบ และขยับข้อต่อไหล่ขวา)
local function playProceduralSlash(comboIndex)
	if not currentTool or currentTool.Name ~= "Knife" then return end
	
	local rightGrip = player.Character and player.Character:FindFirstChild("RightGrip", true)
	if not rightGrip then return end
	
	local originalC1 = rightGrip.C1
	
	task.spawn(function()
		local steps = 6
		local duration = 0.08 -- เวลาส่ายไปอย่างรวดเร็ว
		local recoverDuration = 0.12 -- เวลาคืนค่า
		
		if comboIndex == 1 then
			-- 1. ฟันวาดจากซ้ายล่างไปขวาบน
			for i = 1, steps do
				local t = i / steps
				if not rightGrip or not rightGrip.Parent then break end
				rightGrip.C1 = originalC1 
					* CFrame.new(-0.35 + 0.7 * t, -0.25 + 0.5 * t, 0.45 * t) 
					* CFrame.Angles(math.rad(30 - 65 * t), math.rad(-15 + 30 * t), math.rad(-45 + 90 * t))
				
				-- ขยับไหล่ให้วาดแขนตามแนวมีดเฉลียงขึ้นบน
				armSwingOffset = CFrame.new(-0.25 * t, 0.3 * t, -0.45 * t) 
					* CFrame.Angles(math.rad(35 * t), math.rad(15 * t), math.rad(-25 * t))
				task.wait(duration / steps)
			end
			for i = 1, steps do
				local t = 1 - (i / steps)
				if not rightGrip or not rightGrip.Parent then break end
				rightGrip.C1 = originalC1 
					* CFrame.new(-0.35 + 0.7 * t, -0.25 + 0.5 * t, 0.45 * t) 
					* CFrame.Angles(math.rad(30 - 65 * t), math.rad(-15 + 30 * t), math.rad(-45 + 90 * t))
				
				armSwingOffset = CFrame.new(-0.25 * t, 0.3 * t, -0.45 * t) 
					* CFrame.Angles(math.rad(35 * t), math.rad(15 * t), math.rad(-25 * t))
				task.wait(recoverDuration / steps)
			end
		elseif comboIndex == 2 then
			-- 2. ฟันวาดจากขวาบนไปซ้ายล่าง
			for i = 1, steps do
				local t = i / steps
				if not rightGrip or not rightGrip.Parent then break end
				rightGrip.C1 = originalC1 
					* CFrame.new(0.35 - 0.7 * t, 0.25 - 0.5 * t, 0.45 * t) 
					* CFrame.Angles(math.rad(-30 + 65 * t), math.rad(15 - 30 * t), math.rad(45 - 90 * t))
				
				-- ขยับไหล่ให้ท่อนแขนเฉือนกวาดกลับทาง
				armSwingOffset = CFrame.new(0.1 - 0.35 * t, 0.2 - 0.45 * t, -0.4 * t) 
					* CFrame.Angles(math.rad(30 - 50 * t), math.rad(-15 * t), math.rad(25 * t))
				task.wait(duration / steps)
			end
			for i = 1, steps do
				local t = 1 - (i / steps)
				if not rightGrip or not rightGrip.Parent then break end
				rightGrip.C1 = originalC1 
					* CFrame.new(0.35 - 0.7 * t, 0.25 - 0.5 * t, 0.45 * t) 
					* CFrame.Angles(math.rad(-30 + 65 * t), math.rad(15 - 30 * t), math.rad(45 - 90 * t))
				
				armSwingOffset = CFrame.new(0.1 - 0.35 * t, 0.2 - 0.45 * t, -0.4 * t) 
					* CFrame.Angles(math.rad(30 - 50 * t), math.rad(-15 * t), math.rad(25 * t))
				task.wait(recoverDuration / steps)
			end
		elseif comboIndex == 3 then
			-- 3. แทงไปข้างหน้าตรงๆ
			for i = 1, steps do
				local t = i / steps
				if not rightGrip or not rightGrip.Parent then break end
				rightGrip.C1 = originalC1 
					* CFrame.new(0, 0, 0.85 * t) 
					* CFrame.Angles(math.rad(15 * t), 0, 0)
				
				-- ขยับไหล่ขวายื่นแขนแทงลึกไปข้างหน้า
				armSwingOffset = CFrame.new(0, -0.15 * t, -0.7 * t) 
					* CFrame.Angles(math.rad(45 * t), 0, 0)
				task.wait(duration / steps)
			end
			for i = 1, steps do
				local t = 1 - (i / steps)
				if not rightGrip or not rightGrip.Parent then break end
				rightGrip.C1 = originalC1 
					* CFrame.new(0, 0, 0.85 * t) 
					* CFrame.Angles(math.rad(15 * t), 0, 0)
				
				armSwingOffset = CFrame.new(0, -0.15 * t, -0.7 * t) 
					* CFrame.Angles(math.rad(45 * t), 0, 0)
				task.wait(recoverDuration / steps)
			end
		end
		
		armSwingOffset = CFrame.new()
		if rightGrip and rightGrip.Parent then
			rightGrip.C1 = originalC1
		end
	end)
end

-- อนิเมชั่นปืนพกถอยดีดสะท้อนกลับแบบ Procedural (ส่าย RightGrip Joint และขยับข้อไหล่ขวา)
local function playProceduralRecoil()
	if not currentTool or currentTool.Name ~= "Pistol" then return end
	
	local rightGrip = player.Character and player.Character:FindFirstChild("RightGrip", true)
	if not rightGrip then return end
	
	local originalC1 = rightGrip.C1
	
	task.spawn(function()
		local stepsUp = 3
		-- เตะปืนขึ้นด้านบนและดันถอยหลังเล็กน้อย
		for i = 1, stepsUp do
			local t = i / stepsUp
			if not rightGrip or not rightGrip.Parent then break end
			rightGrip.C1 = originalC1 
				* CFrame.new(0, 0.15 * t, 0.3 * t) 
				* CFrame.Angles(math.rad(-18 * t), 0, 0)
			
			-- แขนสะบัดเตะขึ้นสะท้อนกลับ
			armSwingOffset = CFrame.new(0, 0.08 * t, 0.15 * t) 
				* CFrame.Angles(math.rad(8 * t), 0, 0)
			task.wait(0.03)
		end
		
		local stepsDown = 6
		-- คืนปืนกลับมายังตำแหน่งปกติ
		for i = 1, stepsDown do
			local t = 1 - (i / stepsDown)
			if not rightGrip or not rightGrip.Parent then break end
			rightGrip.C1 = originalC1 
				* CFrame.new(0, 0.15 * t, 0.3 * t) 
				* CFrame.Angles(math.rad(-18 * t), 0, 0)
			
			armSwingOffset = CFrame.new(0, 0.08 * t, 0.15 * t) 
				* CFrame.Angles(math.rad(8 * t), 0, 0)
			task.wait(0.025)
		end
		
		armSwingOffset = CFrame.new()
		if rightGrip and rightGrip.Parent then
			rightGrip.C1 = originalC1
		end
	end)
end

-- ดักจับจังหวะการกดเมาส์ซ้ายหรือเริ่มสั่งโจมตี (Attack logic)
local function performAttack()
	if not currentTool or not currentWeaponData then return end
	if tick() - lastAttackTime < currentWeaponData.Cooldown then return end
	
	local char = player.Character
	if not char or not char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildOfClass("Humanoid").Health <= 0 then return end
	
	local now = tick()
	-- ตรวจสอบเวลาระหว่างการโจมตี หากเกิน 1 วินาที ให้รีเซ็ตคอมโบกลับไปคลิกครั้งที่ 1
	if now - lastComboTime > 1.0 then
		currentComboIndex = 1
	end
	
	lastAttackTime = now
	lastComboTime = now
	
	if currentWeaponData.Type == "Melee" then
		-- 🗡️ [โจมตีระยะประชิด]
		-- เล่นเสียงเหวี่ยงอาวุธ (เร่งสปีดเสียงกระโดดทำเสียง Whoosh สั้น)
		playSoundLocal(currentWeaponData.SwingSound, 0.45, 2.5)
		
		-- บันทึกค่าคอมโบรอบนี้ และอัปเดตรอบถัดไป (1 -> 2 -> 3 -> 1)
		local thisCombo = currentComboIndex
		currentComboIndex = currentComboIndex % 3 + 1
		
		-- เล่นอนิเมชั่นดาบแกว่ง สั่งแขนตัวละครแกว่งจริง และทริกเกอร์ Tool swing ในระบบหลัก
		playProceduralSlash(thisCombo)
		currentTool:Activate() -- สั่งแกว่งแขนมาตรฐานของ Roblox
		
		local animate = char:FindFirstChild("Animate")
		local toolanim = animate and animate:FindFirstChild("toolanim")
		if toolanim then
			-- คอมโบที่ 3 (แทง) ใช้ท่า Lunge ยื่นไปข้างหน้าตรงๆ, คอมโบ 1-2 ใช้ท่าฟันปกติ
			if thisCombo == 3 then
				toolanim.Value = "Lunge"
			else
				toolanim.Value = "Slash"
			end
		end
		
		-- ทำการ Raycast จากกึ่งกลางหน้าจอกล้อง
		local ray = camera:ViewportPointToRay(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {char}
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		
		local result = workspace:Raycast(ray.Origin, ray.Direction * currentWeaponData.Range, raycastParams)
		
		if result then
			local hitInstance = result.Instance
			local hitPos = result.Position
			local model = hitInstance:FindFirstAncestorOfClass("Model")
			local targetHumanoid = model and model:FindFirstChildOfClass("Humanoid")
			
			-- แจ้งเซิร์ฟเวอร์ว่ามีการโจมตีโดนเป้าหมาย
			WeaponRemotes.WeaponAttack:FireServer("Melee", currentTool.Name, targetHumanoid, hitInstance, hitPos)
		end
		
	elseif currentWeaponData.Type == "Ranged" then
		-- 🔫 [โจมตีระยะไกล / ยิงปืน]
		if isReloading then return end
		
		local currentAmmo = ammoCount[currentTool.Name] or currentWeaponData.MaxAmmo
		if currentAmmo <= 0 then
			-- เล่นเสียงคลิกปืนเปล่าไร้กระสุน (Dry fire sound)
			playSoundLocal("rbxasset://sounds/volume_slider.ogg", 0.4)
			return
		end
		
		-- หักลดกระสุน
		currentAmmo = currentAmmo - 1
		ammoCount[currentTool.Name] = currentAmmo
		SurvivalUIController.SetWatchAmmo(true, currentAmmo, currentWeaponData.MaxAmmo)
		
		-- เล่นเสียงปืนยิง (ปรับสปีดเร่งระดับเสียงของเสียงระเบิดโลคอลเป็นปืนยิงแหลมสะใจ)
		playSoundLocal(currentWeaponData.FireSound, 0.65, 1.8)
		
		-- เล่นอนิเมชั่นแรงดีดปืน ส่ายแขนเล็กน้อย และทริกเกอร์ Tool swing
		playProceduralRecoil()
		currentTool:Activate() -- สั่งยิงปืน/แกว่งแขนมาตรฐานของ Roblox
		local animate = char:FindFirstChild("Animate")
		local toolanim = animate and animate:FindFirstChild("toolanim")
		if toolanim then
			toolanim.Value = "Slash"
		end
		
		-- ทำการหาตำแหน่งปากกระบอกปืน (หรือใช้ตำแหน่งกริปปืนแทน)
		local muzzlePart = currentTool:FindFirstChild("Muzzle") or currentTool:FindFirstChild("Handle")
		local muzzlePos = muzzlePart and muzzlePart.Position or char.PrimaryPart.Position
		
		-- ทำการ Raycast จากกึ่งกลางหน้าจอกล้องออกไปตามทิศทางกล้อง
		local ray = camera:ViewportPointToRay(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {char}
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		
		local maxRange = currentWeaponData.Range
		local result = workspace:Raycast(ray.Origin, ray.Direction * maxRange, raycastParams)
		
		local targetPos = ray.Origin + ray.Direction * maxRange
		local hitInstance = nil
		local targetHumanoid = nil
		
		if result then
			targetPos = result.Position
			hitInstance = result.Instance
			local model = hitInstance:FindFirstAncestorOfClass("Model")
			targetHumanoid = model and model:FindFirstChildOfClass("Humanoid")
		end
		
		-- สร้างเส้นวิถีกระสุนเรืองแสง
		createBulletTracer(muzzlePos, targetPos)
		
		-- ส่งข้อมูลการยิงให้ฝั่ง Server จัดการ
		WeaponRemotes.WeaponAttack:FireServer("Ranged", currentTool.Name, targetHumanoid, hitInstance, targetPos)
	end
end

-- ฟังก์ชันทำการรีโหลดกระสุนปืน
local function performReload()
	if not currentTool or not currentWeaponData or currentWeaponData.Type ~= "Ranged" then return end
	if isReloading then return end
	
	local currentAmmo = ammoCount[currentTool.Name] or currentWeaponData.MaxAmmo
	if currentAmmo >= currentWeaponData.MaxAmmo then return end -- กระสุนเต็มอยู่แล้ว
	
	isReloading = true
	print("[WeaponController]: 🔄 กำลังบรรจุกระสุนใหม่...")
	
	-- เล่นเสียงปืนรีโหลดกระสุน (สปอว์นดับเบิ้ลคลิกแคล็กสไตล์รีโหลดปืน)
	playSoundLocal(currentWeaponData.ReloadSound, 0.55, 0.9)
	task.spawn(function()
		task.wait(0.3)
		if currentTool and isReloading then
			playSoundLocal(currentWeaponData.ReloadSound, 0.55, 1.2)
		end
	end)
	
	-- ดีเลย์ตามเวลาการรีโหลดใน Config
	task.wait(currentWeaponData.ReloadTime)
	
	-- เติมกระสุนเต็ม
	ammoCount[currentTool.Name] = currentWeaponData.MaxAmmo
	isReloading = false
	
	-- อัปเดตข้อมูลบนหน้าปัดนาฬิกาใหม่
	if currentTool and currentWeaponData and currentTool.Parent == player.Character then
		SurvivalUIController.SetWatchAmmo(true, currentWeaponData.MaxAmmo, currentWeaponData.MaxAmmo)
		print("[WeaponController]: 🟢 บรรจุกระสุนเสร็จสิ้น!")
	end
end

-- ฟังก์ชันติดตั้งตัวดักจับเหตุการณ์ของตัวละคร (Equip / Unequip detection)
local function setupCharacterEvents(char)
	-- ดึงข้อต่อหัวไหล่ขวาเมื่อตัวละครโหลด
	rightShoulder = char:WaitForChild("RightUpperArm", 5) and char.RightUpperArm:FindFirstChild("RightShoulder")
		or char:WaitForChild("Torso", 5) and char.Torso:FindFirstChild("Right Shoulder")
	
	if rightShoulder then
		local success, val = pcall(function() return rightShoulder.C0 end)
		if success then
			originalShoulderC0 = val
		else
			pcall(function()
				originalShoulderC0 = rightShoulder.Attachment0.CFrame
			end)
		end
	end

	-- ตรวจสอบเมื่อมีการหยิบอาวุธขึ้นมาถือ (ChildAdded to Character)
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			currentTool = child
			local weaponData = WeaponConfig.Weapons[child.Name]
			
			-- รีเซ็ตอนิเมชั่นหัวไหล่และค่าคอมโบใหม่
			armSwingOffset = CFrame.new()
			currentComboIndex = 1
			lastComboTime = 0
			
			if weaponData then
				currentWeaponData = weaponData
				print("[WeaponController]: 🗡️ ติดตั้งอาวุธ -> " .. child.Name)
				
				-- หากเป็นอาวุธปืน ให้ดึงปริมาณกระสุนและส่งข้อมูลไปโชว์บนหน้าปัดนาฬิกา
				if weaponData.Type == "Ranged" then
					if not ammoCount[child.Name] then
						ammoCount[child.Name] = weaponData.MaxAmmo
					end
					SurvivalUIController.SetWatchAmmo(true, ammoCount[child.Name], weaponData.MaxAmmo)
				end
			end
		end
	end)
	
	-- ตรวจสอบเมื่อมีการเก็บหรือถอดอาวุธ (ChildRemoved from Character)
	char.ChildRemoved:Connect(function(child)
		if child == currentTool then
			currentTool = nil
			currentWeaponData = nil
			isReloading = false
			
			-- คืนค่า C0 หัวไหล่กลับสู่สภาพเริ่มต้น และล้างค่าคอมโบ
			armSwingOffset = CFrame.new()
			if rightShoulder and originalShoulderC0 then
				setShoulderC0(originalShoulderC0)
			end
			currentComboIndex = 1
			lastComboTime = 0
			
			SurvivalUIController.SetWatchAmmo(false) -- ซ่อนแถบกระสุนบนนาฬิกา
			print("[WeaponController]: ❌ เก็บอาวุธเรียบร้อย")
		end
	end)
end

function WeaponController.Init()
	print("WeaponController: บูตระบบควบคุมอาวุธฝั่ง Client สำเร็จ!")
	
	player.CharacterAdded:Connect(setupCharacterEvents)
	if player.Character then
		setupCharacterEvents(player.Character)
	end
	
	-- ตรวจจับคลิกการโจมตีเมื่อถืออาวุธ
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if UserInputService:GetFocusedTextBox() then return end
		
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			performAttack()
		elseif input.KeyCode == Enum.KeyCode.R then
			performReload()
		end
	end)

	-- เชื่อมเหตุการณ์ RenderStepped เพื่อควบคุมการก้มเงยและแกว่งของข้อไหล่ขวาตามมุมกล้องและคอมโบ
	RunService.RenderStepped:Connect(function()
		if not currentTool or not rightShoulder or not originalShoulderC0 then
			return
		end
		
		-- ตรวจจับว่ากระดูกหัวไหล่ยังมีชีวิตอยู่ (ป้องกันข้อผิดพลาดการเกิดใหม่)
		if not rightShoulder.Parent then
			rightShoulder = player.Character and (player.Character:FindFirstChild("RightShoulder", true) or player.Character:FindFirstChild("Right Shoulder", true))
			if rightShoulder then
				local success, val = pcall(function() return rightShoulder.C0 end)
				if success then
					originalShoulderC0 = val
				else
					pcall(function()
						originalShoulderC0 = rightShoulder.Attachment0.CFrame
					end)
				end
			end
			return
		end
		
		-- คำนวณมุมก้มเงยของกล้อง (Camera Y Pitch)
		local cameraDirection = camera.CFrame.LookVector
		local pitch = math.asin(cameraDirection.Y)
		
		-- หมุนข้อต่อไหล่ขวาให้ก้มเงยตามกล้อง + คอยบวก CFrame อนิเมชั่นแกว่ง/เตะถอยของคอมโบ (armSwingOffset)
		setShoulderC0(originalShoulderC0 
			* CFrame.Angles(pitch, 0, 0) 
			* armSwingOffset)
	end)
end

return WeaponController
