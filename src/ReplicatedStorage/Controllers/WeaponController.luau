local WeaponController = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ตัวแปรควบคุมการขยับแขนขวาและซ้ายในมุมมองบุคคลที่หนึ่ง
local rightShoulder = nil
local originalShoulderC0 = nil
local rightElbow = nil
local originalElbowC0 = nil
local armSwingOffset = CFrame.new()

local leftShoulder = nil
local originalLeftShoulderC0 = nil
local leftElbow = nil
local originalLeftElbowC0 = nil
local leftArmSwingOffset = CFrame.new()

-- ตารางควบคุมพิกัดขยับท่อนแขนและสถานะอาวุธของผู้เล่นคนอื่นๆ บนเซิร์ฟเวอร์
local playerArmSwingOffsets = {}
local playerLeftArmSwingOffsets = {}
local lastActiveWeapon = {}

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
local currentIdleTrack = nil
local currentAttackTrack = nil

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

-- ฟังก์ชันสำหรับเซ็ตค่า C0 ของข้อศอกขวาอย่างปลอดภัย
local function setElbowC0(cframe)
	if not rightElbow then return end
	local success, _ = pcall(function()
		rightElbow.C0 = cframe
	end)
	if not success then
		pcall(function()
			rightElbow.Attachment0.CFrame = cframe
		end)
	end
end

-- ฟังก์ชันสำหรับเซ็ตค่า C0 ของไหล่ซ้ายอย่างปลอดภัย
local function setLeftShoulderC0(cframe)
	if not leftShoulder then return end
	local success, _ = pcall(function()
		leftShoulder.C0 = cframe
	end)
	if not success then
		pcall(function()
			leftShoulder.Attachment0.CFrame = cframe
		end)
	end
end

-- ฟังก์ชันสำหรับเซ็ตค่า C0 ของข้อศอกซ้ายอย่างปลอดภัย
local function setLeftElbowC0(cframe)
	if not leftElbow then return end
	local success, _ = pcall(function()
		leftElbow.C0 = cframe
	end)
	if not success then
		pcall(function()
			leftElbow.Attachment0.CFrame = cframe
		end)
	end
end

-- ฟังก์ชันเซ็ตข้อต่อ C0 อัจฉริยะ (ส่งผ่านได้ทุกข้อต่อ)
local function setJointC0(joint, cframe)
	if not joint then return end
	local success, _ = pcall(function()
		joint.C0 = cframe
	end)
	if not success then
		pcall(function()
			joint.Attachment0.CFrame = cframe
		end)
	end
end

-- ฟังก์ชันเคลียร์ท่าทางแขนซ้ายและขวาของตัวละครกลับมาเป็นค่าดีฟอลต์ปกติ
local function resetCharacterRig(char)
	local rightShoulderJoint = char:FindFirstChild("RightUpperArm") and char.RightUpperArm:FindFirstChild("RightShoulder")
		or char:FindFirstChild("Torso") and char.Torso:FindFirstChild("Right Shoulder")
	local leftShoulderJoint = char:FindFirstChild("LeftUpperArm") and char.LeftUpperArm:FindFirstChild("LeftShoulder")
		or char:FindFirstChild("Torso") and char.Torso:FindFirstChild("Left Shoulder")
	local rightElbowJoint = char:FindFirstChild("RightLowerArm") and char.RightLowerArm:FindFirstChild("RightElbow")
	local leftElbowJoint = char:FindFirstChild("LeftLowerArm") and char.LeftLowerArm:FindFirstChild("LeftElbow")
	
	local defaultRightShoulderC0 = CFrame.new(1, 0.5, 0)
	local defaultLeftShoulderC0 = CFrame.new(-1, 0.5, 0)
	local defaultRightElbowC0 = CFrame.new(0, -0.5, 0)
	local defaultLeftElbowC0 = CFrame.new(0, -0.5, 0)
	
	setJointC0(rightShoulderJoint, defaultRightShoulderC0)
	setJointC0(leftShoulderJoint, defaultLeftShoulderC0)
	setJointC0(rightElbowJoint, defaultRightElbowC0)
	setJointC0(leftElbowJoint, defaultLeftElbowC0)
end

