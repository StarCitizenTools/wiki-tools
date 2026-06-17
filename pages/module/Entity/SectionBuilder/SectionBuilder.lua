require('strict')

--- @module Entity/SectionBuilder
--- Shared constructor for the section tables that every Entity getSections()
--- returns. Centralises the boilerplate nearly all of them repeat by hand:
--- nil/''-collapsing item rows, dropping empty sections, and wrapping the
--- result. A getSections becomes:
---
---   local sectionBuilder = require('Module:Entity/SectionBuilder')
---   local items = {}
---   sectionBuilder.push(items, 'Health', durability.health and format.formatNum(durability.health))
---   sectionBuilder.push(items, 'Resistance', formatResistance(durability.resistance))
---   return sectionBuilder.build(sectionBuilder.section({
---       key = 'component', label = 'Component', collapsible = true, collapsed = true, items = items,
---   }))
---
--- A section carries key/label plus exactly one payload:
---   items    — list of { label, content[, class] } rows (the common case)
---   sections — nested { label, content } sub-sections (tabbed groups, e.g. Dimensions)
---   content  — a single pre-rendered blob carried on the section itself

local p = {}

--- Append a { label = label, content = content } row to `items`, but only when
--- `content` is present (non-nil and not ''). This is the nil-collapse every
--- getSections does by hand. Returns `items` for chaining.
--- @param items EntityItemData[]  the row accumulator
--- @param label string
--- @param content any
--- @return EntityItemData[] items
function p.push(items, label, content)
	if content ~= nil and content ~= '' then
		items[#items + 1] = { label = label, content = content }
	end
	return items
end

--- Build one section from a config, or return nil when it carries no payload
--- (no rows, no sub-sections, no content) — so build() drops it, matching the
--- `if #items == 0 then return {} end` guard the sites write by hand. Unset
--- fields stay nil (absent), so the output equals the hand-built table.
--- @param cfg EntitySectionEntry  the producer-side section (key + label, plus one payload of items / sections / content and optional collapsible/collapsed/columns/class)
--- @return EntitySectionEntry|nil  nil when the section carries no payload
function p.section(cfg)
	local hasItems = type(cfg.items) == 'table' and cfg.items[1] ~= nil
	local hasSections = type(cfg.sections) == 'table' and cfg.sections[1] ~= nil
	local hasContent = cfg.content ~= nil and cfg.content ~= ''
	if not (hasItems or hasSections or hasContent) then
		return nil
	end
	return {
		key = cfg.key,
		label = cfg.label,
		items = cfg.items,
		sections = cfg.sections,
		content = cfg.content,
		collapsible = cfg.collapsible,
		collapsed = cfg.collapsed,
		class = cfg.class,
		columns = cfg.columns,
	}
end

--- Collect the non-nil sections into the list getSections returns. Pass each
--- section (or nil) as a separate argument — varargs so an interspersed nil
--- (from a dropped section) doesn't truncate the list the way an array literal
--- would. An all-nil call yields {} (the "nothing to show" return).
--- @param ... EntitySectionEntry|nil
--- @return EntitySectionEntry[]
function p.build(...)
	local out = {}
	local n = select('#', ...)
	for i = 1, n do
		local s = select(i, ...)
		if s ~= nil then
			out[#out + 1] = s
		end
	end
	return out
end

return p
