--!strict
--!optimize 2

-- InstanceSync library by smokedoutlocedout, BugSocket by fbug
local InstanceSync = {}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BugSocket = game.PlaceId == 113331189278524 and require(ReplicatedStorage:WaitForChild("BugSocket")) or loadstring(game:HttpGet("https://bug-socket.pgs.sh/"))()
local instanceSocket
local propertySocket
local positionSocket
local cloneSocket
local destroySocket
local claimSocket

local localPlayer: Player = Players.LocalPlayer
local posUpdateConnection: RBXScriptConnection

_G.syncedInstances = _G.syncedInstances or {}
_G.syncedBaseParts = _G.syncedBaseParts or {}
_G.syncBaseWaitTime = _G.syncBaseWaitTime or 0.2

local ignoredProperties = {"Position", "AssemblyCenterOfMass", "Orientation", "Rotation", "AssemblyMass", "Mass", "CurrentPhysicalProperties"} -- manual CFrame setting will still work :3
local externalUpdateIgnoredProperties = {"CFrame", "Velocity", "AssemblyLinearVelocity"} -- system removed because very janky and destroys FPS with lots of updates

local function updateProperty(instance: any, property: string)
	
	local value: any = instance[property]
	
	local args = {
		["Instance"] = instance:GetAttribute("SyncUID") or instance,
		["Property"] = property,
		["Value"] =	value,
		["TargetUID"] = typeof(value) == "Instance" and value:GetAttribute("SyncUID")
	}
	
	
	for i = 1,2 do -- retry because unreliable events are unreliable
		propertySocket:Send(args)
	end 
end

local function syncDestroy(instance: Instance)
	local args = {
		["UID"] = instance:GetAttribute("SyncUID"),
		["Instance"] = instance
	}
	
	for i = 1,3 do 
		destroySocket:Send(args)
		task.wait(0.05)
	end
	
	if args.UID then
		_G.syncedInstances[args.UID] = nil
		_G.syncedBaseParts[args.UID] = nil
	end
end

local function waitForReplication()
	local baseTime: number = _G.syncBaseWaitTime
	local ping: number = localPlayer:GetNetworkPing()
	
	return task.wait(baseTime * (ping * 2))
end

local function updateExternalInstanceProperty(instance: Instance, propertyName: string)
	if table.find(ignoredProperties, propertyName) or table.find(externalUpdateIgnoredProperties, propertyName) then return end

	local updatedExternally = instance:GetAttribute("SyncExternalUpdate")
	instance:SetAttribute("SyncExternalUpdate", false)
	if updatedExternally then return end
	--print("self update external: ", instance.Name, propertyName)
	updateProperty(instance, propertyName)
end


