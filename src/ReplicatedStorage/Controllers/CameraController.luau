local CameraController = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ตั้งค่าระดับการโยกเยกของหน้าจอ (Head Bobbing)
local bobbingEnabled = true
local bobbingSpeed = 12
local bobbingIntensityX = 0.12
local bobbingIntensityY = 0.08

-- ตัวแปรควบคุมระบบหน้าจอสั่น (Camera Shake)
local currentShake = Vector3.new(0, 0, 0)
local shakeIntensity = 0
local shakeDecay = 0

-- ตัวแปรสำหรับเลื่อนมุมมองย่อตัว (Crouch Camera Slide)
local crouchYOffset = 0
local targetCrouchY = 0
local CROUCH_SPEED = 10 -- ความเร็วในการสไลด์กล้องขึ้น/ลง

local function lerpNum(n1, n2, alpha)
	return n1 + (n2 - n1) * alpha
end

-- ฟังก์ชันกระตุ้นหน้าจอสั่น
function CameraController.Shake(intensity, duration)
	shakeIntensity = intensity
	shakeDecay = intensity / duration
end

-- เริ่มการทำงานของระบบควบคุมกล้อง
function CameraController.Init()
	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		if not character then return end
		
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not rootPart then return end
		
		local cameraOffset = Vector3.new(0, 0, 0)
		
		-- 1. คำนวณระบบโยกเยกตามการเดิน (Head Bobbing)
		if bobbingEnabled and humanoid.MoveDirection.Magnitude > 0 then
			local speedMultiplier = humanoid.WalkSpeed / 16
			local tickValue = tick() * bobbingSpeed * speedMultiplier
			
			local bobX = math.sin(tickValue * 0.5) * bobbingIntensityX * speedMultiplier
			local bobY = math.abs(math.sin(tickValue)) * bobbingIntensityY * speedMultiplier
			
			cameraOffset = Vector3.new(bobX, bobY, 0)
		end
		
		-- 2. คำนวณระบบสั่นหน้าจอ (Camera Shake)
		if shakeIntensity > 0 then
			local randomX = (math.random() - 0.5) * 2 * shakeIntensity
			local randomY = (math.random() - 0.5) * 2 * shakeIntensity
			local randomZ = (math.random() - 0.5) * 2 * shakeIntensity
			
			currentShake = Vector3.new(randomX, randomY, randomZ)
			shakeIntensity = math.max(0, shakeIntensity - (shakeDecay * dt))
		else
			currentShake = currentShake * 0.9
		end
		
		-- 3. คำนวณความสูงมุมมองการย่อตัว (Crouch Camera Slide)
		local isCrouching = character:GetAttribute("Crouching") == true
		if isCrouching then
			targetCrouchY = -1.2 -- ย่อกล้องลง 1.2 สตัด
		else
			targetCrouchY = 0     -- ยืนตำแหน่งปกติ
		end
		
		-- เลื่อนกล้องขึ้นลงอย่างสมูท (Lerp)
		crouchYOffset = lerpNum(crouchYOffset, targetCrouchY, dt * CROUCH_SPEED)
		
		-- 4. รวบรวมการโยก การสั่น และการย่อ ไปใส่ใน CameraOffset
		humanoid.CameraOffset = cameraOffset + currentShake + Vector3.new(0, crouchYOffset, 0)
	end)
	
	print("CameraController: ระบบควบคุมกล้องรองรับระบบย่อตัว (Crouch Slide) แล้ว!")
end

return CameraController