-- ฟังก์ชันอัปเดตตำแหน่งและการจัดวางกระดูกไหล่/ข้อศอกของตัวละครทุกคน
local function updateCharacterRig(targetPlayer, weaponName)
	local char = targetPlayer.Character
	if not char then return end
	
	local rightShoulderJoint = char:FindFirstChild("RightUpperArm") and char.RightUpperArm:FindFirstChild("RightShoulder")
		or char:FindFirstChild("Torso") and char.Torso:FindFirstChild("Right Shoulder")
	local leftShoulderJoint = char:FindFirstChild("LeftUpperArm") and char.LeftUpperArm:FindFirstChild("LeftShoulder")
		or char:FindFirstChild("Torso") and char.Torso:FindFirstChild("Left Shoulder")
	local rightElbowJoint = char:FindFirstChild("RightLowerArm") and char.RightLowerArm:FindFirstChild("RightElbow")
	local leftElbowJoint = char:FindFirstChild("LeftLowerArm") and char.LeftLowerArm:FindFirstChild("LeftElbow")
	
	if not rightShoulderJoint then return end
	
	-- คำนวณก้มเงยศีรษะ (ใช้กล้องสำหรับตัวเองเพื่อให้หันหน้าตามจริง และใช้หัวกระดูกสำหรับคนอื่น)
	local pitch = 0
	if targetPlayer == player then
		pitch = math.asin(camera.CFrame.LookVector.Y)
	else
		local head = char:FindFirstChild("Head")
		if head then
			pitch = math.asin(head.CFrame.LookVector.Y)
		end
	end
	
	local defaultRightShoulderC0 = CFrame.new(1, 0.5, 0)
	local defaultLeftShoulderC0 = CFrame.new(-1, 0.5, 0)
	local defaultRightElbowC0 = CFrame.new(0, -0.5, 0)
	local defaultLeftElbowC0 = CFrame.new(0, -0.5, 0)
	
	-- ดึงค่าแรงขยับเหวี่ยงปล่อยหมัด
	local rightOffset = playerArmSwingOffsets[targetPlayer] or CFrame.new()
	local leftOffset = playerLeftArmSwingOffsets[targetPlayer] or CFrame.new()
	
	-- ถ้าเป็นตัวเราเอง (LocalPlayer) ให้ใช้ค่าส่ายและแรงดีดแบบเรียลไทม์ (ไม่มีหน่วงเครือข่าย)
	if targetPlayer == player then
		rightOffset = armSwingOffset
		leftOffset = leftArmSwingOffset
	end
	
	-- หายใจส่ายเบาๆ (Breathing Sway)
	local breathingAngle = tick() * 1.5 + (targetPlayer.UserId % 10)
	local breathingSway = CFrame.new(
		math.cos(breathingAngle) * 0.015,
		math.sin(breathingAngle * 2) * 0.015,
		0
	)
	
	if weaponName == "Fists" then
		-- 🥊 การ์ดชกมวยหมัดคู่
		if rightElbowJoint and leftElbowJoint then
			setJointC0(rightElbowJoint, defaultRightElbowC0 * CFrame.Angles(math.rad(-75), 0, 0))
			setJointC0(leftElbowJoint, defaultLeftElbowC0 * CFrame.Angles(math.rad(-75), 0, 0))
			
			local shoulderCFrameR = defaultRightShoulderC0 
				* CFrame.new(-0.25, -0.15, -0.4) 
				* CFrame.Angles(pitch + math.rad(35), math.rad(-25), math.rad(-15)) 
				* breathingSway
				* rightOffset
			setJointC0(rightShoulderJoint, shoulderCFrameR)
			
			local leftBreathingSway = CFrame.new(
				math.cos(breathingAngle + math.pi) * 0.015,
				math.sin(breathingAngle * 2 + math.pi) * 0.015,
				0
			)
			local shoulderCFrameL = defaultLeftShoulderC0 
				* CFrame.new(0.25, -0.15, -0.4) 
				* CFrame.Angles(pitch + math.rad(35), math.rad(25), math.rad(15)) 
				* leftBreathingSway
				* leftOffset
			setJointC0(leftShoulderJoint, shoulderCFrameL)
		end
	elseif weaponName == "Pistol" then
		-- 🔫 ถือปืนพกแขนขวาเดี่ยว แขนซ้ายปกติ
		if rightElbowJoint then
			setJointC0(rightElbowJoint, defaultRightElbowC0 * CFrame.Angles(math.rad(-75), 0, 0))
			
			local shoulderCFrameR = defaultRightShoulderC0 
				* CFrame.new(-0.25, -0.15, -0.4) 
				* CFrame.Angles(pitch + math.rad(35), math.rad(-25), math.rad(-15)) 
				* breathingSway
				* rightOffset
			setJointC0(rightShoulderJoint, shoulderCFrameR)
		end
		
		setJointC0(leftShoulderJoint, defaultLeftShoulderC0)
		setJointC0(leftElbowJoint, defaultLeftElbowC0)
	end