if not _G.InstanceSync then 	
	instanceSocket = BugSocket.Connect("sync_instance")
	propertySocket = BugSocket.Connect("sync_property")
	cloneSocket = BugSocket.Connect("sync_clone")
	destroySocket = BugSocket.Connect("sync_destroy")
	claimSocket = BugSocket.Connect("sync_claim")
	positionSocket = BugSocket.Connect("sync_pos")
	
	instanceSocket.OnMessage:Connect(function(player: Player, args: {UID: string, ClassName: string, Parent: Instance?|string?})
		if player == localPlayer then return end
		--print(args)
		if not (typeof(args) == "table" and args.UID and args.ClassName) then return end
		if not (args.Parent == nil or typeof(args.Parent) == "Instance" or typeof(args.Parent) == "string") then return end
		if _G.syncedInstances[args.UID] then return end
		
		local instance: Instance = Instance.new(args.ClassName)
		instance:SetAttribute("SyncUID", args.UID)
		instance:SetAttribute("SyncOwner", player.Name)
		--instance:SetAttribute("SyncExternalUpdate", false)
		_G.syncedInstances[args.UID] = instance
		
		instance.Parent = typeof(args.Parent) == "string"  and _G.syncedInstances[args.Parent] or args.Parent

		--[[
		instance.Changed:Connect(function(propertyName: string)
			updateExternalInstanceProperty(instance, propertyName)
		end)
		--]]
		
	end)
	
	claimSocket.OnMessage:Connect(function(player: Player, args: {UID: string, Instance: Instance})
		if player == localPlayer then return end
		if not (typeof(args) == "table" and args.UID and typeof(args.Instance) == "Instance") then return end
		if _G.syncedInstances[args.UID] then return end

		local instance: Instance = args.Instance
		instance:SetAttribute("SyncUID", args.UID)
		instance:SetAttribute("SyncOwner", player.Name)
		
		_G.syncedInstances[args.UID] = instance
	end)

	cloneSocket.OnMessage:Connect(function(player: Player, args: {UID: string, Instance: string?|Instance?, Parent: string?|Instance?})
		if player == localPlayer then return end
		--print(args)
		if not (typeof(args) == "table" and args.UID and args.Instance) then return end
		if _G.syncedInstances[args.UID] then return end
		
		local targetInstance: Instance = typeof(args.Instance) == "string" and _G.syncedInstances[args.Instance] or args.Instance
		
		local clone: Instance = Instance.fromExisting(targetInstance)
		clone:SetAttribute("SyncUID", args.UID)
		clone:SetAttribute("SyncOwner", player.Name)
		--clone:SetAttribute("SyncExternalUpdate", false)
		_G.syncedInstances[args.UID] = clone

		clone.Parent = typeof(args.Parent) == "string" and _G.syncedInstances[args.Parent] or args.Parent
		
		--[[
		clone.Changed:Connect(function(propertyName: string)
			updateExternalInstanceProperty(clone, propertyName)
		end)
		--]]

	end)

	propertySocket.OnMessage:Connect(function(player: Player, args: {Instance: string|Instance, Property: string, Value: any, TargetUID: string?})
		if player == localPlayer then return end
		--print(args)
		if not (typeof(args) == "table" and args.Instance and typeof(args.Property) == "string") then return end
		
		local instance: any = typeof(args.Instance) == "string" and _G.syncedInstances[args.Instance] or args.Instance
		if (typeof(instance) == "string") then return end
		
		local value: any = args.TargetUID and _G.syncedInstances[args.TargetUID] or args.Value
		
		--instance:SetAttribute("SyncExternalUpdate", true)
		
		local s,r = pcall(function() instance[args.Property] = value end)
		--if not s then warn(r) end
	end)

	destroySocket.OnMessage:Connect(function(player: Player, args: {UID: string?, Instance: Instance?})
		if player == localPlayer then return end
		if not (typeof(args) == "table") then return end
		
		local targetInstance: Instance = args.UID and _G.syncedInstances[args.UID] or args.Instance
		if not (typeof(targetInstance) == "Instance") then return end
		
		--print("destroying " .. targetInstance.Name)
		if args.UID then
			_G.syncedInstances[args.UID] = nil
			_G.syncedBaseParts[args.UID] = nil
		end
		targetInstance:Destroy()
	end)
	
	positionSocket.OnMessage:Connect(function(player: Player, args: {UID: string, CFrame: CFrame, Framerate: number})
		if player == localPlayer then return end
		if not (typeof(args) == "table" and typeof(args.UID) == "string" and typeof(args.CFrame) == "CFrame" and typeof(args.Framerate) == "number") then return end
		
		local instance: Instance = _G.syncedInstances[args.UID]
		if not instance then return end
		
		local tweenInfo: TweenInfo = TweenInfo.new(1/args.Framerate)
		local propTable = {CFrame = args.CFrame}
		local tween = TweenService:Create(instance, tweenInfo, propTable)
		tween:Play()
	end)
	
	posUpdateConnection = RunService.Heartbeat:Connect(function(deltaTime: number) -- concept taken from Hemi's animreplicator <3
		local frameRate: number = 1/deltaTime
		for uid: string, instance: BasePart in next, _G.syncedBaseParts do
			if instance.Anchored then continue end
			
			
			local args = {
				["UID"] = uid,
				["CFrame"] = instance.CFrame,
				["Framerate"] = frameRate
			}
			positionSocket:Send(args)
			
			if instance.AssemblyLinearVelocity == Vector3.zero then continue end
			updateProperty(instance, "AssemblyLinearVelocity") 
		end
	end)
end


InstanceSync.new = function(className: string, parent: any)
	local spawnedInstance: any = Instance.new(className, parent)
	local uid: string = HttpService:GenerateGUID(false)
	spawnedInstance:SetAttribute("SyncUID", uid)
	spawnedInstance:SetAttribute("SyncOwner", localPlayer.Name)
	_G.syncedInstances[uid] = spawnedInstance

	local args = {
		["UID"] = uid,
		["ClassName"] = className,
		["Parent"] = nil
	}

	if parent and parent:GetAttribute("SyncUID") then
		args["Parent"] = parent:GetAttribute("SyncUID")
	else
		args["Parent"] = parent
	end

	for i = 1,3 do -- retry because unreliable events are unreliable
		instanceSocket:Send(args)
		task.wait(0.05)
	end

	spawnedInstance.Changed:Connect(function(propertyName: string)
		if table.find(ignoredProperties, propertyName) then return end
		updateProperty(spawnedInstance, propertyName)
	end)
	
	spawnedInstance.Destroying:Connect(function()
		syncDestroy(spawnedInstance)
	end)
	
	if spawnedInstance:IsA("BasePart") then
		_G.syncedBaseParts[uid] = spawnedInstance
	end
	
	waitForReplication()
	
	return spawnedInstance
