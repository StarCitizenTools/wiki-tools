-- TODO: Maybe make this more generic so that it can be reused somewhere else?
local NavplateVehicles = {}

local metatable = {}
local methodtable = {}

metatable.__index = methodtable

local navplate = require('Module:Navplate')
local common = require('Module:Common')
local manufacturer = require('Module:Manufacturer'):new()
local i18n = require('Module:i18n'):new()
local TNT = require('Module:Translate'):new()
local BucketQuery = require('Module:BucketQuery')
local lang = mw.getContentLanguage()

--- Wrapper function for Module:i18n.translate
---
--- @param key string The translation key
--- @return string If the key was not found, the key is returned
local function t(key)
	return i18n:translate(key)
end

--- FIXME: This should go to somewhere else, like Module:Common
--- Calls TNT with the given key
---
--- @param key string The translation key
--- @return string If the key was not found in the .tab page, the key is returned
local function translate(key, ...)
	local success, translation = pcall(TNT.format, 'Module:Navplate vehicles/i18n.json', key or '', ...)

	if not success or translation == nil then
		return key
	end

	return translation
end

--- Sorts Store rows by manufacturer then page; grouping re-sorts each group's
--- pages by display name, so this only fixes the order pages with the same
--- manufacturer and no display name are grouped in.
--- @param rows table
--- @return table rows, sorted in place
local function sortRows(rows)
	table.sort(rows, function(a, b)
		local ma, mb = a.manufacturer or '', b.manufacturer or ''
		if ma ~= mb then
			return ma < mb
		end
		return (a.page or '') < (b.page or '')
	end)
	return rows
end

--- Reads Bucket via Module:BucketQuery: page and manufacturer for every page
--- in `category`. A Store failure (or an empty result) returns nil rather than
--- red-erroring the page; `make` turns that into an error hatnote.
--- @return table|nil
function methodtable.getRows(self, category)
	-- Cache multiple calls
	if self.rows ~= nil and self.rows[category] ~= nil then
		return self.rows[category]
	end

	category = category or ''

	local ok, rows = pcall(BucketQuery.query, {
		filters = { 'Category:' .. category },
		columns = {
			{ builtin = 'page_name', as = 'page' },
			{ property = 'Manufacturer', as = 'manufacturer' },
		},
		limit = 500,
	})

	if not ok or rows == nil or rows[1] == nil then
		return nil
	end

	sortRows(rows)

	-- Init self.rows
	if self.rows == nil then
		self.rows = {}
	end

	self.rows[category] = rows

	return self.rows[category]
end

--- Groups data by a given key, and sorts the pages within each group alphabetically.
---
--- @param data table Store rows - Requires a 'page' key on each row
--- @param groupKey string Key on objects to group them under, e.g. manufacturer
--- @param suffix string|table Suffix to remove from page title
--- @return table
function methodtable.group(self, data, groupKey, suffix)
	local grouped = {}

	if type(data) ~= 'table' or type(groupKey) ~= 'string' then
		return grouped
	end

	for _, row in pairs(data) do
		if row[groupKey] ~= nil then
			if type(grouped[row[groupKey]]) ~= 'table' then
				grouped[row[groupKey]] = {}
			end

			local name = common.removeTypeSuffix(row.page, suffix)

			if row.name ~= nil then
				name = row.name
			end

			table.insert(grouped[row[groupKey]], string.format('[[%s|%s]]', row.page, name))
		end
	end

	-- Sort vehicles alphabetically
	for _, pages in pairs(grouped) do
		table.sort(pages, function(a, b)
			local nameA = string.match(a, '%|(.+)]]')
			local nameB = string.match(b, '%|(.+)]]')

			if nameA and nameB then
				return nameA < nameB
			end

			return a < b -- Fallback to sorting by page link
		end)
	end

	--mw.logObject( grouped )

	return grouped
end

--- Outputs the table
---
--- @return string
function methodtable.make(self)
	local args = {
		subtitle = translate('subtitle_navplatevehicles'),
		title = translate('title_navplatevehicles'),
	}

	local sections = {
		t('category_ships'),
		t('category_ground_vehicles'),
	}

	local i = 1
	for _, section in pairs(sections) do
		local data = self:getRows(section)
		if data == nil then
			local hatnote = require('Module:Hatnote')._hatnote
			return hatnote(t('message_error_no_data_text'), { icon = 'WikimediaUI-Error.svg' })
		end
		local grouped = self:group(data, 'manufacturer', sections)

		args['header' .. i] = lang:ucfirst(section)
		i = i + 1
		for mfu, vehicles in common.spairs(grouped) do
			local icon = ''
			local label
			local mfuData = manufacturer:get(mfu)
			if mfuData and mfuData.code then
				icon = string.format('[[File:sc-icon-brand-%s.svg|36px|link=]] ', string.lower(mfuData.code))
				-- TODO: Intergrate label title and subtitle into Module:Navplate
				label = string.format(
					'[[%s|%s<div class="template-navplate__subtitle>%s</div>]]',
					mfu,
					mfuData.name,
					mfuData.code
				)
			else
				label = string.format('[[%s]]', mfu)
			end
			args['label' .. i] = string.format('%s%s', icon, label)
			args['list' .. i] = table.concat(vehicles)
			i = i + 1
		end
	end

	--mw.logObject( args )

	return navplate.navplateTemplate({
		args = args,
	})
end

--- New Instance
---
--- @return table NavplateVehicles
function NavplateVehicles.new(self, frameArgs)
	local instance = {}
	setmetatable(instance, metatable)
	return instance
end

--- "Main" entry point
---
--- @param frame table Invocation frame
--- @return string
function NavplateVehicles.main(frame)
	local instance = NavplateVehicles:new()

	return instance:make()
end

--- @class NavplateVehiclesInternal
--- @field group fun(data: table, groupKey: string, suffix: string|table): table
--- @field sortRows fun(rows: table): table

-- Test-only exports. Not part of the public API.
--- @type NavplateVehiclesInternal
NavplateVehicles._internal = {
	group = function(data, groupKey, suffix)
		return methodtable.group(nil, data, groupKey, suffix)
	end,
	sortRows = sortRows,
}

return NavplateVehicles
