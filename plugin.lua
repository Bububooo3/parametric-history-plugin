--!optimize 2

-- Detect new baseparts
----> workspace:descendent added/removing

-- Detect changes in basepart properties
----> Predefined fxn connected to propertyChanged signal

-- Store data as "keyframes"
----> Long buffer for each instance
----> Parsing fxn

type FrameData = {
	cframe: { number }, -- the 12 numbers
	scale: Vector3,
	cancollide: boolean,
	anchored: boolean,
	color3: Color3,
	tagline: string, -- like "Part created in workspace" or something
}

-- Services
local HS = game:GetService("HttpService")
local CS = game:GetService("CollectionService")

-- LinkedList
local root: number -- reverse linkedlist inside of our hashmaps (first capture)
local head: number -- like the most recent capture
local current: number -- our current node

-- Magic numbers
local destructionCode = -2 -- if #cframe == 1 and [1] is -2 then we know this is the end of the line and we handle it accordingly

-- Storage
local tracked: { [string]: { [number]: buffer } } = {}

setmetatable(tracked, {
	__index = function(t, k)
		local newItem = {}
		rawset(t, k, newItem)
		return newItem
	end,
})

-- Helper fxns
local function getFrameData(token: buffer) end

local function tokenizeFrameData(data: FrameData) end

local function updateLog() end

local function capture(UID: string, description: string)
	-- Handle the real deal background stuff up in here
	local part: BasePart = CS:GetTagged(UID)[1]
	local ref = tracked[UID] -- so what we wanna do is have each UID in tracked contain a framedata history as a table of buffers w/ unique time as key

	--------------------------------------
	if not part then -- please pardon this interruption
		if #ref > 0 then -- the part was destroyed
			rawset(
				ref,
				os.time(),
				tokenizeFrameData({
					cframe = {destructionCode},
					scale = Vector3.zero,
					cancollide = false,
					anchored = false,
					color3 = 0,
					tagline = description or `Removed item with ID: <{UID}> from Workspace`,
				})
			)

			return
		end

		-- if we're atp, then this thing never even existed
		warn(`Failed to locate item with ID: <{UID}>`)
		return
	end
	--------------------------------------

	description = (not description or description == "") and `Edited {part.Name}` or description

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

	-- draw it out in the UI down there
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
		task.delay(0.05, capture, UID, `Removed {i.Name} from Workspace`) -- might wanna calibrate that delay
	end
end)
