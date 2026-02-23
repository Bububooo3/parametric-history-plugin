--!optimize 2

-- Detect new baseparts
----> workspace:descendent added/removing

-- Detect changes in basepart properties
----> Predefined fxn connected to propertyChanged signal

-- Store data as "keyframes"
----> Long buffer for each instance
----> Parsing fxn

type FrameData = {
	cframe: { number },
	scale: Vector3,
	collide: boolean,
	anchored: boolean,
	color3: Color3,
}

-- Services
local HS = game:GetService("HttpService")
local CS = game:GetService("CollectionService")

-- Storage
local tracked: { [string]: { buffer } } = {}

setmetatable(tracked, {
	__index = function(t, k)
		rawset(t, k, {})
	end,
})

-- Helper fxns
local function getFrameData(token: buffer) end

local function tokenizeFrameData(data: FrameData) end

local function capture(UID: string)
	local part: BasePart = CS:GetTagged(UID)[1]
	local ref = tracked[UID] -- so what we wanna do is have each UID in tracked contain a framedata history as a table of buffers

	rawset(
		ref,
		os.time(),
		tokenizeFrameData({
			cframe = part.CFrame:GetComponents(),
			scale = part.Size,
			collide = part.CanCollide,
			anchored = part.Anchored,
			color3 = part.Color,
		})
	)
end

-- Connections, detections...
workspace.DescendantAdded:Connect(function(i: Instance)
	if i:IsA("BasePart") then
		CS:AddTag(i, HS:GenerateGUID(false))
	end
end)
