local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

print("Zombie Island Game: กำลังโหลดระบบฝั่ง Client...")

local Controllers = ReplicatedStorage:WaitForChild("Controllers")

-- ค้นหาและรันสปาร์ทระบบ Controllers ทั้งหมดอัตโนมัติ (Dynamic Bootstrap)
for _, child in ipairs(Controllers:GetChildren()) do
	if child:IsA("ModuleScript") then
		local success, controller = pcall(require, child)
		if success then
			if type(controller) == "table" and controller.Init then
				print("[ClientMain]: กำลังบูตรัน Controller -> " .. child.Name)
				task.spawn(controller.Init)
			end
		else
			warn("[ClientMain]: บูตรัน Controller ไม่สำเร็จ -> " .. child.Name .. " | Error: " .. tostring(controller))
		end
	end
end

-- ============================================================================
-- 🔦 [ระบบไฟฉายกล้อง FPS - FLASHLIGHT SYSTEM]
-- ============================================================================

-- สร้าง Part เปล่าสำหรับติดดวงไฟไว้ที่กล้อง
local flashlightPart = Instance.new("Part")
flashlightPart.Name = "LocalFlashlightPart"
flashlightPart.Transparency = 1
flashlightPart.CanCollide = false
flashlightPart.CanTouch = false
flashlightPart.CanQuery = false
flashlightPart.Size = Vector3.new(0.1, 0.1, 0.1)
flashlightPart.Massless = true
flashlightPart.Anchored = true
flashlightPart.Parent = camera

-- สร้าง SpotLight ส่องทิศทางกระบอกไฟ
local spotLight = Instance.new("SpotLight")
spotLight.Name = "FlashlightLight"
spotLight.Shadows = false -- ปิดเงาเพื่อความสมูท
spotLight.Enabled = false
spotLight.Parent = flashlightPart

-- โหลดเสียงสวิตช์ไฟฉาย
local switchSound = Instance.new("Sound")
switchSound.SoundId = "rbxasset://sounds/switch.mp3"
switchSound.Volume = 0.4
switchSound.Parent = flashlightPart

local flashlightEnabled = false
local lastFlickerTime = tick()
local nextFlickerDelay = math.random(15, 35)
local isFlickering = false

-- ฟังก์ชันปรับแต่งค่าความสว่างของไฟฉายแบบ Dynamic ตามคุณภาพ
local function updateFlashlightSpecs()
	local character = player.Character
	if not character then return end
	
	local quality = character:GetAttribute("FlashlightQuality") or 1
	
	if quality == 1 then
		-- เลเวล 1: ไฟฉายกากๆ ติดๆ ดับๆ แสงสีเหลืองสลัว มุมแคบ
		spotLight.Range = 50
		spotLight.Brightness = 2.0
		spotLight.Angle = 32
		spotLight.Color = Color3.fromRGB(245, 220, 160)
	else
		-- เลเวล 2: ไฟฉายเกรดทหาร สว่างจ้า ลำแสงกว้าง สีขาวเจิดจ้า
		spotLight.Range = 95
		spotLight.Brightness = 4.5
		spotLight.Angle = 48
		spotLight.Color = Color3.fromRGB(250, 252, 255)
	end
end

-- ฟังก์ชันสลับสถานะเปิด/ปิดไฟฉาย
local function toggleFlashlight()
	flashlightEnabled = not flashlightEnabled
	spotLight.Enabled = flashlightEnabled
	switchSound:Play()
	
	local character = player.Character
	if character then
		character:SetAttribute("FlashlightOn", flashlightEnabled)
		lastFlickerTime = tick()
		nextFlickerDelay = math.random(15, 35)
		updateFlashlightSpecs()
	end
	print("[Flashlight Debug]: สลับสถานะไฟฉาย -> " .. (flashlightEnabled and "เปิด 🟢" or "ปิด 🔴"))
end

-- 🌀 [Task Loop] ระบบสุ่มไฟกะพริบชำรุด (เฉพาะเลเวล 1 เท่านั้น)
task.spawn(function()
	while true do
		task.wait(1)
		
		local character = player.Character
		if not character then continue end
		
		local quality = character:GetAttribute("FlashlightQuality") or 1
		
		if flashlightEnabled and quality == 1 and not isFlickering then
			if tick() - lastFlickerTime >= nextFlickerDelay then
				isFlickering = true
				print("[Flashlight Event]: ⚠️ ไฟฉายขัดข้อง! กำลังกะพริบ...")
				
				switchSound:Play()
				
				local flickers = math.random(3, 7)
				for i = 1, flickers do
					spotLight.Enabled = false
					task.wait(math.random(6, 16) / 100)
					spotLight.Enabled = true
					task.wait(math.random(6, 16) / 100)
				end
				
				if math.random() > 0.5 then
					spotLight.Enabled = false
					task.wait(0.3)
					spotLight.Enabled = true
					switchSound:Play()
				end
				
				spotLight.Enabled = flashlightEnabled
				
				lastFlickerTime = tick()
				nextFlickerDelay = math.random(15, 45)
				isFlickering = false
			end
		end
	end
end)

