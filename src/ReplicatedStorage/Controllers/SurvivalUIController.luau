local SurvivalUIController = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local isMouseLocked = true
local isRmbPressed = false -- ตรวจจับคลิกขวาค้าง

-- 3D Viewmodel สำหรับยกแขนดูนาฬิกา
local viewmodel = nil
local armPart = nil
local watchPart = nil
local watchSurfaceGui = nil

-- พิกัด Offset ของตัวนาฬิกา 3 มิติเทียบกับกล้องหลัก (ล่างซ้ายซ่อน / ยกขึ้นแนบชิดตาพาดแนวนอนสไตล์ Green Hell)
local loweredOffset = CFrame.new(-1.2, -2.0, -1) * CFrame.Angles(0, math.rad(-90), 0)
local raisedOffset = CFrame.new(-0.05, -0.16, -0.7) * CFrame.Angles(0, math.rad(-90), 0)
local currentOffset = loweredOffset

-- ตัวแปรอ้างอิง UI หน้าปัดนาฬิกา
local watchFrame = nil
local watchTimeLabel = nil
local watchDayLabel = nil
local watchSystemLabel = nil
local isWatchOpen = false

-- ตัวแปรแถบพลังงานความหิวและเปอร์เซ็นต์ติดเชื้อบนหน้าปัดนาฬิกา (เกจทรงโค้ง Left/Right)
local leftFillStroke = nil
local leftGradient = nil
local rightFillStroke = nil
local rightGradient = nil
local foodLabel = nil
local virusLabel = nil

-- ปุ่มแฝงสำหรับสั่งปลดล็อกระบบเมาส์ของ Roblox Engine (Modal Bypass)
local modalBypassButton = nil

-- ตารางเก็บสถานะความโปร่งใสดั้งเดิมของร่างกายตัวละคร
local originalTransparencies = {}

-- ฟังก์ชันดึงสีผิวจริงจากตัวละครผู้เล่น
local function getPlayerSkinColor()
	local char = player.Character
	if char then
		-- ตรวจหาชิ้นส่วนผิวหนัง R15 / R6
		local bodyPart = char:FindFirstChild("Head") or char:FindFirstChild("LeftArm") or char:FindFirstChild("LeftUpperArm")
		if bodyPart and bodyPart:IsA("BasePart") then
			return bodyPart.Color
		end
	end
	return Color3.fromRGB(225, 184, 153) -- สีผิวสำรองกรณีไม่พบตัวละคร
end

-- ฟังก์ชันช่วยไล่ระดับสเกลความสูงของเส้นโค้ง (UIGradient Transparency wiping)
local function updateArcProgress(uiGradient, percentage)
	percentage = math.clamp(percentage, 0, 1)
	uiGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(math.clamp(percentage - 0.001, 0, 0.999), 0),
		NumberSequenceKeypoint.new(math.clamp(percentage, 0.001, 1), 1),
		NumberSequenceKeypoint.new(1, 1)
	})
end

-- ฟังก์ชันสร้างแขนและนาฬิกา 3 มิติ (3D Wristwatch Viewmodel)
local function createWatchViewmodel()
	if viewmodel then viewmodel:Destroy() end
	
	viewmodel = Instance.new("Model")
	viewmodel.Name = "TacticalWatchViewmodel"
	
	-- 1. สร้างชิ้นส่วนแขนซ้ายจำลอง (Left Arm)
	armPart = Instance.new("Part")
	armPart.Name = "Arm"
	armPart.Size = Vector3.new(0.35, 1.4, 0.35)
	armPart.Color = getPlayerSkinColor()
	armPart.Material = Enum.Material.SmoothPlastic
	armPart.CanCollide = false
	armPart.CastShadow = false
	armPart.Anchored = true
	armPart.Parent = viewmodel
	
	-- 2. สร้างตัวเรือนนาฬิกา (Watch Frame) ทรงกลม (Cylinder)
	watchPart = Instance.new("Part")
	watchPart.Name = "Watch"
	watchPart.Shape = Enum.PartType.Cylinder
	watchPart.Size = Vector3.new(0.12, 0.48, 0.48) -- X = ความหนา, Y/Z = เส้นผ่านศูนย์กลางของทรงกลม
	watchPart.Color = Color3.fromRGB(40, 40, 42)
	watchPart.Material = Enum.Material.Metal
	watchPart.CanCollide = false
	watchPart.CastShadow = false
	watchPart.Anchored = true
	watchPart.Parent = viewmodel
	
	-- 3. ลิงก์ระบบแสดงผล 3D (SurfaceGui) ที่มีอยู่แล้วเข้ากับตัวเรือนนาฬิกาตัวใหม่
	if watchSurfaceGui then
		watchSurfaceGui.Adornee = watchPart
	end
	
	-- ย้ายไปไว้ใต้กล้อง (Parent เปล่าเพื่อซ่อนไว้ก่อน)
	viewmodel.Parent = nil
