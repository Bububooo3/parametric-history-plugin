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

type Node = {
	UID: string,
	timestamp: number,
	n: Node,
	p: Node
}

-- Services
local HS = game:GetService("HttpService")
local CS = game:GetService("CollectionService")

-- LinkedList
local root: Node -- reverse linkedlist inside of our hashmaps (first capture)
local head: Node -- like the most recent capture
local current: Node -- our current node

-- Magic numbers
local DESTROY_CODE = -2 -- if #cframe == 1 and [1] is this code then we know this is the end of the line and we handle it accordingly
local TAGLINE_BYTE_LIMIT = 34 -- save 2 bytes for the tagline length
local STORAGE_LIMIT = 10000000 -- 10 MB
-- 		^ maximum size of 1 frame is 100 bytes (100,000 entries max before shifting)

-- Storage
local tracked: { [string]: { [number]: number } } = {} -- [UID]: {[timestamp]: cursor location}
local storage = buffer.create(STORAGE_LIMIT)
local available = #storage
local refresh = 0.8 -- The percent to keep when shifting space --> must be on [0, 1)

setmetatable(tracked, {
	__index = function(t, k)
		local newItem = {}
		rawset(t, k, newItem)
		return newItem
	end,
})

-- Helper fxns
----> STRINGS
------> (truncate tagline for storage)
local function taglineEncode(s: string): string
	return s:sub(1, math.min(#s, TAGLINE_BYTE_LIMIT - 3)) .. "..."
end

----> LINKEDLIST
-------> (make a node)
-------> (insert a node)
local function insertNode(pNode: Node)
	
end

local function newNode(id: string, t: number?, pNode: Node?, nNode: Node?): Node
	local nn = {
		UID = id,
		timestamp = t or os.time(),
		p = pNode or head,
		n = nNode or nil
	}
	return nn
end

----> FRAME DATA
------> (token to frame)
------> (frame to token)
local function getFrameData(token: buffer) end

local function tokenizeFrameData(offset: number, data: FrameData): number
	local tl = taglineEncode(data.tagline)
	local l = tl:len()
	local b = buffer.create(64 + 16 + l * 8)

	if available - #b < 0 then
		local oldstorage = storage
		storage = buffer.create(STORAGE_LIMIT)
		buffer.copy(storage, 0, oldstorage, oldstorage * (1 - refresh), oldstorage.len() * refresh)
		-- edit 'tracked' container
		-- do it by figuring out the timestamp that we're cutting off at
		-- (take the framedata of the first frame)

		root = 
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

	-- Get us to 100 bytes
	offset += TAGLINE_BYTE_LIMIT + 2

	available -= offset

	return offset
end

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
