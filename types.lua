--------------------------------------------------------------------------------
------[ TYPES ]-----------------------------------------------------------------
--------------------------------------------------------------------------------
export type FrameData = {
	cframe: { number }, -- 12 * f32 is like 48 bytes
	scale: Vector3, -- 3 * f32 = 12 bytes
	cancollide: boolean, -- (shared 1 byte) u8
	anchored: boolean, -- (shared 1 byte) u8
	color3: Color3, -- 3 * u8 = 3 bytes
	tagline: string, -- maximum 34 bytes (+2 for length)
}

export type Node = {
	UID: string,
	timestamp: number,
	n: Node?,
	p: Node?,
}

export type MapStore = {
	[string]: { ----> UID
		[number]: number, ---> [timestamp]: cursor location
	},
}

--------------------------------------------------------------------------------
return {}