end

-- ฟังก์ชันซ่อน/แสดงร่างกายของผู้เล่นฝั่ง Client (ความโปร่งใสคงที่ 100%)
local function setCharacterVisible(visible)
	local character = player.Character
	if not character then return end
	
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			if not visible then
				-- บันทึกค่าโปร่งใสเดิมและซ่อนเป็น 1 (ล่องหน)
				if not originalTransparencies[part] then
					originalTransparencies[part] = part.Transparency
				end
				part.Transparency = 1
			else
				-- คืนค่าความโปร่งใสเดิม
				local originalVal = originalTransparencies[part]
				part.Transparency = originalVal or 0
			end
		end
	end
	
	if visible then
		table.clear(originalTransparencies)
	end
end

-- ฟังก์ชันปรับแต่งการล็อกและปลดล็อกเมาส์
function SurvivalUIController.SetMouseLock(locked)
	isMouseLocked = locked
	
	if locked then
		-- 🎯 [โหมดเล่นปกติ - บุคคลที่หนึ่ง 100%]
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
		
		setCharacterVisible(true) -- คืนค่าแสดงผลร่างกายตามปกติ
		
		if modalBypassButton then
			modalBypassButton.Modal = false
			modalBypassButton.Visible = false
		end
		
		-- ⏱️ ดีเลย์การล็อกเมาส์ 1 เฟรม เพื่อรอให้โหมดบุคคลที่หนึ่งจัดระเบียบเฟรมเสร็จสิ้น ป้องกันเมาส์หลุดจอ
		task.defer(function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
		end)
		
		local crosshair = playerGui:FindFirstChild("CrosshairGui")
		if crosshair then
			crosshair.Enabled = true
		end
		print("SurvivalUIController: ล็อกเมาส์ (โหมดเล็งยิง)")
	else
		-- 🎯 [โหมดเมนู/ปลดล็อก - เปลี่ยนเป็นบุคคลที่สามระยะประชิด 2 สตัด เพื่อปลดล็อกเมาส์ถาวร]
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 2.0
		player.CameraMaxZoomDistance = 2.0
		
		setCharacterVisible(false) -- ซ่อนร่างกายผู้เล่นทั้งหมดทันที (ล่องหน)
		
		if modalBypassButton then
			modalBypassButton.Visible = true
			modalBypassButton.Modal = true
		end
		
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		
		local crosshair = playerGui:FindFirstChild("CrosshairGui")
		if crosshair then
			crosshair.Enabled = false
		end
		print("SurvivalUIController: ปลดล็อกเมาส์ (โหมดเลือกเมนู - ซูมออก 2.0)")
	end
end

-- ฟังก์ชันสลับสถานะล็อก/ปลดล็อกเมาส์
function SurvivalUIController.ToggleMouseLock()
	SurvivalUIController.SetMouseLock(not isMouseLocked)
end

