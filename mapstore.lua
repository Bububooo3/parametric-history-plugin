--!strict
--!optimize 2
--------------------------------------------------------------------------------
------[ VARIABLES ]-------------------------------------------------------------
--------------------------------------------------------------------------------
local MS = {}
--------------------------------------------------------------------------------
-- Services
local CS = game:GetService("CollectionService")

--------------------------------------------------------------------------------
-- Configuration
local REFRESH_SPACE = 0.6 -- The percent to keep when shifting space --> must be on [0, 1)
local DESTROY_CODE = -2 -- if #cframe == 1 and [1] is this code then we know this is the end of the line and we handle it accordingly
local TAGLINE_BYTE_LIMIT = 34 -- save 2 bytes for the tagline length
local STORAGE_LIMIT = 10000000 -- ~10 MB
-- 		^ maximum size of 1 frame is 100 bytes (100,000 entries max before shifting)

--------------------------------------------------------------------------------
-- Dependencies
local Types = require("types")
local LS = require("linkedstore")

-- HashMap
local tracked: Types.MapStore = {}
local storage = buffer.create(STORAGE_LIMIT)
local available = buffer.len(storage)

--------------------------------------------------------------------------------
-- Metamethod magic
setmetatable(tracked, {
	__index = function(t, k)
		local newItem = {}
		rawset(t, k, newItem)
		return newItem
	end,
})

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
------[ PRIVATE METHODS ]-------------------------------------------------------
--------------------------------------------------------------------------------
local function taglineEncode(s: string): string --> (truncate tagline for storage)
	return s:sub(1, math.min(#s, TAGLINE_BYTE_LIMIT - 3)) .. "..."
end

----> Gets frame data from token
local function getFrameData(location: number): Types.FrameData
	if location % 100 ~= 0 then
		warn("Attempted to find a frame at an invalid location")
	end

	-- now synthesize the frame data from the token
	local offset = location
	local data: { [string]: any } = {
		cframe = {},
		scale = nil,
		cancollide = nil,
		anchored = nil,
		color3 = nil,
		tagline = nil,
	}

	-- CFrame
	for i = 1, 12 do
		rawset(data.cframe, i, buffer.readf32(storage, offset))
		offset += 4
		task.wait()
	end

	-- Scale
	rawset(
		data,
		"scale",
		Vector3.new(
			buffer.readf32(storage, offset),
			buffer.readf32(storage, offset + 4),
			buffer.readf32(storage, offset + 8)
		)
	)
	offset += 12

	-- CanCollide & Anchored
	local ca = buffer.readu8(storage, offset)
	rawset(data, "anchored", (bit32.band(ca, 1) ~= 0))
	rawset(data, "cancollide", (bit32.band(ca, 2) ~= 0))
	offset += 1

	-- Color
	rawset(
		data,
		"color3",
		Color3.fromRGB(
			buffer.readu8(storage, offset),
			buffer.readu8(storage, offset + 1),
			buffer.readu8(storage, offset + 2)
		)
	)
	offset += 3

	-- Tagline
	rawset(data, "tagline", buffer.readstring(storage, offset + 2, buffer.readu16(storage, offset)))
	offset += TAGLINE_BYTE_LIMIT + 2

	return data
end

local function getUIDfromCursor(pos: number): string | nil
	for UID: string, data in pairs(tracked) do
		for timestamp: number, offset: number in pairs(data) do
			if offset == pos then
				return UID
			end
			task.wait()
		end
		task.wait()
	end

	return nil
end

local function shiftDB() ----> (shift for new space)
	local oldstorage = storage
	storage = buffer.create(STORAGE_LIMIT)

	local used = math.min(buffer.len(oldstorage) - available, STORAGE_LIMIT) ----> For safety
	local preserved = math.floor(used * REFRESH_SPACE) ----> amount to take to the new one
	local offset = used - preserved

	if preserved > 0 then
		buffer.copy(storage, 0, oldstorage, offset, preserved)
	end

	available = STORAGE_LIMIT - preserved

	local c = LS.getNode(getUIDfromCursor(0))
	local t = c.timestamp

	-- LinkedStore
	while task.wait() do
		local crumbs = LS.removeNode(c) ----> prev & next of our fallen soldier

		if crumbs == nil or crumbs.pv == nil then
			break
		end

		c = crumbs.pv

		if c.timestamp < t then
			warn(`Issue: Timestamp conflict while shifting database ({c.timestamp} < {t})`)
		end
	end

	-- MapStore
	for UID: string, _ in pairs(tracked) do
		for timestamp, v in pairs(tracked[UID]) do
			if timestamp < t then
				tracked[UID][timestamp] = nil
			end
		end
	end
end

----> Generates token from frame data and puts it in the storage buffer
local function tokenizeFrameData(offset: number, data: Types.FrameData): number
	local tl = taglineEncode(data.tagline)
	local l = tl:len()

	if available - 100 < 0 then
		shiftDB()
	end

	-- CFrame components [48]
	for _, n in ipairs(data.cframe) do
		buffer.writef32(storage, offset, n)
		offset += 4
		task.wait()
	end

	-- Scale [12]
	local s = data.scale
	buffer.writef32(storage, offset, s.X)
	buffer.writef32(storage, offset + 4, s.Y)
	buffer.writef32(storage, offset + 8, s.Z)
	offset += 12

	-- CanCollide/Anchored [1]
	local ca = 0 ----> just learned this. super clever!
	if data.cancollide then
		ca += 1
	end
	if data.anchored then
		ca += 2
	end
	buffer.writeu8(storage, offset, ca)
	offset += 1

	-- Color3 [3]
	local c = data.color3
	buffer.writeu8(storage, offset, (c.R * 255) // 1)
	buffer.writeu8(storage, offset + 1, (c.G * 255) // 1)
	buffer.writeu8(storage, offset + 2, (c.B * 255) // 1)
	offset += 3

	-- Tagline [idk + 2]
	buffer.writeu16(storage, offset, l)
	buffer.writestring(storage, offset + 2, tl)

	-- Get us to 100 bytes added
	offset += TAGLINE_BYTE_LIMIT + 2

	available -= 100

	return offset -- new cursor location
end

local function handleNonexisting(UID, description)
	local ref = tracked[UID]
	if #ref > 0 then -- the part was destroyed
		rawset(
			ref,
			os.time(),
			tokenizeFrameData(buffer.len(storage) - available, {
				cframe = { DESTROY_CODE },
				scale = Vector3.zero,
				cancollide = false,
				anchored = false,
				color3 = Color3.new(),
				tagline = description or taglineEncode(`Removed <{UID}>`),
			})
		)
	else
		-- if we're atp, then this thing never even existed at all
		tracked[UID] = nil
		warn(`Not found: <{UID}>`)
	end
	return
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
------[ PUBLIC METHODS ]--------------------------------------------------------
--------------------------------------------------------------------------------
function MS.capture(UID: string, description: string) --> (store a snapshot in the buffer)
	-- Handle the real deal background stuff up in here
	local ps: { Instance } = CS:GetTagged(UID)
	local ref = tracked[UID] -- so what we wanna do is have each UID in tracked contain a framedata history as a table of buffers locations w/ unique time as key

	if #ps == 0 or not ps[1]:IsA("BasePart") then
		warn(`Capture failed: <{UID}>`)
		return
	end

	if ps[1].Parent ~= workspace then
		handleNonexisting(UID, description)
	end

	local part = ps[1] :: BasePart

	if description == nil or description == "" then
		description = `Edited {part.Name}`
	end

	description = taglineEncode(description)

	rawset(
		ref,
		os.time(),
		tokenizeFrameData(buffer.len(storage) - available, {
			cframe = table.pack(part.CFrame:GetComponents()),
			scale = part.Size,
			cancollide = part.CanCollide,
			anchored = part.Anchored,
			color3 = part.Color,
			tagline = description,
		})
	)
end

function MS.getUID(part: BasePart): string | nil --> Get UID from BasePart
	task.desynchronize()
	for _, s: string in part:GetTags() do
		if #s == 36 and rawget(tracked :: any, s) then
			return s
		end
	end

	return nil
end
--------------------------------------------------------------------------------
return MS
