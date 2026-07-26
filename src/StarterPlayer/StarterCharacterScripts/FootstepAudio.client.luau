print("[FootstepAudio] === สคริปต์เริ่มทำงานแล้ว (เวอร์ชันตัดเสียงค้าง) ===")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = script.Parent

local humanoid = character:WaitForChild("Humanoid", 5)
if not humanoid then
	warn("[FootstepAudio] ไม่พบ Humanoid!")
	return
end

local rootPart = character:WaitForChild("HumanoidRootPart", 5)
if not rootPart then
	warn("[FootstepAudio] ไม่พบ HumanoidRootPart!")
	return
end

local defaultHipHeight = humanoid.HipHeight

-- กำหนดระดับความเร็ว
local SPEED_CROUCH = 8
local SPEED_WALK = 16
local SPEED_SPRINT = 24

-- สถานะพฤติกรรม
local isCrouching = false
local isSprinting = false

-- ตารางเสียงก้าวเท้าแยกตามวัสดุ ( Verified Sound IDs )
local MATERIAL_SOUNDS = {
	[Enum.Material.Grass] = "rbxassetid://9064714296",
	[Enum.Material.Fabric] = "rbxassetid://9064714296",
	[Enum.Material.Wood] = "rbxassetid://9065052688",
	[Enum.Material.WoodPlanks] = "rbxassetid://9065052688",
	[Enum.Material.Concrete] = "rbxassetid://9064974448",
	[Enum.Material.Plastic] = "rbxassetid://9064974448",
	[Enum.Material.Metal] = "rbxassetid://9064974448",
	[Enum.Material.DiamondPlate] = "rbxassetid://9064974448",
	["Default"] = "rbxassetid://9064714296"
}

-- สร้าง Sound สำหรับเล่นเสียงก้าวเท้า Custom เป็น 2D (ติดตั้งใน PlayerGui เพื่อความดังชัดเจนสูงสุด)
local footstepSound = Instance.new("Sound")
footstepSound.Name = "CustomFootstep"
footstepSound.Parent = player:WaitForChild("PlayerGui")

local function getSoundForMaterial(material)
	return MATERIAL_SOUNDS[material] or MATERIAL_SOUNDS["Default"]
end

-- 🔇 [BULLETPROOF MUTE] ระบบดักทำลายเสียงเดิมของ Roblox แบบเรียลไทม์
local DEFAULT_ROBLOX_SOUNDS = {
	["Running"] = true,
	["Jumping"] = true,
	["Landing"] = true,
	["Climbing"] = true,
	["FreeFalling"] = true,
	["Swimming"] = true,
	["Splash"] = true
}

local function handleSoundAdded(child)
	if child:IsA("Sound") and DEFAULT_ROBLOX_SOUNDS[child.Name] then
		child.Volume = 0
		task.defer(function()
			if child and child.Parent then
				child:Destroy()
			end
		end)
	end
end

rootPart.ChildAdded:Connect(handleSoundAdded)
for _, child in ipairs(rootPart:GetChildren()) do
	handleSoundAdded(child)
end

-- ฟังก์ชันปรับระดับความเร็วและส่วนสูงของตัวละคร
local function updateMovementState()
	if isCrouching then
		humanoid.WalkSpeed = SPEED_CROUCH
		if humanoid.RigType == Enum.HumanoidRigType.R15 then
			humanoid.HipHeight = defaultHipHeight - 0.8
		end
	elseif isSprinting then
		humanoid.WalkSpeed = SPEED_SPRINT
		if humanoid.RigType == Enum.HumanoidRigType.R15 then
			humanoid.HipHeight = defaultHipHeight
		end
	else
		humanoid.WalkSpeed = SPEED_WALK
		if humanoid.RigType == Enum.HumanoidRigType.R15 then
			humanoid.HipHeight = defaultHipHeight
		end
	end
	
	character:SetAttribute("Crouching", isCrouching)
end

-- ระบบคุมความเร็วผ่านปุ่ม Shift ซ้าย
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if UserInputService:GetFocusedTextBox() then return end
	
	if input.KeyCode == Enum.KeyCode.LeftShift then
		isSprinting = true
		if isCrouching then
			isCrouching = false
		end
		updateMovementState()
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		isSprinting = false
		updateMovementState()
	end
end)

-- ควบคุมปุ่มกด LeftControl (ย่อตัว)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if UserInputService:GetFocusedTextBox() then return end
	
	if input.KeyCode == Enum.KeyCode.LeftControl then
		isCrouching = not isCrouching
		if isCrouching then
			isSprinting = false
		end
		updateMovementState()
	end
end)

-- ควบคุมเสียงฝีเท้าและส่งค่าความดัง (NoiseLevel) ในแต่ละเฟรม
local lastStepTime = 0

RunService.RenderStepped:Connect(function()
	local isMoving = humanoid.MoveDirection.Magnitude > 0
	local isGrounded = humanoid.FloorMaterial ~= Enum.Material.Air
	
	if isMoving and isGrounded then
		local stepInterval = 0.38
		local soundVolume = 0.12    -- ปรับเดินปกติกลับมานุ่มนวลฟังสบายหู (0.12)
		local soundPitch = 0.95
		local currentNoise = 10
		
		if isCrouching then
			stepInterval = 0.65    -- ก้าวเท้าช้าลงเยอะ
			soundVolume = 0.01     -- ย่องเงียบเชียบสุดๆ แทบไม่ได้ยิน (0.01)
			soundPitch = 0.70      -- เสียงทุ้มลง
			currentNoise = 3
		elseif isSprinting then
			stepInterval = 0.22    -- สับเท้าถี่เร็วขึ้น
			soundVolume = 0.28     -- เสียงวิ่งนุ่มนวลพอดีหูไม่กระแทก (0.28)
			soundPitch = 1.25      -- เสียงเร็วแหลมขึ้น
			currentNoise = 25
		end
		
		local currentTime = tick()
		if currentTime - lastStepTime >= stepInterval then
			lastStepTime = currentTime
			
			local currentMaterial = humanoid.FloorMaterial
			local soundId = getSoundForMaterial(currentMaterial)
				
			footstepSound.SoundId = soundId
			footstepSound.Volume = soundVolume
			footstepSound.PlaybackSpeed = soundPitch
			
			footstepSound:Play()
		end
		
		character:SetAttribute("NoiseLevel", currentNoise)
	else
		-- 🛑 เมื่อผู้เล่นยืนเฉยๆ หรือลอยอยู่บนฟ้า ให้สั่งตัดเสียงการก้าวเท้า Custom ทันที
		if footstepSound.IsPlaying then
			footstepSound:Stop()
		end
		character:SetAttribute("NoiseLevel", 0)
	end
end)

print("[FootstepAudio] === บูตรันระบบเสียงฝีเท้า Custom (ป้องกันเสียงค้างสำเร็จ) ===")
