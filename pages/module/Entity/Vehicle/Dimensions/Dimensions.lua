require('strict')

--- @module Entity/Vehicle/Dimensions
--- Vehicle Dimensions sub-builder: thin adapter over Module:Dimensions. Vehicles
--- carry flat dimension.{length,width,height} (the item Dimensions facet reads a
--- nested .dimensions and so does not match vehicles). Editorial-first: a
--- planned/concept vehicle supplies L/W/H/mass via args; an in-game vehicle falls
--- back to the API dimension block.

local dimensions = require('Module:Dimensions')
local dimensionsPresets = require('Module:Dimensions/presets')
local format = require('Module:Entity/Format')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @param apiData table
--- @param args table
--- @param ed table  Editorial.view
--- @return table|nil
function p.build(apiData, args, ed)
	local dim = type(apiData.dimension) == 'table' and apiData.dimension or {}
	local length = tonumber(ed:value('length', dim.length))
	local width = tonumber(ed:value('width', dim.width))
	local height = tonumber(ed:value('height', dim.height))
	if not (length and width and height) then
		return nil
	end
	local metrics = {}
	local mass = tonumber(ed:value('mass', apiData.mass))
	if mass then
		metrics[#metrics + 1] = { label = 'Mass', value = format.formatNum(mass) .. ' kg' }
	end
	local boxHtml = dimensions._main({
		length = length,
		width = width,
		height = height,
		lengthAlt = tonumber(ed:value('retracted_length', nil)),
		widthAlt = tonumber(ed:value('retracted_width', nil)),
		heightAlt = tonumber(ed:value('retracted_height', nil)),
		reference = dimensionsPresets.human,
		metrics = metrics,
	})
	if not boxHtml then
		return nil
	end
	return sectionBuilder.section({ key = 'dimensions', label = 'Dimensions', content = tostring(boxHtml) })
end

return p
