--!strict
--!optimize 2
--------------------------------------------------------------------------------
------[ VARIABLES ]-------------------------------------------------------------
--------------------------------------------------------------------------------
local LS = {} ----> (MapStore dependency)
--------------------------------------------------------------------------------
-- Dependencies
local Types = require("types")

-- LinkedList
local root: Types.Node -- reverse linkedlist inside of our hashmaps (first capture)
local head: Types.Node -- like the most recent capture
local current: Types.Node -- our current node

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
------[ PRIVATE METHODS ]-------------------------------------------------------
--------------------------------------------------------------------------------
local function refreshCurrent() ----> (refresh current var's val)
	if current then
		return
	end

	if head then
		current = head
	elseif root then
		current = root
	else
		warn("LinkedList does not exist, so current was not assigned a value")
		return
	end
end

local function refreshHeadRoot() ----> (update head and root)
	refreshCurrent()

	-- Handle the head
	while current.n do
		current = current.n
	end
	head = current

	-- Handle the root
	while current.p do
		current = current.p
	end
	root = current
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-------[ PUBLIC METHODS ]-------------------------------------------------------
--------------------------------------------------------------------------------
function LS.insertNode(iNode: Types.Node, pNode: Types.Node?, nNode: Types.Node?) ----> (insert a node)
	if pNode then
		iNode.p = pNode
		iNode.n = pNode.n or nNode
		pNode.n = iNode
	elseif nNode then
		iNode.p = nil
		iNode.n = nNode
	else -- append
		iNode.p = head
		head.n = iNode
		head = iNode
	end

	if nNode then
		nNode.p = iNode
	end

	refreshHeadRoot()

	return iNode
end

function LS.newNode(id: string, t: number?): Types.Node ----> (make a node)
	return {
		UID = id,
		timestamp = t or os.time(),
		p = nil,
		n = nil,
	}
end

function LS.getNode(target: number | string | nil): Types.Node
	-- Checks
	if head == nil then
		refreshHeadRoot()
	end
	if current == nil then
		refreshCurrent()
	end

	current = head

	-- Find it
	repeat
		current = current.n and current.n or root :: Types.Node
	until current.UID == target or current.timestamp == target

	return current
end

function LS.removeNode(rNode: Types.Node): nil | { nx: Types.Node?, pv: Types.Node? }
	local p = rNode.p
	local n = rNode.n

	-- Checks
	if n == nil and p == nil then
		return
	end
	--
	if p ~= nil then
		p.n = n
	end

	if n ~= nil then
		n.p = p
	end
	--

	table.clear(rNode) ----> Should be gc'd bc no references
	refreshHeadRoot()

	return { nx = n, pv = p }
end
--------------------------------------------------------------------------------
return LS
