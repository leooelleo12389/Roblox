local SurvivalConfig = {
	-- 🍗 ระบบจำลองความหิว (Hunger Configuration)
	HUNGER_MAX = 100,
	HUNGER_DECR_INTERVAL = 3,       -- ลดค่าความหิวทุกๆ กี่วินาที
	HUNGER_DECR_AMOUNT = 0.25,      -- จำนวนความหิวที่ลดในแต่ละรอบ (100 -> 0 ใช้เวลาประมาณ 20 นาที หรือ 1 วันเกมพอดี)
	STARVATION_DAMAGE_INTERVAL = 4, -- วินาทีที่ผู้เล่นโดนหักเลือดเมื่อหิวเป็น 0
	STARVATION_DAMAGE_AMOUNT = 2,    -- จำนวน HP ที่หักเมื่อหิวเหลือ 0
	
	-- ☣️ ระบบไวรัสและการติดเชื้อ (Infection Configuration)
	INFECTION_MAX = 100,
	INFECTION_DECR_INTERVAL = 2,    -- อัปเดตและแพร่เชื้อเพิ่มขึ้นในร่างกายทุกๆ กี่วินาที
	INFECTION_GROWTH_AMOUNT = 0.15,  -- อัตราไวรัสเพิ่มขึ้นตามเวลาเมื่อได้รับเชื้อ (>0) ต่อวิกฤต
}

return SurvivalConfig
