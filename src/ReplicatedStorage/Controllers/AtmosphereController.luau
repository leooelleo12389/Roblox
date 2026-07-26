local AtmosphereController = {}

local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- กำหนดค่าบรรยากาศในแต่ละช่วงเวลา
local AMBIENT_PRESETS = {
	DAY = {
		Ambient = Color3.fromRGB(130, 130, 130),
		OutdoorAmbient = Color3.fromRGB(120, 120, 120),
		Brightness = 2.0,
		FogColor = Color3.fromRGB(190, 200, 215),
		FogEnd = 500,
		FogStart = 50
	},
	SUNSET = {
		Ambient = Color3.fromRGB(130, 90, 70), -- สีส้มสลัว
		OutdoorAmbient = Color3.fromRGB(120, 80, 60),
		Brightness = 1.0,
		FogColor = Color3.fromRGB(140, 90, 70),
		FogEnd = 250,
		FogStart = 20
	},
	NIGHT = {
		Ambient = Color3.fromRGB(8, 8, 20), -- สีน้ำเงินมืดสนิท
		OutdoorAmbient = Color3.fromRGB(3, 3, 10),
		Brightness = 0.15,
		FogColor = Color3.fromRGB(4, 4, 8), -- หมอกสีดำสนิท
		FogEnd = 65, -- หมอกจะมาบังตาทัศนวิสัยเหลือเพียง 65 สตัดเพื่อความหลอน!
		FogStart = 10
	}
}

-- เสียงบรรยากาศ (Ambient Audio)
local dayAmbience = Instance.new("Sound")
dayAmbience.Name = "DayAmbience"
dayAmbience.SoundId = "rbxassetid://9059530462" -- เสียงป่ากลางวัน
dayAmbience.Volume = 0
dayAmbience.Looped = true
dayAmbience.Parent = SoundService

local nightAmbience = Instance.new("Sound")
nightAmbience.Name = "NightAmbience"
nightAmbience.SoundId = "rbxassetid://1843110200" -- เสียงลมหวีดหวิวกลางคืน
nightAmbience.Volume = 0
nightAmbience.Looped = true
nightAmbience.Parent = SoundService

-- ฟังก์ชันช่วยทำการคำนวณการ Lerp ค่าสีและตัวเลข
local function lerpColor(c1, c2, alpha)
	return c1:Lerp(c2, alpha)
end

local function lerpNum(n1, n2, alpha)
	return n1 + (n2 - n1) * alpha
end

