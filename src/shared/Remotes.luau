--!strict
-- src/shared/Remotes.luau
-- Inicializador y acceso seguro a RemoteEvents (compartido entre Cliente y Servidor)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTES_FOLDER_NAME = "Remotes"

local REMOTE_NAMES = {
	"FireWeapon",
	"HitMarker",
	"InkUpdate",
	"MatchStateUpdate",
	"TerritoryUpdate",
}

local function getOrCreateFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
	if not folder then
		if RunService:IsServer() then
			local newFolder = Instance.new("Folder")
			newFolder.Name = REMOTES_FOLDER_NAME
			newFolder.Parent = ReplicatedStorage
			return newFolder
		else
			return ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME) :: Folder
		end
	end
	return folder :: Folder
end

local Remotes = {}

function Remotes.InitServer()
	local folder = getOrCreateFolder()
	for _, name in REMOTE_NAMES do
		if not folder:FindFirstChild(name) then
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
	end
end

function Remotes.Get(name: string): RemoteEvent
	local folder = getOrCreateFolder()
	local ev = folder:FindFirstChild(name)
	if not ev then
		return folder:WaitForChild(name) :: RemoteEvent
	end
	return ev :: RemoteEvent
end

return Remotes

