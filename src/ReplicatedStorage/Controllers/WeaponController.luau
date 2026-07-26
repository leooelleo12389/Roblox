local WeaponController = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local WeaponConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("WeaponConfig"))
local WeaponRemotes = require(ReplicatedStorage:WaitForChild("Network"):WaitForChild("WeaponRemotes"))
local SurvivalUIController = require(ReplicatedStorage:WaitForChild("Controllers"):WaitForChild("SurvivalUIController"))

local currentTool = nil
local currentWeaponData = nil
local ammoCount = {} -- เก็บลำดับกระสุนของปืนแต่ละกระบอก { [WeaponName] = ammo }
local isReloading = false
local lastAttackTime = 0

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

-- อนิเมชั่นแกว่งมีดฟันแบบ Procedural (ส่าย RightGrip Joint)
local function playProceduralSlash()
	if not currentTool or currentTool.Name ~= "Knife" then return end
	
	local rightGrip = player.Character and player.Character:FindFirstChild("RightGrip", true)
	if not rightGrip then return end
	
	local originalC1 = rightGrip.C1
	
	task.spawn(function()
		local steps = 6
		local duration = 0.12 -- เวลาส่ายไป
		
		-- 1. จังหวะฟันเฉือนออกไปข้างหน้าและเอียงเฉลียงลง
		for i = 1, steps do
			local t = i / steps
			if not rightGrip or not rightGrip.Parent then break end
			rightGrip.C1 = originalC1 
				* CFrame.new(0.2 * t, -0.1 * t, 0.35 * t) 
				* CFrame.Angles(math.rad(45 * t), math.rad(-15 * t), math.rad(-45 * t))
			task.wait(duration / steps)
		end
		
		-- 2. จังหวะหวนดึงมีดกลับมาท่าตั้งรับเดิม
		for i = 1, steps do
			local t = 1 - (i / steps)
			if not rightGrip or not rightGrip.Parent then break end
			rightGrip.C1 = originalC1 
				* CFrame.new(0.2 * t, -0.1 * t, 0.35 * t) 
				* CFrame.Angles(math.rad(45 * t), math.rad(-15 * t), math.rad(-45 * t))
			task.wait(duration / steps)
		end
		
		if rightGrip and rightGrip.Parent then
			rightGrip.C1 = originalC1
		end
	end)
end

-- อนิเมชั่นปืนพกถอยดีดสะท้อนกลับแบบ Procedural (ส่าย RightGrip Joint)
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
			task.wait(0.025)
		end
		
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
	
	lastAttackTime = tick()
	
	if currentWeaponData.Type == "Melee" then
		-- 🗡️ [โจมตีระยะประชิด]
		-- เล่นเสียงเหวี่ยงอาวุธ (เร่งสปีดเสียงกระโดดทำเสียง Whoosh สั้น)
		playSoundLocal(currentWeaponData.SwingSound, 0.45, 2.5)
		
		-- เล่นอนิเมชั่นดาบแกว่ง สั่งแขนตัวละครแกว่งจริง และทริกเกอร์ Tool swing ในระบบหลัก
		playProceduralSlash()
		currentTool:Activate() -- สั่งแกว่งแขนมาตรฐานของ Roblox
		local animate = char:FindFirstChild("Animate")
		local toolanim = animate and animate:FindFirstChild("toolanim")
		if toolanim then
			toolanim.Value = "Slash"
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
	-- ตรวจสอบเมื่อมีการหยิบอาวุธขึ้นมาถือ (ChildAdded to Character)
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			currentTool = child
			local weaponData = WeaponConfig.Weapons[child.Name]
			
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
end

return WeaponController
