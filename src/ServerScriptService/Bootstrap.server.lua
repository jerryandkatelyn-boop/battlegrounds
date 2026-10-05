--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Config = require(ReplicatedStorage:WaitForChild("TownShared"):WaitForChild("TownConfig"))
local QueueService = require(script.Parent.Town.QueueService)
local WorldService = require(script.Parent.Town.WorldService)

local town = workspace:WaitForChild("TinyTown", 15)
assert(town, "TinyTown model is missing. Reconnect Rojo using default.project.json.")
local previous = ReplicatedStorage:FindFirstChild(Config.RemoteFolder)
if previous then previous:Destroy() end
local folder = Instance.new("Folder")
folder.Name = Config.RemoteFolder
local remotes = {}
for _, name in ipairs({ "Request", "State" }) do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	remotes[name] = remote
end
folder.Parent = ReplicatedStorage
Players.RespawnTime = 2
local queues = QueueService.new(remotes, town)
WorldService.Start(town, queues)
queues:Start()
print("[Tiny Town] Town and destination queues ready" .. (queues.preview and " (Studio local preview)" or ""))
