require('strict')

--- @module Entity/LocationNavigation/Model
--- Place rows and Module:SystemMap/Data.findBody results → the models the
--- page-foot panels render. Pure: no Bucket reads and no title lookups.

local amenities = require('Module:Entity/Location/Place/Amenities')
local classes = require('Module:Entity/Location/Place/Classes')

local p = {}

--- Heading for places whose class is missing or outside the vocabulary.
p.OTHER = 'Other'

local LANDING_ZONE = 'Landing zone'
local POINT_ORDER = { L1 = 1, L2 = 2, L3 = 3, L4 = 4, L5 = 5 }
local NEAR = { L1 = true, L2 = true }

--- A page name without its trailing disambiguator.
--- @param page string
--- @return string
function p.label(page)
	return mw.text.trim((page:gsub('%s*%b()$', '')))
end

--- @param page string
--- @param label string|nil
--- @return string
function p.link(page, label)
	return '[[' .. page .. '|' .. (label or p.label(page)) .. ']]'
end

local function sortKey(text)
	return mw.ustring.lower(text)
end

--- A trailing code: the last word, when it holds a digit and only capitals,
--- digits and hyphens ("SM0-10", "2UB-RB9-5").
local function trailingCode(label)
	local stem, code = label:match('^(.-)%s+([%u%d][%u%d%-]*)$')
	if stem and stem ~= '' and code:find('%d') then
		return stem, code
	end
	return nil
end

--- A prefix code: two or more capitals and a hyphen ("HDMS-Edmond").
local function prefixCode(label)
	return label:match('^(%u%u+)%-(%S.*)$')
end