function AtmosphereController.Init()
	-- เปิดเสียงบรรยากาศ
	dayAmbience:Play()
	nightAmbience:Play()
	
	-- บังคับเปิดใช้งาน Fog (หมอก) ในระบบ
	Lighting.FogStart = AMBIENT_PRESETS.DAY.FogStart
	Lighting.FogEnd = AMBIENT_PRESETS.DAY.FogEnd
	
	RunService.RenderStepped:Connect(function(dt)
		local clockTime = Lighting.ClockTime
		local targetPreset = AMBIENT_PRESETS.DAY
		local nightVolumeTarget = 0
		local dayVolumeTarget = 0.5
		
		-- 1. ตัดสินใจเลือก Preset ตามชั่วโมงท้องฟ้า
		if clockTime >= 6.0 and clockTime < 17.0 then
			-- กลางวันเต็มตัว
			targetPreset = AMBIENT_PRESETS.DAY
			dayVolumeTarget = 0.5
			nightVolumeTarget = 0
			
		elseif clockTime >= 17.0 and clockTime < 18.5 then
			-- ช่วงโพล้เพล้ (กำลังมืด)
			local alpha = (clockTime - 17.0) / 1.5
			targetPreset = {
				Ambient = lerpColor(AMBIENT_PRESETS.DAY.Ambient, AMBIENT_PRESETS.SUNSET.Ambient, alpha),
				OutdoorAmbient = lerpColor(AMBIENT_PRESETS.DAY.OutdoorAmbient, AMBIENT_PRESETS.SUNSET.OutdoorAmbient, alpha),
				Brightness = lerpNum(AMBIENT_PRESETS.DAY.Brightness, AMBIENT_PRESETS.SUNSET.Brightness, alpha),
				FogColor = lerpColor(AMBIENT_PRESETS.DAY.FogColor, AMBIENT_PRESETS.SUNSET.FogColor, alpha),
				FogEnd = lerpNum(AMBIENT_PRESETS.DAY.FogEnd, AMBIENT_PRESETS.SUNSET.FogEnd, alpha),
				FogStart = lerpNum(AMBIENT_PRESETS.DAY.FogStart, AMBIENT_PRESETS.SUNSET.FogStart, alpha),
			}
			dayVolumeTarget = lerpNum(0.5, 0.1, alpha)
			nightVolumeTarget = lerpNum(0, 0.4, alpha)
			
		elseif clockTime >= 18.5 and clockTime < 19.5 then
			-- เริ่มเข้าสู่ค่ำคืนสนิท
			local alpha = (clockTime - 18.5) / 1.0
			targetPreset = {
				Ambient = lerpColor(AMBIENT_PRESETS.SUNSET.Ambient, AMBIENT_PRESETS.NIGHT.Ambient, alpha),
				OutdoorAmbient = lerpColor(AMBIENT_PRESETS.SUNSET.OutdoorAmbient, AMBIENT_PRESETS.NIGHT.OutdoorAmbient, alpha),
				Brightness = lerpNum(AMBIENT_PRESETS.SUNSET.Brightness, AMBIENT_PRESETS.NIGHT.Brightness, alpha),
				FogColor = lerpColor(AMBIENT_PRESETS.SUNSET.FogColor, AMBIENT_PRESETS.NIGHT.FogColor, alpha),
				FogEnd = lerpNum(AMBIENT_PRESETS.SUNSET.FogEnd, AMBIENT_PRESETS.NIGHT.FogEnd, alpha),
				FogStart = lerpNum(AMBIENT_PRESETS.SUNSET.FogStart, AMBIENT_PRESETS.NIGHT.FogStart, alpha),
			}
			dayVolumeTarget = lerpNum(0.1, 0, alpha)
			nightVolumeTarget = lerpNum(0.4, 0.8, alpha)
			
		elseif clockTime >= 19.5 or clockTime < 5.0 then
			-- กลางคืนเต็มตัว (มืดและน่ากลัวมาก)
			targetPreset = AMBIENT_PRESETS.NIGHT
			dayVolumeTarget = 0
			nightVolumeTarget = 0.8
			
		elseif clockTime >= 5.0 and clockTime < 6.0 then
			-- รุ่งเช้า (พระอาทิตย์ขึ้น)
			local alpha = (clockTime - 5.0) / 1.0
			targetPreset = {
				Ambient = lerpColor(AMBIENT_PRESETS.NIGHT.Ambient, AMBIENT_PRESETS.DAY.Ambient, alpha),
				OutdoorAmbient = lerpColor(AMBIENT_PRESETS.NIGHT.OutdoorAmbient, AMBIENT_PRESETS.DAY.OutdoorAmbient, alpha),
				Brightness = lerpNum(AMBIENT_PRESETS.NIGHT.Brightness, AMBIENT_PRESETS.DAY.Brightness, alpha),
				FogColor = lerpColor(AMBIENT_PRESETS.NIGHT.FogColor, AMBIENT_PRESETS.DAY.FogColor, alpha),
				FogEnd = lerpNum(AMBIENT_PRESETS.NIGHT.FogEnd, AMBIENT_PRESETS.DAY.FogEnd, alpha),
				FogStart = lerpNum(AMBIENT_PRESETS.NIGHT.FogStart, AMBIENT_PRESETS.DAY.FogStart, alpha),
			}
			dayVolumeTarget = lerpNum(0, 0.5, alpha)
			nightVolumeTarget = lerpNum(0.8, 0, alpha)
		end
		
		-- 2. ค่อยๆ ปรับเปลี่ยนแสงในระบบจริงอย่างราบรื่น (Smooth Lerping)
		local lerpSpeed = dt * 3 -- ความเร็วในการไล่โทนแสง
		
		Lighting.Ambient = Lighting.Ambient:Lerp(targetPreset.Ambient, lerpSpeed)
		Lighting.OutdoorAmbient = Lighting.OutdoorAmbient:Lerp(targetPreset.OutdoorAmbient, lerpSpeed)
		Lighting.Brightness = lerpNum(Lighting.Brightness, targetPreset.Brightness, lerpSpeed)
		Lighting.FogColor = Lighting.FogColor:Lerp(targetPreset.FogColor, lerpSpeed)
		Lighting.FogEnd = lerpNum(Lighting.FogEnd, targetPreset.FogEnd, lerpSpeed)
		Lighting.FogStart = lerpNum(Lighting.FogStart, targetPreset.FogStart, lerpSpeed)
		
		-- 3. ค่อยๆ ปรับระดับเสียงบรรยากาศ
		dayAmbience.Volume = lerpNum(dayAmbience.Volume, dayVolumeTarget, lerpSpeed)
		nightAmbience.Volume = lerpNum(nightAmbience.Volume, nightVolumeTarget, lerpSpeed)
	end)
	
	print("AtmosphereController: ระบบควบคุมบรรยากาศมืดและหมอก พร้อมทำงานแล้ว!")
end

return AtmosphereController
