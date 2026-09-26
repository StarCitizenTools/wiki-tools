require('strict')

--- @module Entity/LocationNavigation/Gauge
--- The decorative distance gauge beside each Body panel row: the body's disc,
--- a dashed axis, orbit arcs that flatten with distance, moon glyphs and
--- Lagrange diamonds. MediaWiki strips SVG, so an arc is a large bordered
--- circle placed so its lower edge crosses the row, clipped by the row's gauge
--- cell. Every element is computed for both variants: `wide` for the 160 px
--- column, `narrow` for the 56 px strip below 640 px; the stylesheet shows one.

local p = {}

--- Per variant, in px. `line` is the centre of a row's first 36 px line; a
--- narrow row carries its label inside the row, which pushes it down.
p.GEOMETRY = {
	wide = {
		axis = 80,
		disc = 150,
		line = 22,
		step = 36,
		orbitBottom = 22,
		orbit = 240,
		moon = 320,
		moonStep = 80,
		near = 600,
		far = 900,
		nearDx = 44,
		farDx = 44,
		glyph = 16,
		glyphMin = 10,
	},
	narrow = {
		axis = 28,
		disc = 52,
		line = 54,
		step = 36,
		orbitBottom = 22,
		orbit = 90,
		moon = 120,
		moonStep = 30,
		near = 220,
		far = 300,
		nearDx = 14,
		farDx = 16,
		glyph = 13,
		glyphMin = 8,
	},
}

local DIAMOND = 8
local BREAK = 16

local function round(x)
	return math.floor(x + 0.5)
end

local function arc(g, radius, bottom)
	return { class = 'arc', left = g.axis - radius, top = bottom - 2 * radius, width = 2 * radius, height = 2 * radius }
end

--- y of the arc of `radius` (lower edge at `bottom`) at `dx` from the axis.
local function arcY(radius, bottom, dx)
	return bottom - (radius - math.sqrt(radius * radius - dx * dx))
end

local function diamond(x, y)
	return { class = 'diamond', left = round(x - DIAMOND / 2), top = round(y - DIAMOND / 2) }
end

--- @param g table geometry
--- @param row table model row
--- @param disc table { icon, star }
--- @param first boolean
--- @return table[]
local function build(g, row, disc, first)
	local elements = {}
	local axisTop = 0
	if first then
		local half = g.disc / 2
		elements[#elements + 1] = {
			class = 'disc',
			modifier = disc.star and 'star' or (not disc.icon and 'plain' or nil),
			file = disc.icon,
			size = g.disc,
			left = g.axis - half,
			top = -half,
		}
		axisTop = half
	end
	local axis = { class = 'axis', left = g.axis, top = axisTop, bottom = 0 }
	elements[#elements + 1] = axis

	if row.key == 'orbit' then
		elements[#elements + 1] = arc(g, g.orbit, g.orbitBottom)
	elseif row.key == 'moons' then
		local maxKm = 0
		for _, moon in ipairs(row.moons) do
			maxKm = math.max(maxKm, tonumber(moon.km) or 0)
		end
		for i, moon in ipairs(row.moons) do
			local cy = g.line + g.step * (i - 1)
			elements[#elements + 1] = arc(g, g.moon + g.moonStep * (i - 1), cy)
			local share = maxKm > 0 and (tonumber(moon.km) or 0) / maxKm or 1
			local size = g.glyphMin + round((g.glyph - g.glyphMin) * share)
			elements[#elements + 1] = {
				class = moon.icon and 'glyph' or 'dot',
				file = moon.icon,
				size = size,
				left = round(g.axis - size / 2),
				top = round(cy - size / 2),
			}
		end
	elseif row.key == 'lagrange' then
		local near, far = row.near or {}, row.far or {}
		local present = {}
		for _, item in ipairs(near) do
			present[item.point] = true
		end
		for _, item in ipairs(far) do
			present[item.point] = true
		end
		local nearY = near[1] and g.line or nil
		local farY = far[1] and (nearY and g.line + g.step or g.line) or nil
		if nearY then
			elements[#elements + 1] = arc(g, g.near, nearY)
			for point, dx in pairs({ L1 = -g.nearDx, L2 = g.nearDx }) do
				if present[point] then
					elements[#elements + 1] = diamond(g.axis + dx, arcY(g.near, nearY, math.abs(dx)))
				end
			end
		end
		if farY then
			elements[#elements + 1] = arc(g, g.far, farY)
			for point, dx in pairs({ L3 = -g.farDx, L4 = 0, L5 = g.farDx }) do
				if present[point] then
					elements[#elements + 1] = diamond(g.axis + dx, arcY(g.far, farY, math.abs(dx)))
				end
			end
		end
		if nearY and farY then
			local top = round((nearY + farY) / 2) - BREAK / 2
			elements[#elements + 1] = { class = 'break', left = g.axis - BREAK / 2, top = top, text = '≈' }
			axis.bottom, axis.height = nil, top
		else
			axis.bottom, axis.height = nil, nearY or farY
		end
	end
	return elements
end

--- Diamonds sort top to bottom, then left to right, so the output does not
--- depend on `pairs` order.
local function sortDiamonds(elements)
	table.sort(elements, function(a, b)
		if a.class == 'diamond' and b.class == 'diamond' then
			if a.top ~= b.top then
				return a.top < b.top
			end
			return a.left < b.left
		end
		return false
	end)
end

--- The gauge elements for one panel row, per variant.
--- @param row table model row ({ key, moons?, near?, far? })
--- @param disc table { icon = file|nil, star = boolean|nil }
--- @param first boolean true for the panel's first row, which carries the disc
--- @return { wide: table[], narrow: table[] }
function p.row(row, disc, first)
	local out = {}
	for variant, g in pairs(p.GEOMETRY) do
		local elements = build(g, row, disc or {}, first)
		local diamonds, rest = {}, {}
		for _, element in ipairs(elements) do
			table.insert(element.class == 'diamond' and diamonds or rest, element)
		end
		sortDiamonds(diamonds)
		for _, element in ipairs(diamonds) do
			rest[#rest + 1] = element
		end
		out[variant] = rest
	end
	return out
end

return p
