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
local head: Types.Node -- like the most recent capture
local root: Types.Node -- reverse linkedlist inside of our hashmaps (first capture)
local current: Types.Node -- our current node

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-------[ PUBLIC METHODS ]-------------------------------------------------------
--------------------------------------------------------------------------------
function LS.refreshCurrent() ----> (refresh current var's val)
	if current then
		return
	end

	current = head or root
	if current == nil then
		warn("LinkedList does not exist, so current was not assigned a value")
		return
	end
end

function LS.refreshHeadRoot() ----> (update head and root)
	LS.refreshCurrent()

	-- Handle the root
	root = root or current
	while root.p do
		root = root.p
	end

	-- Handle the head
	head = head or current
	while head.n do
		head = head.n
	end
end

function LS.getHead()
	return head
end

function LS.getRoot()
	return root
end

function LS.getCurrent()
	return current
end

function LS.insertNode(iNode: Types.Node, pNode: Types.Node?, nNode: Types.Node?) ----> (insert a node)
	if pNode and nNode then
		iNode.n = nNode
		iNode.p = pNode
		pNode.n = iNode
		nNode.p = iNode
	elseif nNode then
		iNode.n = nNode
		iNode.p = nil ----> Dangerous bc it creates a 1-way road for iteration
		nNode.p = iNode
	elseif pNode then
		iNode.n = nil ----> Also dangerous
		iNode.p = pNode
		pNode.n = iNode
	else
		iNode.n = nil
		iNode.p = nil
	end

	LS.refreshHeadRoot()

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
		LS.refreshHeadRoot()
	end
	if current == nil then
		LS.refreshCurrent()
	end

	current = head

	-- Find it
	repeat
		current = current.n and current.n or root :: Types.Node
	until current.UID == target or current.timestamp == target

	return current
end

function LS.removeNode(rNode: Types.Node): { nx: Types.Node?, pv: Types.Node? }
	local p = rNode.p
	local n = rNode.n

	if p then
		p.n = n
	end

	if n then
		n.p = p
	end
	--

	table.clear(rNode) ----> Should be gc'd bc no references

	if n == nil or p == nil then
		LS.refreshHeadRoot()
	end

	return { nx = n, pv = p }
end

function LS.clear()
	current = head

	while current and current ~= root do
		local p = current.p
		table.clear(current)
		current = p or root
	end

	LS.refreshHeadRoot()
end

function LS.sortByTimestamps() ----> Pretty self-explanatory
	print("Sorting timeline")
	local sortArray = {}
	current = root

	while current.n and current ~= head do
		table.insert(sortArray, { current.timestamp, current.UID } :: { any })
		current = current.n
	end
	table.insert(sortArray, { head.timestamp, head.UID } :: { any })

	table.sort(sortArray)

	LS.clear()

	for _, info in pairs(sortArray) do
		LS.insertNode({
			UID = info[2],
			timestamp = info[1],
		}, current)
	end

	LS.refreshHeadRoot()

	print("Timeline sort complete")
end
--------------------------------------------------------------------------------
return LS
