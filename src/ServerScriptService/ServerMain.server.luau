print("Zombie Island Game: Server Initializing...")

local Services = script.Parent.Services

-- 1. บูตรันโมดูล Services ทั้งหมดอัตโนมัติ
for _, child in ipairs(Services:GetChildren()) do
	if child:IsA("ModuleScript") then
		local success, service = pcall(require, child)
		if success then
			if type(service) == "table" and service.Init then
				print("[ServerMain]: กำลังบูตรัน Service -> " .. child.Name)
				task.spawn(service.Init)
			end
		else
			warn("[ServerMain]: บูตรัน Service ไม่สำเร็จ -> " .. child.Name .. " | Error: " .. tostring(service))
		end
	end
end

-- ============================================================================
-- 📦 [ระบบสร้างห้องทึบทดสอบไฟฉาย - PROCEDURAL TEST ROOM SPAWNER]
-- ============================================================================
local function createTestRoom()
	local folder = Instance.new("Folder")
	folder.Name = "TestFlashlightRoom"
	folder.Parent = workspace
	
	local size = 50       -- ความกว้าง/ยาวของห้อง
	local height = 20     -- ความสูงของห้อง
	local thickness = 2   -- ความหนาของกำแพง
	
	-- วัสดุและโทนสีของห้องทึบ
	local wallMaterial = Enum.Material.Concrete
	local wallColor = Color3.fromRGB(45, 45, 45) -- เทาเข้มบล็อกแสง
	
	-- ฟังก์ชันย่อยสำหรับสร้างพาร์ทแบบระบุขนาดและตำแหน่ง
	local function createPart(name, partSize, position)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = partSize
		part.Position = position
		part.Material = wallMaterial
		part.Color = wallColor
		part.Anchored = true
		part.Parent = folder
		return part
	end
	
	-- (ใช้ Baseplate เดิมเป็นพื้นเพื่อป้องกันปัญหากระพริบ Z-Fighting)
	
	-- สร้างเพดานปิดทึบเพื่อบังแดด (Ceiling)
	createPart("RoomCeiling", Vector3.new(size, thickness, size), Vector3.new(0, height + thickness/2, 0))
	
	-- สร้างกำแพง 4 ด้าน (Walls)
	-- กำแพงด้านหลัง
	createPart("WallBack", Vector3.new(size, height, thickness), Vector3.new(0, height/2, -size/2 + thickness/2))
	-- กำแพงด้านหน้า (มีช่องทางเดินเข้า-ออก ขนาดกว้าง 8 สตัด)
	createPart("WallFrontLeft", Vector3.new(size/2 - 4, height, thickness), Vector3.new(-size/4 - 2, height/2, size/2 - thickness/2))
	createPart("WallFrontRight", Vector3.new(size/2 - 4, height, thickness), Vector3.new(size/4 + 2, height/2, size/2 - thickness/2))
	-- กำแพงด้านซ้าย
	createPart("WallLeft", Vector3.new(thickness, height, size), Vector3.new(-size/2 + thickness/2, height/2, 0))
	-- กำแพงด้านขวา
	createPart("WallRight", Vector3.new(thickness, height, size), Vector3.new(size/2 - thickness/2, height/2, 0))
	
	-- 🧱 สปอว์น "เสาอิฐ" 4 ต้นภายในห้องเพื่อทดสอบเอฟเฟกต์เงาทอดยาว (Shadows)
	local offset = 12
	local function spawnPillar(pos)
		local pillar = Instance.new("Part")
		pillar.Name = "ShadowPillar"
		pillar.Shape = Enum.PartType.Cylinder
		pillar.Size = Vector3.new(height, 5, 5) -- สูงเท่าห้อง, เส้นผ่านศูนย์กลาง 5
		-- หมุนทรงกระบอกให้ตั้งขึ้น (ใช้ math.rad ที่ถูกต้องแทน math.radians)
		pillar.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
		pillar.Material = Enum.Material.Brick
		pillar.Color = Color3.fromRGB(110, 80, 70)
		pillar.Anchored = true
		pillar.Parent = folder
	end
	
	spawnPillar(Vector3.new(-offset, height/2, -offset))
	spawnPillar(Vector3.new(offset, height/2, -offset))
	spawnPillar(Vector3.new(-offset, height/2, offset - 4))
	spawnPillar(Vector3.new(offset, height/2, offset - 4))
	
	-- 📦 สปอว์น "กล่องไม้" ตรงกลาง
	local crate = Instance.new("Part")
	crate.Name = "ShadowCrate"
	crate.Size = Vector3.new(6, 6, 6)
	crate.Position = Vector3.new(0, 3, -4)
	crate.Material = Enum.Material.Wood
	crate.Color = Color3.fromRGB(130, 100, 70)
	crate.Anchored = true
	crate.Parent = folder
	
	-- 🏁 ปรับจุดเกิดของตัวละคร (SpawnLocation) ให้อยู่กึ่งกลางห้องทดสอบ
	local spawnLocation = workspace:FindFirstChildOfClass("SpawnLocation")
	if spawnLocation then
		spawnLocation.Position = Vector3.new(0, 1, 6)
	else
		local newSpawn = Instance.new("SpawnLocation")
		newSpawn.Name = "TestRoomSpawn"
		newSpawn.Size = Vector3.new(6, 1, 6)
		newSpawn.Position = Vector3.new(0, 0.5, 6)
		newSpawn.Anchored = true
		newSpawn.Parent = folder
	end
	
	print("[ServerMain]: ห้องครอบสำหรับทดสอบไฟฉายสปอว์นเสร็จสิ้นที่พิกัด 0, 0, 0")
end

-- สั่งรันระบบสร้างห้อง
task.spawn(createTestRoom)

print("Zombie Island Game: ระบบฝั่ง Server บูตเสร็จสิ้น!")
