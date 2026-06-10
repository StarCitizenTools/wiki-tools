require('strict')

--- @module Entity/Facet/Dimensions
--- Dimension facet. Data-driven: matches any item carrying drawable dimension
--- data (`apiData.dimension.dimensions` and/or `.cargo_dimension`). Renders the
--- Module:Dimensions isometric diagram as an infobox section with up to two
--- tabs: Cargo (the packed footprint, scaled against a 1 SCU box, volume in the
--- footer) and Physical (the actual size, scaled against the human/banana
--- reference, mass in the footer). Cargo leads because it has gameplay
--- implication. The section hides entirely when an item has neither box.
---
--- Reads the non-deprecated `dimensions` field, never `true_dimension`.

local dimensions = require('Module:Dimensions')

local p = {}

--- True when t is a {length, width, height} table whose three values are all
--- positive numbers (a drawable box). Nil-safe.
---
--- @param t table|nil
--- @return boolean
local function hasBox(t)
	if type(t) ~= 'table' then
		return false
	end
	local l, w, h = tonumber(t.length), tonumber(t.width), tonumber(t.height)
	return l ~= nil and w ~= nil and h ~= nil and l > 0 and w > 0 and h > 0
end

--- Data-driven match: at least one drawable box. Never reads kind identity.
--- Returns a strict boolean.
---
--- @param apiData table|nil
--- @return boolean
function p.matches(apiData)
	local dim = apiData and apiData.dimension
	return dim ~= nil and (hasBox(dim.dimensions) or hasBox(dim.cargo_dimension))
end

--- Cargo diagram: cargo_dimension scaled against a 1 SCU box, cargo volume in
--- the footer. Nil when there is no cargo box.
---
--- @param dim table apiData.dimension
--- @return string|nil
local function cargoBox(dim)
	if not hasBox(dim.cargo_dimension) then
		return nil
	end
	local box = dim.cargo_dimension
	return dimensions._main({
		length = box.length,
		width = box.width,
		height = box.height,
		referenceType = 'scuBox',
		volume = dim.volume_converted,
		volumeUnit = dim.volume_converted_unit or 'SCU',
	})
end

--- Physical diagram: dimensions (the non-deprecated successor to
--- true_dimension) scaled against the auto human/banana reference, mass in the
--- footer. Nil when there is no physical box.
---
--- @param dim table apiData.dimension
--- @param mass number|nil apiData.mass in kg
--- @return string|nil
local function physicalBox(dim, mass)
	if not hasBox(dim.dimensions) then
		return nil
	end
	local box = dim.dimensions
	return dimensions._main({
		length = box.length,
		width = box.width,
		height = box.height,
		referenceType = 'auto',
		mass = mass,
	})
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local dim = apiData and apiData.dimension
	if type(dim) ~= 'table' then
		return {}
	end

	local cargo = cargoBox(dim)
	local physical = physicalBox(dim, tonumber(apiData.mass))

	if cargo and physical then
		return {
			{
				key = 'dimensions',
				label = 'Dimensions',
				sections = {
					{ label = 'Cargo', content = cargo },
					{ label = 'Physical', content = physical },
				},
			},
		}
	end

	if cargo then
		return { { key = 'dimensions', label = 'Cargo dimensions', content = cargo } }
	end

	if physical then
		return { { key = 'dimensions', label = 'Dimensions', content = physical } }
	end

	return {}
end

--- Exposed for testcases only; not a public interface.
p._internal = {
	hasBox = hasBox,
}

return p
