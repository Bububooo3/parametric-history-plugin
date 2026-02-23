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

local function capture(UID: string, description: string)
	local part: BasePart = CS:GetTagged(UID)[1]
	local ref = tracked[UID] -- so what we wanna do is have each UID in tracked contain a framedata history as a table of buffers

	description = (not description or description == "") and "<Empty>" or description

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
end

-- Connections, detections...
workspace.DescendantAdded:Connect(function(i: Instance)
	if i:IsA("BasePart") then
		local UID = HS:GenerateGUID(false)
		CS:AddTag(i, UID)
		capture(UID, `Added {i.Name} to Workspace`) -- the first one (initialization)
	end
end)
