require('strict')

--- @module Entity/Location/Jurisdiction
--- Which law applies at a location. The locations API sets `jurisdiction`
--- only where a jurisdiction is DEFINED (a planet, a star, a station that
--- overrides its surroundings); everything else falls under the first ancestor
--- in its GAME parent chain. The walk must follow the API parent, never a
--- page's curated |parent=: a Lagrange station's game parent is the star, so
--- HUR-L1 is under UEE law, not Hurston Dynamics'.

local api = require('Module:Entity/Api')

local p = {}

--- Ancestor fetches before giving up. The deepest chain observed across the
--- current records is 3 hops (a station on a moon of a planet).
p.MAX_HOPS = 5

--- The record fetch used by resolve(). A field, not a local, so a suite can
--- replace it.
--- @param uuid string
--- @return table|nil
function p.fetch(uuid)
	-- The kind's own config, so each ancestor fetch shares the Apiunto cache entry
	-- of that ancestor's own page. Required here, not at load: the kind loads this
	-- module through its leaves.
	return api.fetchApi(require('Module:Entity/Location').getApiConfigs()[1], uuid)
end

--- API jurisdiction name → display label and link target. A name absent from
--- this table links "<name>#Jurisdiction". That section exists on some
--- faction pages and not others, so every name gets an explicit row here
--- whenever its resolved page differs from the bare API name or lacks the
--- section, linking the bare page instead. `Green` is the API's own name for
--- the Green Imperial jurisdiction.
--- @type table<string, { label: string, target: string }>
p.JURISDICTIONS = {
	UEE = { label = 'UEE', target = 'United Empire of Earth#Jurisdiction' },
	microTech = { label = 'microTech', target = 'MicroTech (company)#Jurisdiction' },
	ArcCorp = { label = 'ArcCorp', target = 'ArcCorp (company)#Jurisdiction' },
	['Rough & Ready'] = { label = 'Rough & Ready', target = 'Rough and Ready' },
	['Citizens For Prosperity'] = { label = 'Citizens for Prosperity', target = 'Citizens for Prosperity' },
	Headhunters = { label = 'Headhunters', target = 'Headhunters' },
	XenoThreat = { label = 'XenoThreat', target = 'XenoThreat' },
	['Klescher Rehabilitation'] = { label = 'Klescher Rehabilitation', target = 'Klescher Rehabilitation Facilities' },
	['Green Imperial'] = { label = 'Green Imperial', target = 'Jurisdiction - Green Imperial' },
	Green = { label = 'Green Imperial', target = 'Jurisdiction - Green Imperial' },
	Ungoverned = { label = 'Ungoverned', target = 'Jurisdictions' },
}

--- @param record table|nil
--- @return string|nil
local function own(record)
	local name = type(record) == 'table' and type(record.jurisdiction) == 'table' and record.jurisdiction.name or nil
	if type(name) == 'string' and name ~= '' then
		return name
	end
	return nil
end

--- The jurisdiction of `record`: its own, else the first ancestor's. `fetch`
--- turns a parent uuid into that parent's record (nil when it cannot).
--- @param record table|nil
--- @param fetch fun(uuid: string): table|nil
--- @return string|nil
function p.walk(record, fetch)
	local node, hops = record, 0
	while type(node) == 'table' do
		local name = own(node)
		if name then
			return name
		end
		local parent = type(node.parent) == 'table' and node.parent.uuid or nil
		if type(parent) ~= 'string' or parent == '' or hops >= p.MAX_HOPS then
			return nil
		end
		node = fetch(parent)
		hops = hops + 1
	end
	return nil
end

--- walk() over the live API.
--- @param record table|nil
--- @return string|nil
function p.resolve(record)
	return p.walk(record, p.fetch)
end

--- The infobox value: the jurisdiction linked to where its laws are described.
--- @param name string|nil
--- @return string|nil
function p.display(name)
	if type(name) ~= 'string' or name == '' then
		return nil
	end
	local entry = p.JURISDICTIONS[name]
	local label = entry and entry.label or name
	local target = entry and entry.target or (name .. '#Jurisdiction')
	return '[[' .. target .. '|' .. label .. ']]'
end

return p
