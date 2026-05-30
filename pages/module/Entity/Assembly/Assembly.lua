require('strict')

--- @module Entity/Assembly
--- Composition primitives that assemble an entity from its component chain and
--- facets: walk the p.parent chain, and merge the ordered section lists / flat
--- structured-data tables each component contributes. All pure.

local p = {}

--- Merges a list of ordered section lists into a single ordered list of sections.
--- For matching keys, items are appended. First definition's metadata (label, collapsible, etc.) wins.
--- Display order is determined by the order entries appear across the input lists.
---
--- Each entry in the input lists is a table with a 'key' field and section data fields.
--- Example: { key = 'general', label = 'General', items = { ... } }
---
--- @param sectionsList table[][] List of ordered section lists from each module in the chain
--- @return table[] Ordered list of merged sections
function p.mergeSections(sectionsList)
	local order = {}
	local seen = {}
	local merged = {}

	for _, sections in ipairs(sectionsList) do
		for _, section in ipairs(sections) do
			local key = section.key

			if not seen[key] then
				seen[key] = true
				table.insert(order, key)
				merged[key] = {
					label = section.label,
					collapsible = section.collapsible,
					collapsed = section.collapsed,
					columns = section.columns,
					class = section.class,
					content = section.content,
					sections = section.sections,
					items = {},
				}
			end

			if section.items then
				for _, item in ipairs(section.items) do
					table.insert(merged[key].items, item)
				end
			end
		end
	end

	local result = {}
	for _, key in ipairs(order) do
		local section = merged[key]
		if #section.items == 0 then
			section.items = nil
		end
		-- Drop sections with nothing to show (e.g. Base's old empty 'general'
		-- scaffold on a kind that uses a different section key) so they don't
		-- render as a stray empty section block.
		if section.items or section.content or section.sections then
			table.insert(result, section)
		end
	end

	return result
end

--- Merges a list of flat key-value tables. Later tables override earlier ones on key collision.
---
--- @param dataList table[] List of structured data tables from each module in the chain
--- @return table Merged key-value table
function p.mergeStructuredData(dataList)
	local result = {}
	for _, data in ipairs(dataList) do
		for k, v in pairs(data) do
			result[k] = v
		end
	end
	return result
end

--- Walks p.parent from a leaf module up to the root, returns the chain in root-first order.
---
--- @param leafModule table The leaf type module (e.g. WeaponGun)
--- @return table[] List of modules from root (Base) to leaf (WeaponGun)
function p.buildChain(leafModule)
	local chain = { leafModule }
	local current = leafModule

	while current.parent do
		current = require('Module:' .. current.parent)
		table.insert(chain, current)
	end

	-- Reverse to get root-first order
	local reversed = {}
	for i = #chain, 1, -1 do
		table.insert(reversed, chain[i])
	end

	return reversed
end

return p