-- ฟังก์ชันสร้างเป้าเล็ง
function SurvivalUIController.CreateCrosshair()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CrosshairGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	
	local lineLength = 8
	local lineThickness = 2
	local lineGap = 4
	
	local dot = Instance.new("Frame")
	dot.Name = "CenterDot"
	dot.Size = UDim2.new(0, 4, 0, 4)
	dot.Position = UDim2.new(0.5, -2, 0.5, -2)
	dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dot.BorderSizePixel = 1
	dot.BorderColor3 = Color3.fromRGB(0, 0, 0)
	dot.Parent = screenGui
	
	local top = Instance.new("Frame")
	top.Name = "TopLine"
	top.Size = UDim2.new(0, lineThickness, 0, lineLength)
	top.Position = UDim2.new(0.5, -lineThickness/2, 0.5, -lineGap - lineLength)
	top.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	top.BorderSizePixel = 1
	top.BorderColor3 = Color3.fromRGB(0, 0, 0)
	top.Parent = screenGui
	
	local bottom = Instance.new("Frame")
	bottom.Name = "BottomLine"
	bottom.Size = UDim2.new(0, lineThickness, 0, lineLength)
	bottom.Position = UDim2.new(0.5, -lineThickness/2, 0.5, lineGap)
	bottom.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	bottom.BorderSizePixel = 1
	bottom.BorderColor3 = Color3.fromRGB(0, 0, 0)
	bottom.Parent = screenGui
	
	local left = Instance.new("Frame")
	left.Name = "LeftLine"
	left.Size = UDim2.new(0, lineLength, 0, lineThickness)
	left.Position = UDim2.new(0.5, -lineGap - lineLength, 0.5, -lineThickness/2)
	left.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	left.BorderSizePixel = 1
	left.BorderColor3 = Color3.fromRGB(0, 0, 0)
	left.Parent = screenGui
	
	local right = Instance.new("Frame")
	right.Name = "RightLine"
	right.Size = UDim2.new(0, lineLength, 0, lineThickness)
	right.Position = UDim2.new(0.5, lineGap, 0.5, -lineThickness/2)
	right.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	right.BorderSizePixel = 1
	right.BorderColor3 = Color3.fromRGB(0, 0, 0)
	right.Parent = screenGui
	
	screenGui.Parent = playerGui
end

-- ฟังก์ชันสร้างแถบสัญลักษณ์สถานะความเร็วซ้ายล่าง
function SurvivalUIController.CreateStatusIndicator()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MovementStatusGui"
	screenGui.ResetOnSpawn = false
	
	local modalBtn = Instance.new("TextButton")
	modalBtn.Name = "ModalBypassButton"
	modalBtn.Size = UDim2.new(0, 1, 0, 1)
	modalBtn.Position = UDim2.new(0, 0, 0, 0)
	modalBtn.BackgroundTransparency = 1
	modalBtn.Text = ""
	modalBtn.Visible = false
	modalBtn.Modal = false
	modalBtn.Parent = screenGui
	
	modalBypassButton = modalBtn
	
	local moveContainer = Instance.new("Frame")
	moveContainer.Name = "MoveStatusContainer"
	moveContainer.Size = UDim2.new(0, 140, 0, 36)
	moveContainer.Position = UDim2.new(0, 20, 1, -60)
	moveContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	moveContainer.BackgroundTransparency = 0.5
	moveContainer.BorderSizePixel = 0
	moveContainer.Parent = screenGui
	
	local uiCorner1 = Instance.new("UICorner")
	uiCorner1.CornerRadius = UDim.new(0, 6)
	uiCorner1.Parent = moveContainer
	
	local stroke1 = Instance.new("UIStroke")
	stroke1.Color = Color3.fromRGB(255, 255, 255)
	stroke1.Transparency = 0.85
	stroke1.Thickness = 1
	stroke1.Parent = moveContainer
	
	local accentBar = Instance.new("Frame")
	accentBar.Name = "AccentBar"
	accentBar.Size = UDim2.new(0, 4, 1, 0)
	accentBar.Position = UDim2.new(0, 0, 0, 0)
	accentBar.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	accentBar.BorderSizePixel = 0
	accentBar.Parent = moveContainer
	
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 6)
	barCorner.Parent = accentBar
	
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -15, 1, 0)
	statusLabel.Position = UDim2.new(0, 15, 0, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "🧘 IDLE"
	statusLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
	statusLabel.TextSize = 13
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = moveContainer
	
	screenGui.Parent = playerGui
	
	-- อัปเดตสถานะความเร็วความเคลื่อนไหวซ้ายล่าง
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		if not character then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		
		local isMoving = humanoid.MoveDirection.Magnitude > 0
		local isSprinting = humanoid.WalkSpeed > 16 and isMoving
		local isCrouching = character:GetAttribute("Crouching") == true
		
		if isCrouching then
			if isMoving then
				statusLabel.Text = "🤫 SNEAKING"
				statusLabel.TextColor3 = Color3.fromRGB(240, 190, 50)
				accentBar.BackgroundColor3 = Color3.fromRGB(240, 190, 50)
			else
				statusLabel.Text = "🧎 CROUCHED"
				statusLabel.TextColor3 = Color3.fromRGB(180, 140, 90)
				accentBar.BackgroundColor3 = Color3.fromRGB(180, 140, 90)
			end
		elseif isSprinting then
			statusLabel.Text = "⚡ SPRINTING"
			statusLabel.TextColor3 = Color3.fromRGB(0, 255, 240)
			accentBar.BackgroundColor3 = Color3.fromRGB(0, 255, 240)
		elseif isMoving then
			statusLabel.Text = "🚶 WALKING"
			statusLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
			accentBar.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
		else
			statusLabel.Text = "🧘 IDLE"
			statusLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
			accentBar.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		end
	end)
