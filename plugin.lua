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
local LS = require("linkedstore")
local MS = require("mapstore")



--------------------------------------------------------------------------------
----> UI
------> (new entry in capture log)
local function updateLog() end


updateLog()

-- Connections, detections...
workspace.DescendantAdded:Connect(function(i: Instance)
	if i:IsA("BasePart") then
		local UID = HS:GenerateGUID(false)
		CS:AddTag(i, UID)
		MS.capture(UID, `Inserted {i.Name}`) -- the first one (initialization)
	end
end)

workspace.DescendantRemoving:Connect(function(i: Instance)
	if i:IsA("BasePart")  then
		local UID = MS.getUID(i) ----> Try not to use often bc loops r sluggish, right?
		if UID then
			task.delay(0.05, MS.capture, UID, `Removed {i.Name}`) -- might wanna calibrate that bad boy in the future
			-- 			^ or even just make it a setting so that I don't even have to deal with it
		end
	end
end)
