local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = script.Parent
local head = character:WaitForChild("Head")

-- 1. บังคับล็อกมุมมองบุคคลที่หนึ่ง (First-Person Only)
player.CameraMode = Enum.CameraMode.LockFirstPerson

-- 2. เคลียร์ส่วนหัวและเครื่องประดับที่หัวไม่ให้มาบดบังกล้อง
local function setupFirstPerson()
	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("BasePart") then
			-- ซ่อนส่วนหัว (Head)
			if child.Name == "Head" then
				RunService.RenderStepped:Connect(function()
					child.LocalTransparencyModifier = 1
				end)
			-- ซ่อนหมวก / ผม / แว่นตา
			elseif child.Parent:IsA("Accessory") then
				local accType = child.Parent.AccessoryType
				if accType == Enum.AccessoryType.Hair 
					or accType == Enum.AccessoryType.Hat 
					or accType == Enum.AccessoryType.Face 
					or accType == Enum.AccessoryType.Eyebrow 
					or accType == Enum.AccessoryType.Eyelash then
					
					RunService.RenderStepped:Connect(function()
						child.LocalTransparencyModifier = 1
					end)
				end
			end
		end
	end
	
	-- 3. แสดงแขนทั้งสองข้างและเครื่องมือที่ถือในมุมมองบุคคลที่หนึ่ง (Show Arms & Tools in FP)
	RunService.RenderStepped:Connect(function()
		for _, child in ipairs(character:GetChildren()) do
			-- ตรวจหาแขนซ้าย/แขนขวา (รองรับทั้งตัวละครแบบ R6 และ R15)
			if child.Name == "RightArm" or child.Name == "LeftArm" 
				or child.Name == "Right Arm" or child.Name == "Left Arm"
				or child.Name == "RightHand" or child.Name == "RightLowerArm" or child.Name == "RightUpperArm"
				or child.Name == "LeftHand" or child.Name == "LeftLowerArm" or child.Name == "LeftUpperArm" then
				
				if child:IsA("BasePart") then
					child.LocalTransparencyModifier = 0
				end
			-- ตรวจหาเครื่องมืออาวุธที่กำลังถืออยู่
			elseif child:IsA("Tool") then
				for _, part in ipairs(child:GetDescendants()) do
					if part:IsA("BasePart") then
						part.LocalTransparencyModifier = 0
					end
				end
			end
		end
	end)
end

setupFirstPerson()
print("FirstPersonEnforcer: ล็อกมุมมองบุคคลที่หนึ่งและเปิดการมองเห็นแขน/เครื่องมือสำหรับตัวละคร " .. character.Name)
