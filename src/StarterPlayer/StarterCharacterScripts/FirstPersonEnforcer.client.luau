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
	
	-- 3. แสดงเฉพาะปลายแขนขวาและเครื่องมือที่ถือเพื่อไม่ให้บดบังมุมมองหน้าจอ
	RunService.RenderStepped:Connect(function()
		for _, child in ipairs(character:GetChildren()) do
			-- สำหรับโมเดล R15: แสดงเฉพาะมือขวาและแขนท่อนล่างขวา ซ่อนส่วนไหล่และแขนซ้ายทั้งหมด
			if child.Name == "RightHand" or child.Name == "RightLowerArm" then
				child.LocalTransparencyModifier = 0
			elseif child.Name == "RightUpperArm" or child.Name == "LeftHand" or child.Name == "LeftLowerArm" or child.Name == "LeftUpperArm" then
				child.LocalTransparencyModifier = 1
				
			-- สำหรับโมเดล R6: แสดงแขนขวา ซ่อนแขนซ้าย
			elseif child.Name == "Right Arm" then
				child.LocalTransparencyModifier = 0
			elseif child.Name == "Left Arm" then
				child.LocalTransparencyModifier = 1
				
			-- แสดงเครื่องมือ/อาวุธที่กำลังถืออยู่เสมอ
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
print("FirstPersonEnforcer: ล็อกมุมมองบุคคลที่หนึ่งและจัดระเบียบการซ่อนแขนไม่ให้บังหน้าจอสำเร็จสำหรับ " .. character.Name)