-- ดักจับอัปเดตตำแหน่งไฟฉายให้หันล็อกตามกล้อง
RunService:BindToRenderStep("FlashlightUpdate", Enum.RenderPriority.Camera.Value + 1, function()
	if flashlightPart and camera then
		flashlightPart.CFrame = camera.CFrame * CFrame.new(0, 0, 1.5)
	end
end)

-- จัดการการเกิดใหม่และการดักจับการสลับอัปเกรด
local function setupCharacter(char)
	flashlightEnabled = false
	spotLight.Enabled = false
	isFlickering = false
	
	char:GetAttributeChangedSignal("FlashlightQuality"):Connect(updateFlashlightSpecs)
	updateFlashlightSpecs()
end

player.CharacterAdded:Connect(setupCharacter)
if player.Character then
	setupCharacter(player.Character)
end

-- ============================================================================
-- 🧪 เหตุการณ์ทดสอบปุ่มควบคุมและล็อกเมาส์
-- ============================================================================
local CameraController = require(Controllers:WaitForChild("CameraController"))
local SurvivalUIController = require(Controllers:WaitForChild("SurvivalUIController"))

-- สั่งเปิดใช้งานระบบต่างๆ ของนาฬิกาและเป้าเล็งทันทีที่ได้รับโมดูลหลัก (แก้ไขปัญหา Race Condition)
task.spawn(function()
	if CameraController and CameraController.Init then
		print("[ClientMain Debug]: กำลังบูต CameraController.Init()...")
		CameraController.Init()
		print("[ClientMain Debug]: บูต CameraController.Init() สำเร็จ")
	else
		warn("[ClientMain Debug]: ⚠️ ไม่พบ CameraController.Init")
	end
end)

task.spawn(function()
	if SurvivalUIController and SurvivalUIController.Init then
		print("[ClientMain Debug]: กำลังบูต SurvivalUIController.Init()...")
		SurvivalUIController.Init()
		print("[ClientMain Debug]: บูต SurvivalUIController.Init() สำเร็จ")
	else
		warn("[ClientMain Debug]: ⚠️ ไม่พบ SurvivalUIController.Init")
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	-- ห้ามรันปุ่มกดถ้าผู้เล่นกำลังแชตหรือพิมพ์กล่องข้อความอยู่
	if UserInputService:GetFocusedTextBox() then return end
	
	if input.KeyCode == Enum.KeyCode.G then
		print("ClientTest: ตรวจพบการกดคีย์ G -> เปิดใช้งานระบบหน้าจอสั่น")
		CameraController.Shake(1.5, 0.8)
	elseif input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.Tab then
		SurvivalUIController.ToggleMouseLock()
	elseif input.KeyCode == Enum.KeyCode.F then
		toggleFlashlight()
	elseif input.KeyCode == Enum.KeyCode.T then
		-- 🕒 ยกนาฬิกาข้อมือขึ้นมาดูเมื่อกดคีย์ T ค้างไว้
		SurvivalUIController.SetWatchVisible(true)
	elseif input.KeyCode == Enum.KeyCode.H then
		-- ปุ่มโกงสำหรับแอดมินสลับความเสถียรไฟฉาย
		local character = player.Character
		if character then
			local currentQuality = character:GetAttribute("FlashlightQuality") or 1
			local newQuality = currentQuality == 1 and 2 or 1
			character:SetAttribute("FlashlightQuality", newQuality)
			print("[Admin Test]: สลับเกรดไฟฉายของคุณเป็น -> เลเวล " .. tostring(newQuality) .. " " .. (newQuality == 2 and "(ไฟฉายเกรดทหาร - เสถียร 🟢)" or "(ไฟฉายกากๆ - ชำรุดกะพริบ 🔴)"))
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	-- 🕒 เก็บนาฬิกาข้อมือลงเมื่อปล่อยมือจากปุ่ม T
	if input.KeyCode == Enum.KeyCode.T then
		SurvivalUIController.SetWatchVisible(false)
	end
end)

print("Zombie Island Game: ระบบฝั่ง Client บูตเสร็จสิ้น! (กด T ค้างเพื่อดูนาฬิกา)")
