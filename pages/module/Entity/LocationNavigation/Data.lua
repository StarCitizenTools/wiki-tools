require('strict')

--- @module Entity/LocationNavigation/Data
--- The page-foot panels' Bucket reads. A sibling invocation cannot see the
--- page's {{Location}} args, so everything comes from stored rows: a page's
--- own row appears only after its first link update, and a Bucket read
--- registers no dependency, so a new place reaches its siblings' panels when
--- their parser cache next expires (or on purge).

local Store = require('Module:Entity/Store')
local systemMapData = require('Module:SystemMap/Data')

local p = {}

--- Parent hops before giving up: a venue in a landing zone on a moon is two.
p.MAX_HOPS = 3

local PLACE_COLUMNS = {
	{ builtin = 'page_name', as = 'page' },
	{ property = 'Classification', as = 'classification' },
	{ property = 'Zone', as = 'zone' },
	{ property = 'Lagrange point', as = 'lagrange' },
	{ property = 'Amenities', as = 'amenities' },
	{ property = 'Image', as = 'image' },
}

--- Place rows whose Parent is `page`. nil when the read fails: a panel then
--- renders without that row rather than red-erroring the page.
--- @param page string
--- @return table[]|nil
function p.children(page)
	local ok, rows = pcall(Store.query, {
		columns = PLACE_COLUMNS,
		-- `{ 'Zone', '+' }` is load-bearing: only place rows carry a Zone value.
		-- A child body or belt shares this same Parent but stores no Zone, so
		-- without this filter it would come back as a place row too.
		filters = { { 'Parent', page }, { 'Zone', '+' } },
		kind = 'Location',
		limit = 500,
	})
	if not ok or type(rows) ~= 'table' then
		return nil
	end
	return rows
end

--- The subject's nearest body (a Module:SystemMap/Data.findBody result), and
--- for a place its own zone and parent. A body page is its own body; a place
--- climbs stored Parent values until one names a body.
--- @param subject string
--- @return { subject: string, body: table|nil, zone: string|nil, parent: string|nil }
function p.context(subject)
	local body = systemMapData.findBody(subject)
	if body then
		return { subject = subject, body = body }
	end
	local zone = Store.pageValue(subject, 'Zone', 'Location')
	local parent = Store.pageValue(subject, 'Parent', 'Location')
	local page, hops = parent, 0
	while type(page) == 'string' and hops < p.MAX_HOPS do
		body = systemMapData.findBody(page)
		if body then
			break
		end
		page = Store.pageValue(page, 'Parent', 'Location')
		hops = hops + 1
	end
	return { subject = subject, body = body, zone = zone, parent = parent }
end

return p