end

function SurvivalUIController.CreateWristwatchUI()
	-- 💡 สร้าง SurfaceGui ประดิษฐ์ถาวรไว้ที่ PlayerGui ก่อน
	watchSurfaceGui = Instance.new("SurfaceGui")
	watchSurfaceGui.Name = "WatchSurfaceGui"
	watchSurfaceGui.ResetOnSpawn = false -- 🛡️ ป้องกัน Roblox ลบหน้าปัดทิ้งเมื่อผู้เล่นสปอว์นเกิดใหม่
	watchSurfaceGui.Face = Enum.NormalId.Right
	watchSurfaceGui.CanvasSize = Vector2.new(120, 130)
	watchSurfaceGui.LightInfluence = 0
	watchSurfaceGui.Brightness = 2.0
	watchSurfaceGui.Parent = playerGui
	
	-- ตรวจสอบให้มั่นใจว่าได้สร้าง 3D Viewmodel แขนแล้ว และทำการดึง Adornee
	createWatchViewmodel()
	
	-- 1. ตัวเรือนนาฬิกาหลัก (ปรับขนาดเต็มกรอบ Canvas ขนาด 120x130 ของ SurfaceGui)
	local container = Instance.new("Frame")
	container.Name = "WatchContainer"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.Position = UDim2.new(0, 0, 0, 0)
	container.BackgroundColor3 = Color3.fromRGB(30, 30, 32)
	container.BorderSizePixel = 0
	container.Parent = watchSurfaceGui
	
	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 18)
	containerCorner.Parent = container
	
	-- 4. หน้าปัดทรงกลม
	local screen = Instance.new("Frame")
	screen.Name = "WatchScreen"
	screen.Size = UDim2.new(0, 104, 0, 104)
	screen.Position = UDim2.new(0.5, -52, 0.5, -52)
	screen.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
	screen.BorderSizePixel = 0
	screen.Parent = container
	
	local screenCorner = Instance.new("UICorner")
	screenCorner.CornerRadius = UDim.new(0, 52)
	screenCorner.Parent = screen
	
	local screenStroke = Instance.new("UIStroke")
	screenStroke.Color = Color3.fromRGB(50, 50, 53)
	screenStroke.Thickness = 2
	screenStroke.Parent = screen
	
	-- 5. ดีเทลตัวอักษรบนหน้าปัด (SYS OK)
	local systemLabel = Instance.new("TextLabel")
	systemLabel.Name = "SystemLabel"
	systemLabel.Size = UDim2.new(1, 0, 0, 12)
	systemLabel.Position = UDim2.new(0, 0, 0.15, -6)
	systemLabel.BackgroundTransparency = 1
	systemLabel.Text = "SYSTEM OK"
	systemLabel.TextColor3 = Color3.fromRGB(90, 90, 95)
	systemLabel.TextSize = 8
	systemLabel.Font = Enum.Font.GothamBold
	systemLabel.TextXAlignment = Enum.TextXAlignment.Center
	systemLabel.Parent = screen
	
	-- 6. ตัวเลขเวลานาฬิกาดิจิทัล
	local timeLabel = Instance.new("TextLabel")
	timeLabel.Name = "TimeLabel"
	timeLabel.Size = UDim2.new(1, 0, 0, 24)
	timeLabel.Position = UDim2.new(0, 0, 0.32, -12)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Text = "08:00"
	timeLabel.TextColor3 = Color3.fromRGB(0, 255, 120)
	timeLabel.TextSize = 22
	timeLabel.Font = Enum.Font.GothamBold
	timeLabel.TextXAlignment = Enum.TextXAlignment.Center
	timeLabel.Parent = screen
	
	-- 7. ตัวเลขบอกสะสมวัน
	local dayLabel = Instance.new("TextLabel")
	dayLabel.Name = "DayLabel"
	dayLabel.Size = UDim2.new(1, 0, 0, 14)
	dayLabel.Position = UDim2.new(0, 0, 0.54, -7)
	dayLabel.BackgroundTransparency = 1
	dayLabel.Text = "DAY 01"
	dayLabel.TextColor3 = Color3.fromRGB(150, 150, 155)
	dayLabel.TextSize = 10
	dayLabel.Font = Enum.Font.GothamBold
	dayLabel.TextXAlignment = Enum.TextXAlignment.Center
	dayLabel.Parent = screen
	
	-- 8. [เกจความหิวแบบโค้งฝั่งซ้าย - LEFT CURVED HUNGER BAR]
	local leftClipper = Instance.new("Frame")
	leftClipper.Name = "LeftClipper"
	leftClipper.Size = UDim2.new(0, 52, 0, 104)
	leftClipper.Position = UDim2.new(0, 0, 0, 0)
	leftClipper.BackgroundTransparency = 1
	leftClipper.ClipsDescendants = true
	leftClipper.Parent = screen
	
	-- วาดเกจพื้นหลังซ้าย (Track)
	local leftTrack = Instance.new("Frame")
	leftTrack.Name = "LeftTrack"
	leftTrack.Size = UDim2.new(0, 94, 0, 94)
	leftTrack.Position = UDim2.new(0, 5, 0, 5) -- กึ่งกลาง
	leftTrack.BackgroundTransparency = 1
	leftTrack.Parent = leftClipper
	
	local leftTrackCorner = Instance.new("UICorner")
	leftTrackCorner.CornerRadius = UDim.new(0, 47)
	leftTrackCorner.Parent = leftTrack
	
	local leftTrackStroke = Instance.new("UIStroke")
	leftTrackStroke.Color = Color3.fromRGB(30, 30, 35)
	leftTrackStroke.Thickness = 4
	leftTrackStroke.Parent = leftTrack
	
	-- วาดเกจสีเขียวเติมพลังงานอาหารซ้าย (Fill)
	local leftFill = Instance.new("Frame")
	leftFill.Name = "LeftFill"
	leftFill.Size = UDim2.new(0, 94, 0, 94)
	leftFill.Position = UDim2.new(0, 5, 0, 5)
	leftFill.BackgroundTransparency = 1
	leftFill.Parent = leftClipper
	
	local leftFillCorner = Instance.new("UICorner")
	leftFillCorner.CornerRadius = UDim.new(0, 47)
	leftFillCorner.Parent = leftFill
	
	local lfStroke = Instance.new("UIStroke")
	lfStroke.Color = Color3.fromRGB(255, 130, 0)
	lfStroke.Thickness = 4
	lfStroke.Parent = leftFill
	leftFillStroke = lfStroke
	
	local lfGradient = Instance.new("UIGradient")
	lfGradient.Rotation = -90 -- เติมล่างขึ้นบน
	lfGradient.Parent = lfStroke
	leftGradient = lfGradient
	
	-- 9. [เกจติดเชื้อแบบโค้งฝั่งขวา - RIGHT CURVED INFECTION BAR]
	local rightClipper = Instance.new("Frame")
	rightClipper.Name = "RightClipper"
	rightClipper.Size = UDim2.new(0, 52, 0, 104)
	rightClipper.Position = UDim2.new(0, 52, 0, 0) -- ซีกขวา
	rightClipper.BackgroundTransparency = 1
	rightClipper.ClipsDescendants = true
	rightClipper.Parent = screen
	
	-- วาดเกจพื้นหลังขวา (Track)
	local rightTrack = Instance.new("Frame")
	rightTrack.Name = "RightTrack"
	rightTrack.Size = UDim2.new(0, 94, 0, 94)
	rightTrack.Position = UDim2.new(0, -47, 0, 5) -- ชดเชยระนาบ
	rightTrack.BackgroundTransparency = 1
	rightTrack.Parent = rightClipper
	
	local rightTrackCorner = Instance.new("UICorner")
	rightTrackCorner.CornerRadius = UDim.new(0, 47)
	rightTrackCorner.Parent = rightTrack
	
	local rightTrackStroke = Instance.new("UIStroke")
	rightTrackStroke.Color = Color3.fromRGB(30, 30, 35)
	rightTrackStroke.Thickness = 4
	rightTrackStroke.Parent = rightTrack
	
	-- วาดเกจสีส้ม/แดงเติมเปอร์เซ็นต์ติดเชื้อขวา (Fill)
	local rightFill = Instance.new("Frame")
	rightFill.Name = "RightFill"
	rightFill.Size = UDim2.new(0, 94, 0, 94)
	rightFill.Position = UDim2.new(0, -47, 0, 5)
	rightFill.BackgroundTransparency = 1
	rightFill.Parent = rightClipper
	
	local rightFillCorner = Instance.new("UICorner")
	rightFillCorner.CornerRadius = UDim.new(0, 47)
	rightFillCorner.Parent = rightFill
	
	local rfStroke = Instance.new("UIStroke")
	rfStroke.Color = Color3.fromRGB(255, 80, 0)
	rfStroke.Thickness = 4
	rfStroke.Parent = rightFill
	rightFillStroke = rfStroke
	
	local rfGradient = Instance.new("UIGradient")
	rfGradient.Rotation = -90 -- เติมล่างขึ้นบน
	rfGradient.Parent = rfStroke
	rightGradient = rfGradient
	
	-- 10. สร้างตัวอักษรบอกประเภทสลักใต้จอ
	local fLabel = Instance.new("TextLabel")
	fLabel.Name = "FoodLabel"
	fLabel.Size = UDim2.new(0, 48, 0, 12)
	fLabel.Position = UDim2.new(0.06, 0, 0.74, 0)
	fLabel.BackgroundTransparency = 1
	fLabel.Text = "🍗 100%"
	fLabel.TextColor3 = Color3.fromRGB(255, 130, 0)
	fLabel.TextSize = 9
	fLabel.Font = Enum.Font.GothamBold
	fLabel.TextXAlignment = Enum.TextXAlignment.Center
	fLabel.Parent = screen
	foodLabel = fLabel
	
	local vLabel = Instance.new("TextLabel")
	vLabel.Name = "VirusLabel"
	vLabel.Size = UDim2.new(0, 48, 0, 12)
	vLabel.Position = UDim2.new(0.52, 0, 0.74, 0)
	vLabel.BackgroundTransparency = 1
	vLabel.Text = "☣️ 0%"
	vLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	vLabel.TextSize = 9
	vLabel.Font = Enum.Font.GothamBold
	vLabel.TextXAlignment = Enum.TextXAlignment.Center
	vLabel.Parent = screen
	virusLabel = vLabel
	
	watchFrame = container
	watchTimeLabel = timeLabel
	watchDayLabel = dayLabel
	watchSystemLabel = systemLabel
	
	-- ตัวแปรช่วยการกะพริบไฟหน้าจอ
	local flashTick = 0
	
	RunService.RenderStepped:Connect(function()
		flashTick = flashTick + 0.15 -- อัปเดตเวลาการกะพริบอย่างสม่ำเสมอในทุกเฟรม
		local activeCamera = workspace.CurrentCamera
		
		-- 3D Viewmodel Watch positioning ( Lerp Animation )
		local targetOffset = isWatchOpen and raisedOffset or loweredOffset
		currentOffset = currentOffset:Lerp(targetOffset, 0.15)
		
		if viewmodel then
			local isHidden = not isWatchOpen and (currentOffset.Position - loweredOffset.Position).Magnitude < 0.05
			if isHidden then
				viewmodel.Parent = nil
				return -- ป้องกันการอัปเดตตำแหน่งเมื่อพับเก็บ
			else
				viewmodel.Parent = activeCamera
				
				-- 1. วางตำแหน่งตัวเรือนนาฬิกาทรงกลมตรงพิกัดเทียบกับกล้องโดยตรง (หน้าปัด Right หงายหันตรงสบตากล้องแล้ว)
				watchPart.CFrame = activeCamera.CFrame * currentOffset
				
				-- 2. วางท่อนแขนจำลองให้งอกย้อนจากใต้ตัวนาฬิกา (ขยับไปหลังนาฬิกา X = -0.18, ยืดไปทางซ้าย Z = -0.5, และหมุนท่อนแขนขนานแนวนอน)
				armPart.CFrame = watchPart.CFrame * CFrame.new(-0.18, 0, -0.5) * CFrame.Angles(math.rad(90), 0, 0)
			end
		end
		
		-- ⏱️ อัปเดตเวลาและวัน
		local clockTime = Lighting.ClockTime
		local hours = math.floor(clockTime)
		local minutes = math.floor((clockTime - hours) * 60)
		watchTimeLabel.Text = string.format("%02d:%02d", hours, minutes)
		
		local currentDay = workspace:GetAttribute("Day") or 1
		watchDayLabel.Text = string.format("DAY %02d", currentDay)
		
		-- 🍗 อัปเดตระดับความหิว (เกจโค้งซ้าย)
		local hunger = player:GetAttribute("Hunger") or 100
		local hungerPercent = hunger / 100
		updateArcProgress(leftGradient, hungerPercent)
		foodLabel.Text = "🍗 " .. math.round(hunger) .. "%"
		
		if hunger <= 25 then
			leftFillStroke.Color = Color3.fromRGB(255, 50, 0)
			foodLabel.TextColor3 = Color3.fromRGB(255, 50, 0)
		else
			leftFillStroke.Color = Color3.fromRGB(255, 130, 0)
			foodLabel.TextColor3 = Color3.fromRGB(255, 130, 0)
		end
		
		-- ☣️ อัปเดตระดับการติดเชื้อ (เกจโค้งขวา)
		local infection = player:GetAttribute("Infection") or 0
		local infectPercent = infection / 100
		virusLabel.Text = "☣️ " .. math.round(infection) .. "%"
		
		if infection <= 0 then
			updateArcProgress(rightGradient, 0)
			virusLabel.TextColor3 = Color3.fromRGB(130, 130, 135)
			rightFillStroke.Color = Color3.fromRGB(30, 30, 35) -- พรางสีตัวเกจ
		elseif infection < 50 then
			rightFillStroke.Color = Color3.fromRGB(240, 180, 20)
			virusLabel.TextColor3 = Color3.fromRGB(240, 180, 20)
			updateArcProgress(rightGradient, infectPercent)
		else
			rightFillStroke.Color = Color3.fromRGB(255, 0, 40)
			virusLabel.TextColor3 = Color3.fromRGB(255, 0, 40)
			updateArcProgress(rightGradient, infectPercent)
		end
		
		-- 🚨 ปรับโทนสีแสงเรืองแสงของนาฬิกา
		local isNight = workspace:GetAttribute("IsNight") == true
		if isNight or infection >= 50 then
			watchTimeLabel.TextColor3 = Color3.fromRGB(255, 80, 0)
			screenStroke.Color = Color3.fromRGB(120, 30, 0)
		else
			watchTimeLabel.TextColor3 = Color3.fromRGB(0, 255, 120)
			screenStroke.Color = Color3.fromRGB(50, 50, 53)
		end
		
		-- 🖥️ อัปเดตข้อความแจ้งเตือนระบบ (System Status Label)
		if watchSystemLabel then
			if infection >= 75 then
				watchSystemLabel.Text = "CRITICAL"
				watchSystemLabel.TextColor3 = Color3.fromRGB(255, 0, 40)
				watchSystemLabel.TextTransparency = 0
			elseif infection > 50 then
				watchSystemLabel.Text = "DANGER"
				watchSystemLabel.TextColor3 = Color3.fromRGB(255, 130, 0)
				watchSystemLabel.TextTransparency = 0
			elseif hunger <= 25 then
				watchSystemLabel.Text = "HUNGER"
				watchSystemLabel.TextColor3 = Color3.fromRGB(255, 130, 0)
				
				-- ทำให้ข้อความ Hunger กะพริบตามจังหวะ flashTick
				local flashVal = math.sin(flashTick)
				if flashVal > 0 then
					watchSystemLabel.TextTransparency = 0
				else
					watchSystemLabel.TextTransparency = 1
				end
			else
				watchSystemLabel.Text = "SYSTEM OK"
				watchSystemLabel.TextColor3 = Color3.fromRGB(90, 90, 95)
				watchSystemLabel.TextTransparency = 0
			end
		end
	end)
