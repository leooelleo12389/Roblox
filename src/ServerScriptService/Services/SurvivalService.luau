local SurvivalService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SurvivalConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("SurvivalConfig"))

-- ตัวแปรเก็บเวลาอัปเดตสถานะล่าสุดของแต่ละผู้เล่น (ฝั่งเซิร์ฟเวอร์)
local lastHungerUpdate = {}
local lastInfectionUpdate = {}
local lastStarveDamage = {}

function SurvivalService.Init()
	print("SurvivalService: บูตอัปเดตระบบเอาชีวิตรอด (หิว & ติดเชื้อ) ฝั่ง Server สำเร็จ!")
	
	-- จัดการเมื่อผู้เล่นเข้าร่วมเซิร์ฟเวอร์
	local function onPlayerAdded(player)
		-- ติดตั้ง Attributes ค่าเริ่มต้นสำหรับบันทึกประวัติชีพจร
		player:SetAttribute("Hunger", SurvivalConfig.HUNGER_MAX)
		player:SetAttribute("Infection", 0)
		
		lastHungerUpdate[player] = tick()
		lastInfectionUpdate[player] = tick()
		lastStarveDamage[player] = tick()
		
		-- รีเซ็ตค่าชีพจรทั้งหมดกลับมาสมบูรณ์เมื่อเกิดใหม่
		player.CharacterAdded:Connect(function(character)
			player:SetAttribute("Hunger", SurvivalConfig.HUNGER_MAX)
			player:SetAttribute("Infection", 0)
			
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid then
				humanoid.Died:Connect(function()
					-- รีเซ็ตเมื่อเสียชีวิตแล้ว
					player:SetAttribute("Hunger", SurvivalConfig.HUNGER_MAX)
					player:SetAttribute("Infection", 0)
				end)
			end
		end)
		
		-- 💬 ระบบแชตคำสั่งแอดมินทดสอบ (Admin Console Message Command)
		player.Chatted:Connect(function(message)
			local args = string.split(message, " ")
			local command = args[1]
			
			if command == "/hunger" then
				local val = tonumber(args[2])
				if val then
					val = math.clamp(val, 0, SurvivalConfig.HUNGER_MAX)
					player:SetAttribute("Hunger", val)
					print(string.format("[Survival Admin]: ปรับความหิวของ %s เป็น: %.1f", player.Name, val))
				end
			elseif command == "/infect" then
				local val = tonumber(args[2])
				if val then
					val = math.clamp(val, 0, SurvivalConfig.INFECTION_MAX)
					player:SetAttribute("Infection", val)
					print(string.format("[Survival Admin]: ปรับเปอร์เซ็นต์ติดเชื้อของ %s เป็น: %.1f", player.Name, val))
				end
			elseif command == "/heal" then
				player:SetAttribute("Hunger", SurvivalConfig.HUNGER_MAX)
				player:SetAttribute("Infection", 0)
				
				local char = player.Character
				if char then
					local humanoid = char:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.Health = humanoid.MaxHealth
					end
				end
				print(string.format("[Survival Admin]: ทำการรักษาเติม HP/ค่าหิว/และสลัดพิษไวรัสให้ %s เรียบร้อย!", player.Name))
			end
		end)
	end
	
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, p)
	end
	
	-- เคลียร์หน่วยความจำเมื่อผู้เล่นออกจากเซิร์ฟเวอร์
	Players.PlayerRemoving:Connect(function(player)
		lastHungerUpdate[player] = nil
		lastInfectionUpdate[player] = nil
		lastStarveDamage[player] = nil
	end)
	
	-- 🔄 ลูปประมวลผลคำนวณการหิวและการเติบโตไวรัสในร่างกาย
	RunService.Heartbeat:Connect(function()
		local now = tick()
		
		for _, player in ipairs(Players:GetPlayers()) do
			local hunger = player:GetAttribute("Hunger") or SurvivalConfig.HUNGER_MAX
			local infection = player:GetAttribute("Infection") or 0
			
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			
			-- 1. การเผาผลาญความหิวตามกาลเวลา (Hunger Decay)
			if now - (lastHungerUpdate[player] or 0) >= SurvivalConfig.HUNGER_DECR_INTERVAL then
				lastHungerUpdate[player] = now
				if hunger > 0 then
					hunger = math.max(0, hunger - SurvivalConfig.HUNGER_DECR_AMOUNT)
					player:SetAttribute("Hunger", hunger)
				end
			end
			
			-- 2. ดาเมจลดพลังชีวิตกรณีอดอยากจนเกลี้ยง (Starvation Damage)
			if hunger <= 0 and humanoid and humanoid.Health > 0 then
				if now - (lastStarveDamage[player] or 0) >= SurvivalConfig.STARVATION_DAMAGE_INTERVAL then
					lastStarveDamage[player] = now
					humanoid:TakeDamage(SurvivalConfig.STARVATION_DAMAGE_AMOUNT)
					print(string.format("[Starvation]: %s หิวโซจนเริ่มหักเลือด! HP ปัจจุบัน: %.1f", player.Name, humanoid.Health))
				end
			end
			
			-- 3. ไวรัสติดเชื้อขยายขอบเขตและปลิดชีพ (Infection Spreading)
			if infection > 0 and infection < SurvivalConfig.INFECTION_MAX then
				if now - (lastInfectionUpdate[player] or 0) >= SurvivalConfig.INFECTION_DECR_INTERVAL then
					lastInfectionUpdate[player] = now
					infection = math.min(SurvivalConfig.INFECTION_MAX, infection + SurvivalConfig.INFECTION_GROWTH_AMOUNT)
					player:SetAttribute("Infection", infection)
					
					-- ไวรัสเต็ม 100% = เสียชีวิตและกลายเป็นซอมบี้
					if infection >= SurvivalConfig.INFECTION_MAX then
						if humanoid and humanoid.Health > 0 then
							humanoid.Health = 0
							print(string.format("[Infection]: %s เสียชีวิตเนื่องจากไวรัสลุกลามถึงขีดสุด 100%%!", player.Name))
						end
					end
				end
			end
		end
	end)
end

return SurvivalService
