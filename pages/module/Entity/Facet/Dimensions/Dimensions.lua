require('strict')

--- @module Entity/Facet/Dimensions
--- Dimension facet. Data-driven: matches any item carrying drawable dimension
--- data (`apiData.dimension.dimensions` and/or `.cargo_dimension`). Renders the
--- Module:Dimensions isometric diagram as an infobox section with up to two
--- tabs: Cargo (the packed footprint, with its volume, marked as the stowed
--- size) and Physical (the actual size, with its mass). Cargo leads because it
--- has gameplay implication. The section hides entirely when an item has
--- neither box.
---
--- This is a thin Star Citizen adapter over the domain-agnostic
--- Module:Dimensions: it owns the metric formatting (Volume in SCU, Mass in kg).
--- Reads the non-deprecated `dimensions` field, never `true_dimension`.

local dimensions = require('Module:Dimensions')

local lang = mw.getContentLanguage()

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

--- Cargo diagram: the packed cargo_dimension box, marked stowed, with its
--- volume. Nil when there is no cargo box.
---
--- @param dim table apiData.dimension
--- @return string|nil
local function cargoBox(dim)
	if not hasBox(dim.cargo_dimension) then
		return nil
	end
	local box = dim.cargo_dimension
	local metrics = {}
	local volume = tonumber(dim.volume_converted)
	if volume then
		metrics[1] = {
			label = 'Volume',
			value = lang:formatNum(volume) .. ' ' .. (dim.volume_converted_unit or 'SCU'),
		}
	end
	return dimensions._main({
		length = box.length,
		width = box.width,
		height = box.height,
		stowed = true,
		metrics = metrics,
	})
end

--- Physical diagram: dimensions (the non-deprecated successor to
--- true_dimension) with the mass. Nil when there is no physical box.
---
--- @param dim table apiData.dimension
--- @param mass number|nil apiData.mass in kg
--- @return string|nil
local function physicalBox(dim, mass)
	if not hasBox(dim.dimensions) then
		return nil
	end
	local box = dim.dimensions
	local metrics = {}
	if mass then
		metrics[1] = { label = 'Mass', value = lang:formatNum(mass) .. ' kg' }
	end
	return dimensions._main({
		length = box.length,
		width = box.width,
		height = box.height,
		metrics = metrics,
	})
end

--- @param ctx EntityHookContext
--- @return table[] Ordered list of section entries with key field
function p.getSections(ctx)
	local apiData = ctx.apiData
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
