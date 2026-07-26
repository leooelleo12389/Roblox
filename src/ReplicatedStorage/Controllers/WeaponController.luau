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
local function playSoundLocal(soundId, volume)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.5
	sound.Parent = camera
	sound:Play()
	Debris:AddItem(sound, 3)
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
		-- เล่นเสียงเหวี่ยงอาวุธ
		playSoundLocal(currentWeaponData.SwingSound, 0.4)
		
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
			playSoundLocal("rbxasset://sounds/switch.mp3", 0.4)
			return
		end
		
		-- หักลดกระสุน
		currentAmmo = currentAmmo - 1
		ammoCount[currentTool.Name] = currentAmmo
		SurvivalUIController.SetWatchAmmo(true, currentAmmo, currentWeaponData.MaxAmmo)
		
		-- เล่นเสียงปืนยิง
		playSoundLocal(currentWeaponData.FireSound, 0.65)
		
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
	
	-- เล่นเสียงปืนรีโหลดกระสุน
	playSoundLocal(currentWeaponData.ReloadSound, 0.55)
	
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
