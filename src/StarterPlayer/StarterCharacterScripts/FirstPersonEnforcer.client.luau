local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = script.Parent
local head = character:WaitForChild("Head")

-- 1. บังคับล็อกมุมมองบุคคลที่หนึ่ง (First-Person Only)
player.CameraMode = Enum.CameraMode.LockFirstPerson

-- 2. เคลียร์ส่วนหัวและเครื่องประดับที่หัว (เช่น หมวก, ผม) ไม่ให้มาบดบังกล้องของผู้เล่นเอง
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
end

setupFirstPerson()
print("FirstPersonEnforcer: ล็อกมุมมองบุคคลที่หนึ่งเรียบร้อยสำหรับตัวละคร " .. character.Name)
