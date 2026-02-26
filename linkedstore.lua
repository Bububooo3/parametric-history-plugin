--------------------------------------------------------------------------------
------[ VARIABLES ]-------------------------------------------------------------
--------------------------------------------------------------------------------
local LS = {}
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
	else
		iNode.p = nil
		iNode.n = nNode
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

--------------------------------------------------------------------------------
return LS
