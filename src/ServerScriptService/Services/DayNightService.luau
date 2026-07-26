local DayNightService = {}

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Configs = ReplicatedStorage:WaitForChild("Configs")
local DayNightConfig = require(Configs:WaitForChild("DayNightConfig"))

-- ตัวแปรสถานะควบคุมเวลา
local isTimePaused = false
local timeSpeedMultiplier = 1
local isNightState = false
local survivalDay = 1 -- เริ่มที่วันแรกของเกม (Day 1)

function DayNightService.Init()
	-- เซตจำนวนวันเริ่มต้นลงระบบ
	workspace:SetAttribute("Day", survivalDay)
	
	-- 1. รันระบบเวลาใน Loop เบื้องหลัง
	task.spawn(function()
		local duration = DayNightConfig.CYCLE_DURATION
		local dayStart = DayNightConfig.DAY_START_HOUR
		local nightStart = DayNightConfig.NIGHT_START_HOUR
		
		Lighting.ClockTime = 8.0 -- เริ่มที่ 8 โมงเช้า
		
		while true do
			local deltaTime = task.wait(0.05)
			
			if not isTimePaused then
				local hoursPerSecond = (24 / duration) * timeSpeedMultiplier
				local newTime = Lighting.ClockTime + (hoursPerSecond * deltaTime)
				
				-- ขึ้นวันใหม่เมื่อพิกัดหมุนผ่านเวลา 24:00 น.
				if newTime >= 24 then
					newTime = newTime - 24
					survivalDay = survivalDay + 1
					workspace:SetAttribute("Day", survivalDay)
					print("[DayNightService]: 📅 ขึ้นสู่วันใหม่! วันที่สะสม: Day " .. tostring(survivalDay))
				end
				
				Lighting.ClockTime = newTime
			end
			
			-- ตรวจสอบสถานะกลางวัน/กลางคืน
			local currentHour = Lighting.ClockTime
			local isNightNow = (currentHour >= nightStart) or (currentHour < dayStart)
			
			if isNightNow ~= isNightState then
				isNightState = isNightNow
				workspace:SetAttribute("IsNight", isNightState)
				
				if isNightState then
					print("[DayNightService]: 🌙 เข้าสู่เวลากลางคืน (ซอมบี้ได้บัฟ)")
				else
					print("[DayNightService]: ☀️ เข้าสู่เวลากลางวัน")
				end
			end
		end
	end)
	
	-- 2. ระบบดักฟังแชตผู้เล่นเพื่อปรับเวลา
	local function onPlayerAdded(player)
		player.Chatted:Connect(function(message)
			local args = string.split(message, " ")
			local command = args[1]
			
			if command == "/time" then
				local param = args[2]
				
				if not param then
					warn("[Time Command]: วิธีใช้ /time <0-24 | pause | resume | speed <ตัวคูณ>>")
					return
				end
				
				if param == "pause" then
					isTimePaused = true
					print("[Admin Command]: หยุดระบบเวลาชั่วคราว")
				elseif param == "resume" then
					isTimePaused = false
					print("[Admin Command]: เริ่มเดินระบบเวลาต่อ")
				elseif param == "speed" and args[3] then
					local multiplier = tonumber(args[3])
					if multiplier then
						timeSpeedMultiplier = multiplier
						print("[Admin Command]: ปรับความเร็วเวลาเป็น: " .. tostring(multiplier) .. " เท่า")
					end
				else
					local hour = tonumber(param)
					if hour and hour >= 0 and hour <= 24 then
						Lighting.ClockTime = hour
						print("[Admin Command]: ตั้งชั่วโมงท้องฟ้าเป็น: " .. tostring(hour) .. ":00 น.")
					end
				end
			elseif command == "/day" then
				local param = args[2]
				
				if not param then
					warn("[Day Command]: วิธีใช้ /day <ตัวเลขวัน | skip>")
					return
				end
				
				if param == "skip" then
					survivalDay = survivalDay + 1
					workspace:SetAttribute("Day", survivalDay)
					print("[Admin Command]: ทำการข้ามวัน ➔ วันปัจจุบันคือ: Day " .. tostring(survivalDay))
				else
					local targetDay = tonumber(param)
					if targetDay and targetDay > 0 then
						survivalDay = targetDay
						workspace:SetAttribute("Day", survivalDay)
						print("[Admin Command]: ตั้งจำนวนวันสะสมเป็น: Day " .. tostring(survivalDay))
					end
				end
			end
		end)
	end
	
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	
	print("DayNightService: บูตอัปเดตระบบสลับวันและตัวแปรนับวันสำเร็จ!")
end

return DayNightService
