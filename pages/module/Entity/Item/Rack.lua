require('strict')

--- @module Entity/Item/Rack
--- Missile rack / bomb launcher subtype. A rack is a port container mounted on a
--- vehicle hardpoint to carry ordnance; the individual slots render in the Ports
--- section, and this adds the at-a-glance Capacity ("how many × what size"). The
--- count/size lives in different places per launcher kind: missile racks (type
--- MissileLauncher) use a `missile_rack` block; bomb launchers (type BombLauncher)
--- report `max_bombs` + `max_size` at the top level. Both carry a durability
--- block, so the Component facet renders alongside.

local format = require('Module:Entity/Format')
local item = require('Module:Entity/Item')
local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @type string
p.parent = 'Entity/Item'

--- Resolves the rack's (ordnance count, ordnance size) from whichever shape the
--- API uses for this launcher kind. Returns nil count when neither is present.
---
--- @param apiData table
--- @return number|nil count, number|nil size
local function capacity(apiData)
	local rack = apiData.missile_rack
	if type(rack) == 'table' then
		return tonumber(rack.missile_count), tonumber(rack.missile_size)
	end
	if apiData.max_bombs ~= nil then
		return tonumber(apiData.max_bombs), tonumber(apiData.max_size)
	end
	return nil, nil
end

--- @param apiData table
--- @param args table
--- @return table[] Ordered list of section entries with key field
function p.getSections(apiData, args)
	local count, size = capacity(apiData)
	if count == nil then
		return {}
	end
	local value = format.formatNum(count)
	if size then
		value = value .. ' × S' .. format.formatNum(size)
	end
	local label = apiData.type == 'BombLauncher' and 'Bomb launcher' or 'Missile rack'
	local items = {}
	sectionBuilder.push(items, 'Capacity', value)
	return sectionBuilder.build(sectionBuilder.section({
		key = 'rack',
		label = label,
		items = items,
	}))
end

--- Short description prepends the mount size — "S1 missile rack by Behring" —
--- mirroring the other ordnance descriptors. Size is omitted only when absent.
---
--- @param apiData table
--- @param args table
--- @param typeInfo table
--- @param prefix string|nil
--- @return string
function p.getShortDescription(apiData, args, typeInfo, prefix)
	local typeName = typeInfo.name
	if apiData.size then
		typeName = 'S' .. tostring(apiData.size) .. ' ' .. typeName:lower()
	end
	return item.formatShortDescription({ name = typeName }, apiData, args, prefix)
end

--- @param apiData table
--- @param args table
--- @return table<string, any>
function p.getStructuredData(apiData, args)
	local count, size = capacity(apiData)
	if count == nil then
		return {}
	end
	return {
		capacity_count = count,
		capacity_size = size,
	}
end

return p
