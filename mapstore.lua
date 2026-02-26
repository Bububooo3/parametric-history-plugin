--------------------------------------------------------------------------------
------[ VARIABLES ]-------------------------------------------------------------
--------------------------------------------------------------------------------
local MS = {}
--------------------------------------------------------------------------------
-- Services
local CS = game:GetService("CollectionService")

--------------------------------------------------------------------------------
-- Configuration
local REFRESH = 0.6 -- The percent to keep when shifting space --> must be on [0, 1)
local DESTROY_CODE = -2 -- if #cframe == 1 and [1] is this code then we know this is the end of the line and we handle it accordingly
local TAGLINE_BYTE_LIMIT = 34 -- save 2 bytes for the tagline length
local STORAGE_LIMIT = 10000000 -- ~10 MB
-- 		^ maximum size of 1 frame is 100 bytes (100,000 entries max before shifting)

--------------------------------------------------------------------------------
-- Dependencies
local Types = require("types")

-- HashMap
local tracked: {[string]: { [number]: number } } = {} -- [UID]: {[timestamp]: cursor location}
local storage = buffer.create(STORAGE_LIMIT)
local available = #storage

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

local function shiftDB() ----> (shift for new space)
	local oldstorage = storage
	storage = buffer.create(STORAGE_LIMIT)
	buffer.copy(storage, 0, oldstorage, oldstorage * (1 - REFRESH), oldstorage.len() * REFRESH)
	-- TODO
	-- edit 'tracked' container
	-- do it by figuring out the timestamp that we're cutting off at
	-- (take the framedata of the first frame)
end

----> Gets frame data from token
local function getFrameData(token: buffer) end

----> Generates token from frame data and puts it in the storage buffer
local function tokenizeFrameData(offset: number, data: Types.FrameData): number
	local tl = taglineEncode(data.tagline)
	local l = tl:len()
	local b = buffer.create(64 + 16 + l * 8)

	if available - #b < 0 then
		shiftDB()
	end

	-- CFrame components [48]
	for _, n in ipairs(data.cframe) do
		buffer.writef32(b, offset, n)
		offset += 4
		task.wait()
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
			tokenizeFrameData(#storage - available, {
				cframe = { DESTROY_CODE },
				scale = Vector3.zero,
				cancollide = false,
				anchored = false,
				color3 = 0,
				tagline = description or taglineEncode(`Removed <{UID}>`),
			})
		)
	else
		-- if we're atp, then this thing never even existed
		tracked[UID] = nil
		warn(taglineEncode(`Not found: <{UID}>`))
	end
	return
end
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
------[ PUBLIC METHODS ]--------------------------------------------------------
--------------------------------------------------------------------------------
function MS.capture(UID: string, description: string) --> (store a snapshot in the buffer)
	-- Handle the real deal background stuff up in here
	local part: BasePart = CS:GetTagged(UID)[1]
	local ref = tracked[UID] -- so what we wanna do is have each UID in tracked contain a framedata history as a table of buffers locations w/ unique time as key

	--------------------------------------
	if (part == nil) or part.Parent ~= workspace then -- please pardon this interruption
		handleNonexisting(UID, description)
	end
	--------------------------------------

	description = taglineEncode((not description or description == "") and `Edited {part.Name}` or description)

	rawset(
		ref,
		os.time(),
		tokenizeFrameData(#storage - available, {
			cframe = part.CFrame:GetComponents(),
			scale = part.Size,
			cancollide = part.CanCollide,
			anchored = part.Anchored,
			color3 = part.Color,
			tagline = description,
		})
	)
end

function MS.getUID(part: BasePart) --> Get UID from BasePart
	task.desynchronize()
	for _, s: string in part:GetTags() do
		if #s == 36 and rawget(tracked, s) then
			return s
		end
	end
	task.synchronize()

	return nil
end
--------------------------------------------------------------------------------
return MS
