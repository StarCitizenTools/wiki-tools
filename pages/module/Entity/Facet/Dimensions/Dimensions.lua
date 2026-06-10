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
--- This is a thin Star Citizen adapter over the domain-agnostic
--- Module:Dimensions: it owns the SC-specific cargo reference (the SCU box) and
--- the metric formatting (Volume in SCU, Mass in kg), and borrows the generic
--- human/banana references from Module:Dimensions/presets. Reads the
--- non-deprecated `dimensions` field, never `true_dimension`.

local dimensions = require('Module:Dimensions')
local presets = require('Module:Dimensions/presets')

local lang = mw.getContentLanguage()

-- Star Citizen cargo containers: external cargo_dimension in metres per SCU,
-- ordered largest first for the auto-pick. Verified against the items API (the
-- Stor*All container line for 1/8 to 8 SCU; official RSI material for 16 to 32).
-- The amber colour trio is shared by every box. SC-specific, so it lives here
-- rather than in the generic Module:Dimensions/presets.
local SCU_BOX_COLOR = { color = '#c8742d', colorLight = '#e0a25c', colorDark = '#8a4e1d' }
local SCU_BOXES = {
	{ scu = 32, length = 10, width = 2.5, height = 2.5 },
	{ scu = 24, length = 7.5, width = 2.5, height = 2.5 },
	{ scu = 16, length = 5, width = 2.5, height = 2.5 },
	{ scu = 8, length = 2.5, width = 2.5, height = 2.5 },
	{ scu = 4, length = 2.5, width = 2.5, height = 1.25 },
	{ scu = 2, length = 2.5, width = 1.25, height = 1.25 },
	{ scu = 1, length = 1.25, width = 1.25, height = 1.25 },
	{ scu = 0.125, length = 0.5, width = 0.5, height = 0.5 },
}

--- Display label for an SCU box size: the sub-SCU box reads as '1/8'.
--- @param scu number
--- @return string
local function scuLabel(scu)
	return scu == 0.125 and '1/8' or tostring(scu)
end

--- Pick the largest SCU box whose longest dimension fits within the cargo's
--- longest dimension, or nil when the cargo is smaller than every box (smaller
--- than the 1/8 box). Sub-box cargo gets no reference: a box would only dwarf
--- it, and the volume footer already conveys the cargo size.
--- @param longest number the cargo's longest dimension in metres
--- @return table|nil one of SCU_BOXES
local function pickScuBox(longest)
	for _, box in ipairs(SCU_BOXES) do
		if math.max(box.length, box.width, box.height) <= longest then
			return box
		end
	end
	return nil
end

--- The cargo reference as a Module:Dimensions reference object, or nil when no
--- SCU box fits (sub-box cargo renders without a reference).
--- @param longest number the cargo's longest dimension in metres
--- @return table|nil reference
local function scuReference(longest)
	local box = pickScuBox(longest)
	if not box then
		return nil
	end
	local boxLongest = math.max(box.length, box.width, box.height)
	return {
		length = box.length,
		width = box.width,
		height = box.height,
		label = scuLabel(box.scu) .. ' SCU box · ' .. lang:formatNum(boxLongest) .. ' m',
		color = SCU_BOX_COLOR.color,
		colorLight = SCU_BOX_COLOR.colorLight,
		colorDark = SCU_BOX_COLOR.colorDark,
	}
end

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
		reference = scuReference(math.max(tonumber(box.length), tonumber(box.width), tonumber(box.height))),
		metrics = metrics,
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
	local metrics = {}
	if mass then
		metrics[1] = { label = 'Mass', value = lang:formatNum(mass) .. ' kg' }
	end
	return dimensions._main({
		length = box.length,
		width = box.width,
		height = box.height,
		reference = presets.resolveAuto(math.max(box.length, box.width, box.height)),
		metrics = metrics,
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
	pickScuBox = pickScuBox,
}

return p