end

-- อนิเมชั่นต่อยหมัดของตัวละครอื่นบนเซิร์ฟเวอร์แบบ Procedural Sync
local function playOtherPlayerProceduralPunch(targetPlayer, comboIndex)
	task.spawn(function()
		local steps = 5
		local duration = 0.06
		local recoverDuration = 0.12
		
		if comboIndex == 1 then
			-- หมัดขวาตรง
			for i = 1, steps do
				local t = i / steps
				playerArmSwingOffsets[targetPlayer] = CFrame.new(-0.1 * t, -0.05 * t, 0.15 - 1.35 * t) 
					* CFrame.Angles(math.rad(15 * t), math.rad(-15 * t), math.rad(-75 * t))
				playerLeftArmSwingOffsets[targetPlayer] = CFrame.new(0.1 * t, 0.05 * t, -0.1 * t)
				task.wait(duration / steps)
			end
			for i = 1, steps do
				local t = 1 - (i / steps)
				playerArmSwingOffsets[targetPlayer] = CFrame.new(-0.1 * t, -0.05 * t, 0.15 - 1.35 * t) 
					* CFrame.Angles(math.rad(15 * t), math.rad(-15 * t), math.rad(-75 * t))
				playerLeftArmSwingOffsets[targetPlayer] = CFrame.new(0.1 * t, 0.05 * t, -0.1 * t)
				task.wait(recoverDuration / steps)
			end
		elseif comboIndex == 2 then
			-- หมัดซ้ายตรง
			for i = 1, steps do
				local t = i / steps
				playerLeftArmSwingOffsets[targetPlayer] = CFrame.new(0.1 * t, -0.05 * t, 0.15 - 1.35 * t) 
					* CFrame.Angles(math.rad(15 * t), math.rad(15 * t), math.rad(75 * t))
				playerArmSwingOffsets[targetPlayer] = CFrame.new(-0.1 * t, 0.05 * t, -0.1 * t)
				task.wait(duration / steps)
			end
			for i = 1, steps do
				local t = 1 - (i / steps)
				playerLeftArmSwingOffsets[targetPlayer] = CFrame.new(0.1 * t, -0.05 * t, 0.15 - 1.35 * t) 
					* CFrame.Angles(math.rad(15 * t), math.rad(15 * t), math.rad(75 * t))
				playerArmSwingOffsets[targetPlayer] = CFrame.new(-0.1 * t, 0.05 * t, -0.1 * t)
				task.wait(recoverDuration / steps)
			end
		elseif comboIndex == 3 then
			-- อัปเปอร์คัทขวา
			for i = 1, steps do
				local t = i / steps
				playerArmSwingOffsets[targetPlayer] = CFrame.new(-0.1 - 0.15 * t, -0.3 + 0.7 * t, 0.1 - 0.7 * t) 
					* CFrame.Angles(math.rad(65 * t), math.rad(-35 * t), math.rad(-60 * t))
				playerLeftArmSwingOffsets[targetPlayer] = CFrame.new(0.15 * t, 0.1 * t, -0.15 * t)
				task.wait(duration / steps)
			end
			for i = 1, steps do
				local t = 1 - (i / steps)
				playerArmSwingOffsets[targetPlayer] = CFrame.new(-0.1 - 0.15 * t, -0.3 + 0.7 * t, 0.1 - 0.7 * t) 
					* CFrame.Angles(math.rad(65 * t), math.rad(-35 * t), math.rad(-60 * t))
				playerLeftArmSwingOffsets[targetPlayer] = CFrame.new(0.15 * t, 0.1 * t, -0.15 * t)
				task.wait(recoverDuration / steps)
			end
		end
		
		playerArmSwingOffsets[targetPlayer] = nil
		playerLeftArmSwingOffsets[targetPlayer] = nil
	end)