--- Items → entries: a family (a shared stem plus a trailing code, or a shared
--- prefix code, with at least two members) becomes one entry whose members are
--- labelled by their code; everything else stays a plain item.
--- @param items { page: string, label: string }[]
--- @return table[] { page, label } | { family, members }
function p.families(items)
	local buckets, entries = {}, {}
	for _, item in ipairs(items) do
		local name, code = trailingCode(item.label)
		if not name then
			name, code = prefixCode(item.label)
		end
		if name then
			buckets[name] = buckets[name] or {}
			table.insert(buckets[name], { item = item, code = code })
		else
			entries[#entries + 1] = { page = item.page, label = item.label }
		end
	end
	for name, members in pairs(buckets) do
		if members[2] then
			local links = {}
			for _, member in ipairs(members) do
				links[#links + 1] = { page = member.item.page, label = member.code }
			end
			table.sort(links, function(a, b)
				return sortKey(a.label) < sortKey(b.label)
			end)
			entries[#entries + 1] = { family = name, members = links }
		else
			entries[#entries + 1] = { page = members[1].item.page, label = members[1].item.label }
		end
	end
	table.sort(entries, function(a, b)
		return sortKey(a.family or a.label) < sortKey(b.family or b.label)
	end)
	return entries
end

--- Rows grouped under their class's plural category, headings alphabetical
--- with Other last.
--- @param rows table[]
--- @param withFamilies boolean
--- @return { heading: string, entries: table[] }[]
function p.groups(rows, withFamilies)
	local byHeading, headings = {}, {}
	for _, row in ipairs(rows) do
		local entry = classes.get(row.classification)
		local heading = entry and entry.category or p.OTHER
		if not byHeading[heading] then
			byHeading[heading] = {}
			headings[#headings + 1] = heading
		end
		table.insert(byHeading[heading], { page = row.page, label = p.label(row.page) })
	end
	table.sort(headings, function(a, b)
		if a == p.OTHER then
			return false
		end
		if b == p.OTHER then
			return true
		end
		return sortKey(a) < sortKey(b)
	end)
	local out = {}
	for _, heading in ipairs(headings) do
		local items = byHeading[heading]
		if withFamilies then
			items = p.families(items)
		else
			table.sort(items, function(a, b)
				return sortKey(a.label) < sortKey(b.label)
			end)
		end
		out[#out + 1] = { heading = heading, entries = items }
	end
	return out
end

--- @param row table
--- @return table
local function card(row)
	return {
		page = row.page,
		label = p.label(row.page),
		class = LANDING_ZONE,
		image = row.image,
		meta = amenities.summary(type(row.amenities) == 'table' and row.amenities or {}),
	}
end

--- Lagrange rows → near (L1, L2) and far (L3–L5) points, in point order.
--- @param rows table[]
--- @return table[] near
--- @return table[] far
function p.lagrange(rows)
	local near, far = {}, {}
	for _, row in ipairs(rows) do
		if POINT_ORDER[row.lagrange] then
			table.insert(NEAR[row.lagrange] and near or far, { point = row.lagrange, page = row.page })
		end
	end
	local function byPoint(a, b)
		if a.point ~= b.point then
			return POINT_ORDER[a.point] < POINT_ORDER[b.point]
		end
		return a.page < b.page
	end
	table.sort(near, byPoint)
	table.sort(far, byPoint)
	return near, far
end

--- The line above a body panel's title: the system, a moon's planet, and the
--- body's designation · subtype.
--- @param body table findBody result
--- @return string
function p.eyebrow(body)
	local parts = { p.link(body.system.page, body.system.page) }
	if body.kind == 'moon' and body.planet then
		parts[#parts + 1] = p.link(body.planet.page, body.planet.label)
		if body.entry.designation then
			parts[#parts + 1] = body.entry.designation
		end
	elseif body.kind == 'planet' then
		local tail = {}
		tail[#tail + 1] = body.entry.designation
		tail[#tail + 1] = body.entry.subtype
		if tail[1] then
			parts[#parts + 1] = table.concat(tail, ' · ')
		end
	end
	return table.concat(parts, ' › ')
end

--- @param body table   findBody result
--- @param rows table[] place rows whose Parent is the body's page
--- @return table|nil   nil when the body has nothing to show
function p.bodyPanel(body, rows)
	local byZone = { surface = {}, orbit = {}, lagrange = {}, star = {} }
	for _, row in ipairs(rows or {}) do
		if byZone[row.zone] then
			table.insert(byZone[row.zone], row)
		end
	end
	local panelRows = {}
	local cards, others = {}, {}
	for _, row in ipairs(byZone.surface) do
		local entry = classes.get(row.classification)
		if entry and entry.name == LANDING_ZONE then
			cards[#cards + 1] = card(row)
		else
			others[#others + 1] = row
		end
	end
	table.sort(cards, function(a, b)
		return sortKey(a.label) < sortKey(b.label)
	end)
	if cards[1] or others[1] then
		panelRows[#panelRows + 1] =
			{ key = 'surface', label = 'Surface', cards = cards, groups = p.groups(others, true) }
	end
	local orbiting = body.kind == 'star' and byZone.star or byZone.orbit
	if orbiting[1] then
		panelRows[#panelRows + 1] = { key = 'orbit', label = 'In orbit', groups = p.groups(orbiting, true) }
	end
	if body.kind == 'planet' then
		local moons = {}
		for _, moon in ipairs(body.entry.moons or {}) do
			if moon.tier ~= 'ring' then
				moons[#moons + 1] = {
					page = moon.page,
					label = moon.label or p.label(moon.page),
					designation = moon.designation,
					icon = moon.icon,
					km = moon.km,
				}
			end
		end
		if moons[1] then
			panelRows[#panelRows + 1] = { key = 'moons', label = 'Moons', moons = moons }
		end
		local near, far = p.lagrange(byZone.lagrange)
		if near[1] or far[1] then
			panelRows[#panelRows + 1] = { key = 'lagrange', label = 'Lagrange points', near = near, far = far }
		end
	end
	if not panelRows[1] then
		return nil
	end
	if panelRows[1].key ~= 'surface' then
		table.insert(panelRows, 1, { key = 'cap' })
	end
	return {
		eyebrow = p.eyebrow(body),
		title = p.link(body.entry.page, body.entry.label),
		disc = { icon = body.entry.icon, star = body.kind == 'star' },
		rows = panelRows,
	}
end

--- @param container string  the place whose contents are listed
--- @param rows table[]      rows whose Parent is the container
--- @param body table|nil    findBody result for the container's body
--- @return table|nil
function p.insidePanel(container, rows, body)
	local inside = {}
	for _, row in ipairs(rows or {}) do
		if row.zone == 'inside' then
			inside[#inside + 1] = row
		end
	end
	if not inside[1] then
		return nil
	end
	local eyebrow
	if body then
		eyebrow = p.link(body.system.page, body.system.page) .. ' › ' .. p.link(body.entry.page, body.entry.label)
	end
	return { eyebrow = eyebrow, title = p.link(container), groups = p.groups(inside, false) }
end

return p