end

-- ฟังก์ชันกระตุ้นทวิ้นอนิเมชั่นยก/เก็บนาฬิกาข้อมือ (ส่งสัญญาณเช็กสถานะการมองเห็น)
function SurvivalUIController.SetWatchVisible(visible)
	isWatchOpen = visible
	
	-- อัปเดตสีผิวของแขนใหม่ตามเวลาที่ตัวละครอาจเกิดหรือเปลี่ยนชุด
	if visible and armPart then
		armPart.Color = getPlayerSkinColor()
	end
end

local isInitialized = false -- ป้องกันการบูตเบิ้ล

function SurvivalUIController.Init()
	if isInitialized then return end
	isInitialized = true
	
	-- 👥 [DISABLE DEFAULT LEADERBOARD] ปิดระบบรายชื่อผู้เล่นดั้งเดิมเพื่อใช้ปุ่ม Tab ได้อย่างอิสระ
	task.spawn(function()
		local StarterGui = game:GetService("StarterGui")
		for i = 1, 10 do
			local success = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			end)
			if success then break end
			task.wait(0.2)
		end
	end)
	
	SurvivalUIController.CreateCrosshair()
	SurvivalUIController.CreateStatusIndicator()
	SurvivalUIController.CreateWristwatchUI()
	
	-- 🖱️ ดักจับอีเวนต์คลิกขวาเพื่อความมั่นคง
	UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			isRmbPressed = true
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			isRmbPressed = false
		end
	end)
	
	UserInputService.WindowFocusReleased:Connect(function()
		isRmbPressed = false
	end)
	
	-- 🖥️ [WINDOW FOCUS RECOVERY] 
	UserInputService.WindowFocused:Connect(function()
		if not isMouseLocked then
			task.defer(function()
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = true
			end)
		end
	end)
	
	-- 🔒 [BULLETPROOF MOUSE LOCK]
	RunService:BindToRenderStep("MouseLockEnforcement", Enum.RenderPriority.Camera.Value + 1, function()
		if isMouseLocked then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
		else
			-- ปลดล็อกเมาส์: หากคลิกขวาค้างเพื่อแพนกล้อง ให้ล็อกตำแหน่งขยับหน้ากล้อง หากปล่อยให้ขยับอิสระ
			if isRmbPressed then
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
				UserInputService.MouseIconEnabled = false
			else
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = true
			end
		end
	end)
	
	-- รีเซ็ตสถานะเมื่อเกิดใหม่
	player.CharacterAdded:Connect(function()
		SurvivalUIController.SetMouseLock(true)
		isRmbPressed = false
		
		-- บูตสร้างโมเดลแขนใหม่หากตัวละครสปอว์นเกิดใหม่
		task.wait(0.5)
		createWatchViewmodel()
	end)
	
	-- บังคับล็อกเมาส์เริ่มต้น
	SurvivalUIController.SetMouseLock(true)
end

return SurvivalUIController