end

-- ฟังก์ชันสำหรับโหลดและเล่นแอนิเมชันการโจมตีที่คุณอัปโหลดเองแบบปรับตั้งค่า (ตามวิดีโอสอน)
local function playCustomAttackAnimation(humanoid, animId)
	if not animId or animId == "" or animId == "rbxassetid://YOUR_ID_HERE" then return end
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end
	
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local success, track = pcall(function() return animator:LoadAnimation(anim) end)
	if success and track then
		if currentAttackTrack then
			currentAttackTrack:Stop()
			currentAttackTrack:Destroy()
		end
		currentAttackTrack = track
		currentAttackTrack:Play()
	end
end

-- อนิเมชั่นปล่อยหมัดแบบ Procedural ระดับพรีเมียม (มีแรงส่งน้ำหนัก หมุนบิดกำปั้น การ์ดป้องกันอีกมือ และกล้องสั่นไหว)
local function playProceduralSlash(comboIndex)
	if not currentTool or currentTool.Name ~= "Fists" then return end
	
	task.spawn(function()
		local steps = 6
		
		-- เพิ่มแรงสั่นสะเทือนกล้องเล็กน้อยเพื่อความหนักแน่น (Camera recoil)
		task.spawn(function()
			for i = 1, 4 do
				if not currentTool or currentTool.Name ~= "Fists" then break end
				local shake = Vector3.new(
					(math.random() - 0.5) * 0.02,
					(math.random() - 0.5) * 0.02,
					(math.random() - 0.5) * 0.02
				)
				camera.CFrame = camera.CFrame * CFrame.new(shake)
				task.wait(0.015)
			end
		end)
		
		if comboIndex == 1 then
			-- 🥊 1. หมัดขวาตรง (Right Jab)
			-- ง้างหมัดถอยหลังนิดหน่อย (Anticipation)
			for i = 1, 2 do
				armSwingOffset = CFrame.new(0.05, 0, 0.15) * CFrame.Angles(0, math.rad(-10), 0)
				leftArmSwingOffset = CFrame.new(0.1, 0.05, -0.1) -- หมัดซ้ายขยับมาบังหน้าเพื่อการ์ด
				task.wait(0.02)
			end
			-- พุ่งหมัดชกออกไปอย่างรวดเร็วพร้อมบิดข้อมือ (Punch snap forward with twist)
			for i = 1, steps do
				local t = i / steps
				armSwingOffset = CFrame.new(-0.1 * t, -0.05 * t, 0.15 - 1.35 * t) 
					* CFrame.Angles(math.rad(15 * t), math.rad(-15 * t), math.rad(-75 * t))
				leftArmSwingOffset = CFrame.new(0.1 * t, 0.05 * t, -0.1 * t)
				task.wait(0.04 / steps)
			end
			-- ดึงหมัดกลับมาตั้งการ์ดปกติแบบหน่วงเวลา (Recover ease-out)
			for i = 1, steps do
				local t = 1 - (i / steps)
				armSwingOffset = CFrame.new(-0.1 * t, -0.05 * t, 0.15 - 1.35 * t) 
					* CFrame.Angles(math.rad(15 * t), math.rad(-15 * t), math.rad(-75 * t))
				leftArmSwingOffset = CFrame.new(0.1 * t, 0.05 * t, -0.1 * t)
				task.wait(0.14 / steps)
			end
			
		elseif comboIndex == 2 then
			-- 🥊 2. หมัดซ้ายตรง (Left Jab)
			-- ง้างหมัดถอยหลังนิดหน่อย (Anticipation)
			for i = 1, 2 do
				leftArmSwingOffset = CFrame.new(-0.05, 0, 0.15) * CFrame.Angles(0, math.rad(10), 0)
				armSwingOffset = CFrame.new(-0.1, 0.05, -0.1) -- หมัดขวาขยับมาการ์ดบังหน้า
				task.wait(0.02)
			end
			-- พุ่งชกซ้ายบิดข้อมือ
			for i = 1, steps do
				local t = i / steps
				leftArmSwingOffset = CFrame.new(0.1 * t, -0.05 * t, 0.15 - 1.35 * t) 
					* CFrame.Angles(math.rad(15 * t), math.rad(15 * t), math.rad(75 * t))
				armSwingOffset = CFrame.new(-0.1 * t, 0.05 * t, -0.1 * t)
				task.wait(0.04 / steps)
			end
			-- ดึงกลับ
			for i = 1, steps do
				local t = 1 - (i / steps)
				leftArmSwingOffset = CFrame.new(0.1 * t, -0.05 * t, 0.15 - 1.35 * t) 
					* CFrame.Angles(math.rad(15 * t), math.rad(15 * t), math.rad(75 * t))
				armSwingOffset = CFrame.new(-0.1 * t, 0.05 * t, -0.1 * t)
				task.wait(0.14 / steps)
			end
			
		elseif comboIndex == 3 then
			-- 🥊 3. อัปเปอร์คัทขวาเสยคาง (Right Uppercut)
			-- ง้างลงต่ำเพื่อเตรียมเสย (Drop fist down for power)
			for i = 1, 3 do
				armSwingOffset = CFrame.new(-0.1, -0.3, 0.1) * CFrame.Angles(math.rad(-20), 0, 0)
				leftArmSwingOffset = CFrame.new(0.15, 0.1, -0.15) -- ยกการ์ดซ้ายสูงป้องกันใบหน้า
				task.wait(0.02)
			end
			-- เสยเสร็จสิ้นอย่างรุนแรง (Uppercut punch up)
			for i = 1, steps do
				local t = i / steps
				armSwingOffset = CFrame.new(-0.1 - 0.15 * t, -0.3 + 0.7 * t, 0.1 - 0.7 * t) 
					* CFrame.Angles(math.rad(65 * t), math.rad(-35 * t), math.rad(-60 * t))
				leftArmSwingOffset = CFrame.new(0.15 * t, 0.1 * t, -0.15 * t)
				task.wait(0.05 / steps)
			end
			-- ค่อยๆ ดึงกลับลงมาท่าการ์ดเดิม
			for i = 1, steps do
				local t = 1 - (i / steps)
				armSwingOffset = CFrame.new(-0.1 - 0.15 * t, -0.3 + 0.7 * t, 0.1 - 0.7 * t) 
					* CFrame.Angles(math.rad(65 * t), math.rad(-35 * t), math.rad(-60 * t))
				leftArmSwingOffset = CFrame.new(0.15 * t, 0.1 * t, -0.15 * t)
				task.wait(0.16 / steps)
			end
		end
		
		armSwingOffset = CFrame.new()
		leftArmSwingOffset = CFrame.new()
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
		
		-- สั่งโหลดและเล่นแอนิเมชันมีดฟันแบบคีย์เฟรมที่คุณอัปโหลดเอง (ถ้ามีตั้งใน Config)
		local comboAnims = currentWeaponData.AttackAnims
		local animId = comboAnims and comboAnims[thisCombo]
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if animId and humanoid then
			playCustomAttackAnimation(humanoid, animId)
		end
		
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
		local hitInstance = nil
		local hitPos = nil
		local targetHumanoid = nil
		
		if result then
			hitInstance = result.Instance
			hitPos = result.Position
			local model = hitInstance:FindFirstAncestorOfClass("Model")
			targetHumanoid = model and model:FindFirstChildOfClass("Humanoid")
		end
		
		-- แจ้งเซิร์ฟเวอร์ว่ามีการโจมตี (รวมทั้งตีลมและโจมตีโดนเป้าหมาย) เพื่อให้กระจายแอนิเมชันให้ผู้เล่นคนอื่นเห็น
		WeaponRemotes.WeaponAttack:FireServer("Melee", currentTool.Name, targetHumanoid, hitInstance, hitPos, thisCombo)
		
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
		
		-- สั่งโหลดและเล่นแอนิเมชันปืนยิงแบบคีย์เฟรมที่คุณอัปโหลดเอง (ถ้ามีตั้งใน Config)
		local comboAnims = currentWeaponData.AttackAnims
		local animId = comboAnims and comboAnims[1]
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if animId and humanoid then
			playCustomAttackAnimation(humanoid, animId)
		end
		
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
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			currentTool = child
			local weaponData = WeaponConfig.Weapons[child.Name]
			
			armSwingOffset = CFrame.new()
			leftArmSwingOffset = CFrame.new()
			currentComboIndex = 1
			lastComboTime = 0
			
			if weaponData then
				currentWeaponData = weaponData
				print("[WeaponController]: 🥊 ติดตั้งอาวุธ -> " .. child.Name)
				
				-- ส่งข้อมูลติดตั้งให้ Server รับทราบเพื่อกระจายให้ผู้เล่นคนอื่นทราบ
				WeaponRemotes.WeaponReplicate:FireServer("Equip", child.Name)
				
				-- โหลดและเล่นแอนิเมชันท่าถือ (Idle) ที่นำเข้าจาก Roblox Studio (ถ้ามีตั้งใน Config)
				local humanoid = char:FindFirstChildOfClass("Humanoid")
				local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
				if animator and weaponData.IdleAnim and weaponData.IdleAnim ~= "" and weaponData.IdleAnim ~= "rbxassetid://YOUR_ID_HERE" then
					local anim = Instance.new("Animation")
					anim.AnimationId = weaponData.IdleAnim
					local success, track = pcall(function() return animator:LoadAnimation(anim) end)
					if success and track then
						currentIdleTrack = track
						currentIdleTrack.Looped = true
						currentIdleTrack:Play()
					end
				end
				
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
	
	char.ChildRemoved:Connect(function(child)
		if child == currentTool then
			currentTool = nil
			currentWeaponData = nil
			isReloading = false
			
			armSwingOffset = CFrame.new()
			leftArmSwingOffset = CFrame.new()
			currentComboIndex = 1
			lastComboTime = 0
			
			-- แจ้ง Server ว่าเก็บ/ถอดอาวุธ
			WeaponRemotes.WeaponReplicate:FireServer("Unequip")
			
			-- ล้างแอนิเมชันของเดิมที่ค้างอยู่
			if currentIdleTrack then
				currentIdleTrack:Stop()
				currentIdleTrack:Destroy()
				currentIdleTrack = nil
			end
			if currentAttackTrack then
				currentAttackTrack:Stop()
				currentAttackTrack:Destroy()
				currentAttackTrack = nil
			end
			
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
	
	-- ดักรับข้อมูลการ Replicate อนิเมชั่นปล่อยหมัดและท่าทางชกมวยของคนอื่น
	WeaponRemotes.WeaponReplicate.OnClientEvent:Connect(function(actionType, targetPlayer, weaponName, comboIndex)
		if not targetPlayer or targetPlayer == player then return end
		
		if actionType == "Equip" then
			lastActiveWeapon[targetPlayer] = weaponName
		elseif actionType == "Unequip" then
			lastActiveWeapon[targetPlayer] = nil
			if targetPlayer.Character then
				resetCharacterRig(targetPlayer.Character)
			end
		elseif actionType == "Attack" then
			playOtherPlayerProceduralPunch(targetPlayer, comboIndex)
		end
	end)
	
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

	-- เชื่อมเหตุการณ์ RenderStepped เพื่อควบคุมก้มเงยตั้งการ์ดและปล่อยหมัดของทุกคนบนเซิร์ฟเวอร์
	RunService.RenderStepped:Connect(function()
		for _, targetPlayer in ipairs(Players:GetPlayers()) do
			local char = targetPlayer.Character
			if not char then 
				lastActiveWeapon[targetPlayer] = nil
				continue 
			end
			
			-- ตรวจหาอาวุธที่กำลังถืออยู่จริงจากโมเดลตัวละคร (เพื่อป้องกัน desync)
			local activeTool = char:FindFirstChildOfClass("Tool")
			local weaponName = activeTool and activeTool.Name
			
			local prevWeapon = lastActiveWeapon[targetPlayer]
			if weaponName ~= prevWeapon then
				lastActiveWeapon[targetPlayer] = weaponName
				if not weaponName then
					resetCharacterRig(char)
				end
			end
			
			if weaponName then
				updateCharacterRig(targetPlayer, weaponName)
			end
		end
	end)
end

return WeaponController
