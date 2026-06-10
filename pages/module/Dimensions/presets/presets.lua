require('strict')

--- Module:Dimensions/presets
--- Common, domain-agnostic scale references for Module:Dimensions, plus an
--- auto-selector. A consumer picks (or auto-resolves) a reference here and
--- passes the resulting object straight to Module:Dimensions as its `reference`.
---
--- Domain-specific references (e.g. a Star Citizen SCU cargo box) do NOT belong
--- here; define those in the consumer that needs them.

local p = {}

--- @type { length: number, width: number, height: number, label: string }
p.human = {
	length = 0.3,
	width = 0.5,
	height = 1.8,
	label = 'Human · 1.8 m',
}

--- Standing upright: the slim footprint keeps it from dominating the ground
--- plane next to small items, and the 0.2 m height reads directly against the
--- object's height. Carries its own yellow colour trio.
--- @type { length: number, width: number, height: number, label: string, color: string, colorLight: string, colorDark: string }
p.banana = {
	length = 0.05,
	width = 0.05,
	height = 0.2,
	label = 'Banana · 0.2 m',
	color = '#d9b73e',
	colorLight = '#ecd06c',
	colorDark = '#8f7722',
}

--- Size ladder for resolveAuto, ordered largest first.
--- @type table[]
local LADDER = { p.human, p.banana }

--- Pick the largest reference whose longest dimension does not exceed the
--- object's longest dimension, so the reference informs without dominating.
--- Objects smaller than every reference get the smallest one: being dwarfed by
--- a banana IS the scale story.
---
--- @param longest number the object's longest dimension in metres
--- @return table reference one of the ladder entries
function p.resolveAuto(longest)
	for _, ref in ipairs(LADDER) do
		if math.max(ref.length, ref.width, ref.height) <= longest then
			return ref
		end
	end
	return LADDER[#LADDER]
end

return p
