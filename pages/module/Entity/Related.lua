require('strict')

--- @module Entity/Related
--- Renders an entity's related entries as two captioned tables: cosmetic
--- variants (base_item + variant_items) and set components (set_items).
--- Sibling renderer parallel to Module:Entity/Availability — consumes
--- Module:Entity/Data so it shares Apiunto's cache with the Entity
--- infobox and other sibling templates on the same page.
---
--- Items only today (reads apiData.related_items, which only the items
--- endpoint provides). Non-item entities render nothing.
---
--- v1: bare TableLua tables, no card wrapper, no styles, no current-row
--- highlight. UI polish is a follow-up.

local data = require('Module:Entity/Data')
local tableLua = require('Module:TableLua')

local p = {}

--- Renders a row's name cell. The current page (uuid match) becomes
--- plain text so the reader isn't given a self-link. Links use the
--- item name as the wiki page title — the API's `link` field is a
--- JSON URL, not a wiki slug, so it isn't usable here.
---
--- @param row table { uuid, name, ... }
--- @param currentUuid string|nil
--- @return string
local function renderNameCell(row, currentUuid)
	if not row.name then
		return ''
	end
	if currentUuid and row.uuid == currentUuid then
		return row.name
	end
	return '[[' .. row.name .. ']]'
end

--- Maps an API type string (e.g. `Char_Armor_Helmet`) to its display
--- name via Module:Entity/Item/types.json. Falls back to the raw type
--- string when unmapped so new types are still discoverable on-page.
---
--- @param apiType string|nil
--- @return string
local function resolveTypeName(apiType)
	if not apiType or apiType == '' then
		return ''
	end
	local types = mw.loadJsonData('Module:Entity/Item/types.json')
	local typeInfo = types[apiType]
	return (typeInfo and typeInfo.name) or apiType
end

--- Builds the rows for the Variants table: base_item prepended, then
--- variant_items in API order. Skips rows with no name (defensive).
--- The base_item row shows '(base)' when variant_name is missing.
---
--- @param relatedItems table
--- @param currentUuid string|nil
--- @return any[][]
local function buildVariantRows(relatedItems, currentUuid)
	local rows = {}
	local base = relatedItems.base_item
	if type(base) == 'table' and base.name then
		local variant = base.variant_name
		if not variant or variant == '' then
			variant = '(base)'
		end
		table.insert(rows, { renderNameCell(base, currentUuid), variant })
	end
	if type(relatedItems.variant_items) == 'table' then
		for _, item in ipairs(relatedItems.variant_items) do
			if item.name then
				table.insert(rows, { renderNameCell(item, currentUuid), item.variant_name or '' })
			end
		end
	end
	return rows
end

--- Builds the rows for the Set components table from set_items in API
--- order. Skips rows with no name.
---
--- @param relatedItems table
--- @param currentUuid string|nil
--- @return any[][]
local function buildSetRows(relatedItems, currentUuid)
	local rows = {}
	if type(relatedItems.set_items) == 'table' then
		for _, item in ipairs(relatedItems.set_items) do
			if item.name then
				table.insert(rows, { renderNameCell(item, currentUuid), resolveTypeName(item.type) })
			end
		end
	end
	return rows
end

--- @param rows any[][]
--- @return string
local function renderVariantsTable(rows)
	return tableLua.render({
		caption = 'Variants',
		columns = {
			{ id = 'name', label = 'Name', textAlign = 'start' },
			{ id = 'variant', label = 'Variant', textAlign = 'start' },
		},
		data = rows,
	})
end

--- @param rows any[][]
--- @return string
local function renderSetTable(rows)
	return tableLua.render({
		caption = 'Set components',
		columns = {
			{ id = 'name', label = 'Name', textAlign = 'start' },
			{ id = 'type', label = 'Type', textAlign = 'start' },
		},
		data = rows,
	})
end

--- Main entry point. Renders up to two tables (variants, set components)
--- depending on which buckets are populated. Returns an empty string when
--- the API has no related_items, both buckets are empty, or the upstream
--- fetch failed.
---
--- @param frame table
--- @return string
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	if result.hasApiError then
		return ''
	end

	local relatedItems = result.apiData.related_items
	if type(relatedItems) ~= 'table' then
		return ''
	end

	local variantRows = buildVariantRows(relatedItems, args.uuid)
	local setRows = buildSetRows(relatedItems, args.uuid)

	local parts = {}
	if #setRows > 0 then
		table.insert(parts, renderSetTable(setRows))
	end
	if #variantRows > 0 then
		table.insert(parts, renderVariantsTable(variantRows))
	end
	return table.concat(parts)
end

return p
