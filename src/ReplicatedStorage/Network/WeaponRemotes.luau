local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ตรวจสอบและสร้างโฟลเดอร์สำหรับรีโมทเพื่อการซิงค์เครือข่าย
local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not RemotesFolder then
	RemotesFolder = Instance.new("Folder")
	RemotesFolder.Name = "Remotes"
	RemotesFolder.Parent = ReplicatedStorage
end

local WeaponAttackEvent = RemotesFolder:FindFirstChild("WeaponAttack")
if not WeaponAttackEvent then
	WeaponAttackEvent = Instance.new("RemoteEvent")
	WeaponAttackEvent.Name = "WeaponAttack"
	WeaponAttackEvent.Parent = RemotesFolder
end

local WeaponReplicateEvent = RemotesFolder:FindFirstChild("WeaponReplicate")
if not WeaponReplicateEvent then
	WeaponReplicateEvent = Instance.new("RemoteEvent")
	WeaponReplicateEvent.Name = "WeaponReplicate"
	WeaponReplicateEvent.Parent = RemotesFolder
end

local WeaponRemotes = {
	WeaponAttack = WeaponAttackEvent,
	WeaponReplicate = WeaponReplicateEvent
}

return WeaponRemotes
