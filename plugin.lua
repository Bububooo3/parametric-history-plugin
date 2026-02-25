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

----> CAPTURE
------> (store a snapshot in the buffer)
local function capture(UID: string, description: string)
	-- Handle the real deal background stuff up in here
	local part: BasePart = CS:GetTagged(UID)[1]
	local ref = tracked[UID] -- so what we wanna do is have each UID in tracked contain a framedata history as a table of buffers w/ unique time as key

	--------------------------------------
	if (part == nil) or part.Parent ~= workspace then -- please pardon this interruption
		if #ref > 0 then -- the part was destroyed
			rawset(
				ref,
				os.time(),
				tokenizeFrameData({
					cframe = { DESTROY_CODE },
					scale = Vector3.zero,
					cancollide = false,
					anchored = false,
					color3 = 0,
					tagline = description or `Removed item with ID: <{UID}> from Workspace`,
				})
			)

			updateLog()
			return
		end

		-- if we're atp, then this thing never even existed
		tracked[UID] = nil
		warn(`Failed to locate item with ID: <{UID}>`)
		return
	end
	--------------------------------------

	description = taglineEncode((not description or description == "") and `Edited {part.Name}` or description)

	rawset(
		ref,
		os.time(),
		tokenizeFrameData({
			cframe = part.CFrame:GetComponents(),
			scale = part.Size,
			cancollide = part.CanCollide,
			anchored = part.Anchored,
			color3 = part.Color,
			tagline = description,
		})
	)

	updateLog()
end

-- Connections, detections...
workspace.DescendantAdded:Connect(function(i: Instance)
	if i:IsA("BasePart") then
		local UID = HS:GenerateGUID(false)
		CS:AddTag(i, UID)
		capture(UID, `Added {i.Name} to Workspace`) -- the first one (initialization)
	end
end)

workspace.DescendantRemoving:Connect(function(i: Instance)
	if i:IsA("BasePart") then
		local UID = HS:GenerateGUID(false)
		task.delay(0.05, capture, UID, `Removed {i.Name} from Workspace`) -- might wanna calibrate that bad boy in the future
		-- 			^ or even just make it a setting so that I don't even have to deal with it
	end
end)
