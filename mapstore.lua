local MS = {}

--------------------------------------------------------------------------------
-- Configuration
local REFRESH = 0.6 -- The percent to keep when shifting space --> must be on [0, 1)
local DESTROY_CODE = -2 -- if #cframe == 1 and [1] is this code then we know this is the end of the line and we handle it accordingly
local TAGLINE_BYTE_LIMIT = 34 -- save 2 bytes for the tagline length
local STORAGE_LIMIT = 10000000 -- ~10 MB
-- 		^ maximum size of 1 frame is 100 bytes (100,000 entries max before shifting)

--------------------------------------------------------------------------------
-- HashMap
local tracked: { [string]: { [number]: number } } = {} -- [UID]: {[timestamp]: cursor location}
local storage = buffer.create(STORAGE_LIMIT)
local available = #storage

-- Dependencies
local Types = require("types")

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

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
------[ PUBLIC METHODS ]--------------------------------------------------------
--------------------------------------------------------------------------------
function MS.getFrameData(token: buffer) end

function MS.tokenizeFrameData(offset: number, data: Types.FrameData): number
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

--------------------------------------------------------------------------------
return MS
