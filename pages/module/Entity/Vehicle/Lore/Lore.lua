require('strict')

--- @module Entity/Vehicle/Lore
--- Vehicle Lore sub-builder: in-lore dates (release / retirement), collapsed.

local sectionBuilder = require('Module:Entity/SectionBuilder')

local p = {}

--- @param apiData table
--- @param args table
--- @param ed table  Editorial.view
--- @return table|nil
function p.build(apiData, args, ed)
	local lore = {}
	sectionBuilder.push(lore, 'Released', ed:value('release_date'))
	sectionBuilder.push(lore, 'Retired', ed:value('retirement_date'))
	return lore[1]
			and sectionBuilder.section({
				key = 'lore',
				label = 'Lore',
				items = lore,
				collapsible = true,
				collapsed = true,
			})
		or nil
end

return p
