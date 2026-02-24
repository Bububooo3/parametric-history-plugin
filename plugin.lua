--!optimize 2

-- Detect new baseparts
----> workspace:descendent added/removing

-- Detect changes in basepart properties
----> Predefined fxn connected to propertyChanged signal

-- Store data as "keyframes"
----> Long buffer for each instance
----> Parsing fxn

type FrameData = {
	cframe: { number }, -- 12 * f32 is like 48 bytes
	scale: Vector3, -- 3 * f32 = 12 bytes
	cancollide: boolean, -- (shared 1 byte) u8
	anchored: boolean, -- (shared 1 byte) u8
	color3: Color3, -- 3 * u8 = 3 bytes
	tagline: string, -- varies (+ 2 for len)
}

-- Services
local HS = game:GetService("HttpService")
local CS = game:GetService("CollectionService")

-- LinkedList
local root: number -- reverse linkedlist inside of our hashmaps (first capture)
local head: number -- like the most recent capture
local current: number -- our current node

-- Magic numbers
local DESTROY_CODE = -2 -- if #cframe == 1 and [1] is this code then we know this is the end of the line and we handle it accordingly
local TAGLINE_BYTE_LIMIT = 28
local STORAGE_LIMIT = 8000 -- bytes (calibrate later)

-- Storage
local tracked: { [string]: { [number]: number } } = {} -- [UID]: {[timestamp]: cursor location}
local storage = buffer.create((64 + TAGLINE_BYTE_LIMIT) * STORAGE_LIMIT)
local available = #storage

setmetatable(tracked, {
	__index = function(t, k)
		local newItem = {}
		rawset(t, k, newItem)
		return newItem
	end,
})

-- Helper fxns
local function getFrameData(token: buffer) end

local function tokenizeFrameData(data: FrameData): number
	local offset = 0 -- units is bytes
	local tl = data.tagline
	local l = tl:len()
	local b = buffer.create(64 + 16 + l * 8)

	if available - #b < 0 then
		-- make space by shifting everything over (buffer.copy())
		--[[
		TODO FINISH SWITCHING FROM USING A TABLE OF BUFFERS TO USING ONE GIANT BUFFER
		MAKE SURE TO EDIT THE "tracked" CONTAINER TOO WHEN MAKING SPACE FOR NEW DATA
		]]
	end

	-- CFrame components [48]
	for _, n in ipairs(data.cframe) do
		buffer.writef32(b, offset, n)
		offset += 4
	end

	-- Scale [12]
	local s = data.scale
	buffer.writef32(b, offset, s.X)
	buffer.writef32(b, offset + 4, s.Y)
	buffer.writef32(b, offset + 8, s.Z)
	offset += 12

	-- CanCollide/Anchored [1]
	local ca = 0 ----> just learned this. super clever!
	if data.cancollide then
		ca += 1
	end
	if data.anchored then
		ca += 2
	end
	buffer.writeu8(b, offset, ca)
	offset += 1

	-- Color3 [3]
	local c = data.color3
	buffer.writeu8(b, offset, (c.R * 255) // 1)
	buffer.writeu8(b, offset + 1, (c.B * 255) // 1)
	buffer.writeu8(b, offset + 2, (c.G * 255) // 1)
	offset += 3

	-- Tagline [idk + 2]
	buffer.writeu16(b, offset, l)
	buffer.writestring(b, offset + 2, tl)

	available -= offset
	return offset
end

----> Do the drawing now
local function updateLog() end

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
		task.delay(0.05, capture, UID, `Removed {i.Name} from Workspace`) -- might wanna calibrate that delay
	end
end)