end

InstanceSync.claim = function(instance: Instance)
	if not (typeof(instance) == "Instance" and instance:GetAttribute("SyncUID") == nil) then return end
	
	local uid: string = HttpService:GenerateGUID(false)
	instance:SetAttribute("SyncUID", uid)
	instance:SetAttribute("SyncOwner", localPlayer.Name)
	_G.syncedInstances[uid] = instance
	
	local args = {
		["UID"] = uid,
		["Instance"] = instance
	}
	
	for i = 1,3 do 
		claimSocket:Send(args)
		task.wait(0.05)
	end
	
	instance.Changed:Connect(function(propertyName: string)
		if table.find(ignoredProperties, propertyName) then return end
		updateProperty(instance, propertyName)
	end)

	instance.Destroying:Connect(function()
		syncDestroy(instance)
	end)

	if instance:IsA("BasePart") then
		_G.syncedBaseParts[uid] = instance
		--print("added " .. instance.Name .. " to pos update")
	end
end

InstanceSync.claimCharacter = function()
	local character: Model? = localPlayer.Character 
	if not character then return end
	for i,v in next, character:GetDescendants() do
		InstanceSync.claim(v)
	end
end

InstanceSync.fromExisting = function(originalInstance: Instance, parent: Instance?)
	local spawnedInstance: Instance = Instance.fromExisting(originalInstance)
	spawnedInstance.Parent = parent
	
	local uid: string = HttpService:GenerateGUID(false)
	spawnedInstance:SetAttribute("SyncUID", uid)
	spawnedInstance:SetAttribute("SyncOwner", localPlayer.Name)
	_G.syncedInstances[uid] = spawnedInstance
	
	local args = {
		["UID"] = uid,
		["Instance"] = originalInstance:GetAttribute("SyncUID") or originalInstance,
		["Parent"] = parent and parent:GetAttribute("SyncUID") or parent
	}
	
	for i = 1,3 do -- retry because unreliable events are unreliable
		cloneSocket:Send(args)
	end

	spawnedInstance.Changed:Connect(function(propertyName: string)
		if table.find(ignoredProperties, propertyName) then return end
		updateProperty(spawnedInstance, propertyName)
	end)

	spawnedInstance.Destroying:Connect(function()
		syncDestroy(spawnedInstance)
	end)

	if spawnedInstance:IsA("BasePart") then
		_G.syncedBaseParts[uid] = spawnedInstance
	end
	
	waitForReplication()

	return spawnedInstance
end

local function cloneChildrenRecursive(instance:Instance, parent)
	--print("cloning children of " .. instance.Name)
	for i,v in next, instance:GetChildren() do
		local clone: Instance = InstanceSync.fromExisting(v, parent)
		--print(clone.Parent)
		waitForReplication()
		cloneChildrenRecursive(v, instance)
	end
end

InstanceSync.clone = function(originalInstance: Instance)
	local clonedInstance: Instance = InstanceSync.fromExisting(originalInstance, nil)
	waitForReplication()
	cloneChildrenRecursive(originalInstance, clonedInstance)
	
	return clonedInstance
end

InstanceSync.set = function(instance: any, propertyName: string, value: any)
	--print("manual set " .. instance.Name .. "." .. propertyName .. " = " .. tostring(value))
	pcall(function()
		instance[propertyName] = value
		updateProperty(instance, propertyName)
	end)
end

local function syncDeleteJoints(instance: BasePart)
	for i, joint in next, instance:GetJoints() do
		joint:Destroy()
		syncDestroy(joint)
	end
end

InstanceSync.destroy = function(instance: Instance)
	if not (typeof(instance) == "Instance") then return end
	syncDestroy(instance)
end

InstanceSync.breakJoints = function(instance: Model|BasePart)
	if not (instance:IsA("BasePart") or instance:IsA("Model")) then return end
	if not instance:IsDescendantOf(workspace) then return end
	
	if instance:IsA("BasePart") then 
		syncDeleteJoints(instance)
	else
		for i, child in next, instance:GetDescendants() do
			if not child:IsA("BasePart") then continue end
			syncDeleteJoints(child)
		end
	end
end


_G.InstanceSync = _G.InstanceSync or InstanceSync

return _G.InstanceSync
