require('strict')

--- @module Entity/Vehicle/Development
--- Vehicle Development sub-builder: real-world dates (concept announced / concept
--- sale), collapsed.

local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @param apiData table
--- @param args table
--- @param ed table  Editorial.view
--- @return table|nil
function p.build(apiData, args, ed)
	local development = {}
	sectionBuilder.push(development, 'Announced', ed:value('concept_announced'))
	sectionBuilder.push(development, 'Concept sale', ed:value('concept_sale'))
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

return p
