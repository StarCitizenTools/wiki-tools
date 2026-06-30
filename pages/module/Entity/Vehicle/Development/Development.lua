require('strict')

--- @module Entity/Vehicle/Development
--- Vehicle Development sub-builder: real-world milestones (concept announced /
--- concept sale / flight-ready patch) plus a free-text production note. Collapsed.

local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- Render the flight-ready patch page as a link with a friendly label:
--- "Update:Star Citizen Alpha 4.8.0" -> "[[Update:Star Citizen Alpha 4.8.0|Alpha 4.8.0]]".
--- @param page string|nil  canonical Update page (from the patchPage transform)
--- @return string|nil
local function patchRow(page)
	if not page or page == '' then
		return nil
	end
	local label = page:gsub('^Update:', ''):gsub('^Star Citizen ', '')
	return string.format('[[%s|%s]]', page, label)
end

--- @param apiData table
--- @param args table
--- @param ed table  Editorial.view
--- @return table|nil
function p.build(apiData, args, ed)
	local development = {}
	sectionBuilder.push(development, 'Announced', ed:value('concept_announced'))
	sectionBuilder.push(development, 'Concept sale', ed:value('concept_sale'))
	sectionBuilder.push(development, 'Flight ready in', patchRow(ed:value('flight_ready_version')))
	sectionBuilder.push(development, 'Note', ed:value('production_state_note'))
	return development[1]
			and sectionBuilder.section({
				key = 'development',
				label = 'Development',
				items = development,
				collapsible = true,
				collapsed = true,
			})
		or nil
end

-- Test-only exports. Not part of the public API.
p._internal = {
	patchRow = patchRow,
}

return p
