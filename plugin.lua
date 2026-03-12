--!optimize 2

-- Detect new baseparts
----> workspace:descendent added/removing

-- Detect changes in basepart properties
----> Predefined fxn connected to propertyChanged signal

-- Store data as "keyframes"
----> Long buffer for each instance
----> Parsing fxn

-- Services
local HS = game:GetService("HttpService")
local CS = game:GetService("CollectionService")

-- Dependencies
local Types = require("types")
local MS = require("mapstore")

--------------------------------------------------------------------------------
----> UI
------> (new entry in capture log)

--[[
ENTRY

- Tagline (shows on hover)
- Action-respective icon

]]
local function newEntry() end ----> Returns a new frame ready for insertion
local function updateLog() end ----> Creates a new 

updateLog()

--------------------------------------------------------------------------------
-- Connections, detections...
workspace.DescendantAdded:Connect(function(i: Instance)
	if i:IsA("BasePart") then
		local UID = HS:GenerateGUID(false)
		CS:AddTag(i, UID)
		MS.capture(UID, `Inserted {i.Name}`) -- the first one (initialization)

		--------------------------------------------------------------------------------
		i:GetPropertyChangedSignal("CFrame"):Connect(function()
			MS.capture(UID, `Transformed {i.Name}`)
		end)

		i:GetPropertyChangedSignal("Size"):Connect(function()
			MS.capture(UID, `Resized {i.Name}`)
		end)

		i:GetPropertyChangedSignal("CanCollide"):Connect(function()
			MS.capture(UID, (i.CanCollide and "Enabled" or "Disabled") .. ` collision: {i.Name}`)
		end)

		i:GetPropertyChangedSignal("Anchored"):Connect(function(property)
			MS.capture(UID, (i.Anchored and "Anchored" or "Unanchored") .. `: {i.Name}`)
		end)

		i:GetPropertyChangedSignal("Color"):Connect(function()
			MS.capture(UID, `Recolored {i.Name}`)
		end)

		--------------------------------------------------------------------------------
	end
end)

workspace.DescendantRemoving:Connect(function(i: Instance)
	if i:IsA("BasePart") then
		local UID = MS.getUID(i) ----> Try not to use often bc loops r sluggish, right?
		if UID then
			task.delay(0.05, MS.capture, UID, `Removed {i.Name}`) -- might wanna calibrate that bad boy in the future
			-- 			^ or even just make it a setting so that I don't even have to deal with it
		end
	end
end)
