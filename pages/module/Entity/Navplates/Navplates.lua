require('strict')

--- @module Entity/Navplates
--- Renders the browse row at the foot of an entity page: one bar holding a link
--- out to the manufacturer's catalogue and one to the type hub, each with the
--- size of what it points at.
---
--- Replaces {{Navplate manufacturers}} and the per-type navplates. Those listed
--- a whole set on every page in that set, so a manufacturer with n products
--- rendered n^2 links across the wiki; Clark Defense Systems alone accounted for
--- roughly 337,000 of 828,792. This renders two links per page regardless of how
--- large the catalogue grows.
---
--- Both destinations are the hub page's `#list` anchor, which every type hub and
--- company page carries (see Template:Anchor). Linking the anchor rather than the
--- bare page lands the reader on the index rather than the lead.
---
--- Sibling renderer parallel to Module:Entity/Related — consumes
--- Module:Entity/Data so it shares Apiunto's cache with the infobox and the other
--- sibling templates on the same page.

local data = require('Module:Entity/Data')
local base = require('Module:Entity/Base')
local BucketQuery = require('Module:BucketQuery')
local Icon = require('Module:Icon')
local manufacturers = require('Module:Manufacturers')
local Store = require('Module:Entity/Store')

local p = {}

local HUBS_PAGE = 'Module:Entity/Navplates/hubs.json'
-- Codex's own next-arrow, rendered as a currentColor mask so it takes the
-- cell's colour in both themes rather than needing skin-invert.
local ARROW_ICON = 'CdxIconArrowNext.svg'
local ARROW_SIZE = '16px'
-- Bucket has no count aggregate, so a count selects the rows and counts them.
-- Measured on the live wiki: the largest catalogue (581 rows) costs ~4 ms of Lua
-- and ~10 ms of Bucket time, against the ~0.58 s of Lua an entity page already
-- spends. The limit is Bucket's own ceiling, not a tuning knob.
local COUNT_LIMIT = 5000

--- Counts the rows matching one property/value pair, or nil when the read
--- failed. nil and 0 are deliberately different: nil suppresses the count line,
--- 0 would claim an empty destination.
---
--- @param property string
--- @param value string
--- @return number|nil
local function countRows(property, value)
	if not value or value == '' then
		return nil
	end

	local ok, rows = pcall(BucketQuery.query, {
		filters = { { property, value } },
		columns = { { builtin = 'page_name', as = 'page' } },
		limit = COUNT_LIMIT,
	})
	if not ok or type(rows) ~= 'table' then
		return nil
	end

	local n = 0
	for _ in ipairs(rows) do
		n = n + 1
	end
	return n
end

--- Every form of a title a type string might arrive as. The value is a category
--- ("Guns") or a subject type ("Gun") depending on which layer answered, so both
--- directions have to match the one page title.
---
--- @param title string
--- @return string[]
local function inflections(title)
	local forms = { title }
	if mw.ustring.find(title, 'ies$') then
		table.insert(forms, (mw.ustring.gsub(title, 'ies$', 'y')))
	elseif mw.ustring.find(title, '[sxz]es$') or mw.ustring.find(title, '[cs]hes$') then
		table.insert(forms, mw.ustring.sub(title, 1, -3))
	elseif mw.ustring.find(title, 's$') and not mw.ustring.find(title, 'ss$') then
		table.insert(forms, mw.ustring.sub(title, 1, -2))
	end
	if mw.ustring.find(title, '[^aeiou]y$') then
		table.insert(forms, (mw.ustring.gsub(title, 'y$', 'ies')))
	elseif mw.ustring.find(title, '[sxz]$') or mw.ustring.find(title, '[cs]h$') then
		table.insert(forms, title .. 'es')
	elseif not mw.ustring.find(title, 's$') then
		table.insert(forms, title .. 's')
	end
	return forms
end

--- Builds the lookup once per render: every anchored hub under each of its
--- inflections, then the hand overrides on top.
---
--- @return table<string, string> lowercased form -> hub page title
--- @return table<string, string> hub page title -> plural label
local function hubIndex()
	local doc = mw.loadJsonData(HUBS_PAGE)
	local index, labels = {}, {}

	-- Exact titles first, and inflections only into keys still free. Two passes
	-- rather than one because pairs() has no defined order, so a single pass
	-- would let one hub's plural beat another hub's own title depending on how
	-- the table happened to iterate.
	for title, label in pairs(doc.hubs) do
		labels[title] = label
		index[mw.ustring.lower(title)] = title
	end
	for title in pairs(doc.hubs) do
		for _, form in ipairs(inflections(title)) do
			local key = mw.ustring.lower(form)
			if index[key] == nil then
				index[key] = title
			end
		end
	end

	for from, to in pairs(doc.overrides) do
		index[mw.ustring.lower(from)] = to
	end
	return index, labels
end

--- Resolves a type string to the hub page that carries the `#list` anchor, and
--- the plural that hub's own heading uses. The label is carried in the data
--- rather than derived: "armor" is uncountable, the dietary-effect hubs are
--- adjectives that need "items" appended, and several hub titles are proper
--- nouns. The headings already settled all three, so this reuses their wording
--- instead of inventing a second one.
---
--- Each candidate carries the `Subject type` value that counts the hub it
--- resolves to, or nil where nothing counts it. The two travel together because
--- the count has to describe the set the cell links to: a hub reached through a
--- browse category ("Medium ships") holds a curated page set that no single
--- subject type selects, so counting the page's own type there sizes a
--- different, much larger set than the reader is being sent to.
---
--- @param candidates { value: string|nil, countOn: string|nil }[] most specific first
--- @return string|nil hub page title
--- @return string|nil plural label
--- @return string|nil the value to count on, nil when the hub is uncountable
local function resolveHub(candidates)
	local index, labels
	for _, candidate in ipairs(candidates) do
		if type(candidate.value) == 'string' and candidate.value ~= '' then
			if not index then
				index, labels = hubIndex()
			end
			local hit = index[mw.ustring.lower(mw.text.trim(candidate.value))]
			if hit then
				return hit, labels[hit] or mw.ustring.lower(hit), candidate.countOn
			end
		end
	end
	return nil
end

--- The count line. It names what it counts unless the title above already is
--- that noun, so "Guns" is captioned "148 in total" rather than "148 guns".
---
--- @param n number|nil
--- @param noun string
--- @param line string the title the count sits beside
--- @return string|nil
local function countLine(n, noun, line)
	if not n or n <= 0 then
		return nil
	end
	local formatted = mw.language.getContentLanguage():formatNum(n)
	local lower = mw.ustring.lower(line)
	if noun ~= '' and mw.ustring.sub(lower, -mw.ustring.len(noun)) == noun then
		return formatted .. ' in total'
	end
	return formatted .. ' ' .. noun
end

--- One half of the bar. The whole cell is the target: the wikilink sits on the
--- title and CSS stretches it over the cell, which keeps the link a real
--- wikilink (so it redlinks, previews and tracks like any other) while letting
--- the eyebrow and the count sit outside its label.
---
--- @param opts { page: string, eyebrow: string, title: string, meta: string|nil }
--- @return string
local function buildCell(opts)
	local cell = mw.html.create('span'):addClass('t-entity-navplates__cell')

	local eyebrow = cell:tag('span'):addClass('t-entity-navplates__eyebrow')
	eyebrow:wikitext(opts.eyebrow)
	if opts.meta then
		eyebrow:tag('span'):addClass('t-entity-navplates__sep'):attr('aria-hidden', 'true'):wikitext('&middot;')
		eyebrow:tag('span'):addClass('t-entity-navplates__meta'):wikitext(opts.meta)
	end

	cell:tag('span')
		:addClass('t-entity-navplates__line')
		:wikitext(string.format('[[%s#list|%s]]', opts.page, opts.title))

	-- Decorative: the line already says where the link goes.
	cell:tag('span')
		:addClass('t-entity-navplates__arrow')
		:attr('aria-hidden', 'true')
		:wikitext(Icon.render({ icon = ARROW_ICON, size = ARROW_SIZE, mask = true }))

	return tostring(cell)
end

--- @param frame table
--- @return string
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	local cells = {}

	-- A sibling invocation parses its own arguments, so it cannot see the
	-- `manufacturer` an editor set on the page's own {{Entity}} call. The page's
	-- Bucket row already carries whatever that resolved to, editorial overrides
	-- included, so the row is the second source rather than a parameter on this
	-- template: one place to declare a manufacturer, not two that can drift.
	-- nil until the page's first link update has run, same as any Store read.
	-- UNKN is a resolved-but-meaningless sentinel: the API returns it wherever the
	-- real maker is unrecorded, and it resolves to a valid record, so guarding the
	-- fallback on nil alone lets it mask an editorial |manufacturer= that names the
	-- maker. Treat it as unresolved so the page's own row wins.
	local manufacturer = base.resolveManufacturer(result.apiData, args)
	if not manufacturer or manufacturer.code == 'UNKN' then
		local stored = Store.selfValue('Manufacturer')
		if type(stored) == 'string' and stored ~= '' then
			manufacturer = manufacturers.resolve(stored)
				or { code = stored, name = stored, short = stored, page = stored }
		end
	end
	if manufacturer and manufacturer.page then
		table.insert(
			cells,
			buildCell({
				page = manufacturer.page,
				eyebrow = 'More from',
				title = manufacturer.name,
				meta = countLine(countRows('Manufacturer', manufacturer.name), 'products', manufacturer.name),
			})
		)
	end

	-- Type first, then the browse categories the chain contributed, leaf-first.
	-- A spacecraft's own type resolves to nothing (Ships is a prose overview
	-- with no index to anchor), but its role categories are anchored hubs, so a
	-- fighter reaches Light fighters instead of rendering no type cell at all.
	local typeInfo = result.typeInfo
	local typeName = typeInfo and typeInfo.name
	local candidates = {
		{ value = typeInfo and typeInfo.category, countOn = typeName },
		{ value = typeName, countOn = typeName },
		{ value = result.displayType, countOn = typeName },
	}
	local browse = result.chainCategories or {}
	for i = #browse, 1, -1 do
		candidates[#candidates + 1] = { value = browse[i] }
	end

	local hub, noun, countOn = resolveHub(candidates)
	if not hub then
		-- Same reason as the manufacturer above: a sibling cannot see the `type`
		-- an editor set on the page's own {{Entity}} call, but the Bucket row can.
		-- Read last and only on a miss, so the pages the chain already answers for
		-- do not each pay a Bucket query for a value they never consult.
		local stored = Store.selfValue('Subject type')
		hub, noun, countOn = resolveHub({ { value = stored, countOn = stored } })
	end
	if hub then
		-- The labels are lowercased for mid-sentence use in the hub headings;
		-- in the title position the first letter comes back up.
		local title = mw.ustring.upper(mw.ustring.sub(noun, 1, 1)) .. mw.ustring.sub(noun, 2)
		table.insert(
			cells,
			buildCell({
				page = hub,
				eyebrow = 'More',
				title = title,
				meta = countLine(countRows('Subject type', countOn), noun, title),
			})
		)
	end

	if #cells == 0 then
		return ''
	end

	local root = mw.html.create('div'):addClass('t-entity-navplates')
	-- More than two destinations would not fit side by side at any width the
	-- skin offers, so the stacked form is not only a narrow-screen fallback.
	if #cells > 2 then
		root:addClass('t-entity-navplates--stacked')
	end
	root:wikitext(table.concat(cells))

	-- Module:Icon.render returns markup only, so its stylesheet is emitted here.
	local styles = frame:extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Icon/styles.css' },
	}) .. frame:extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/Navplates/styles.css' },
	})

	return styles .. tostring(root)
end

--- Exposed for the ScribuntoUnit suite; not part of the module's API.
p._internal = {
	resolveHub = resolveHub,
	countLine = countLine,
}

return p
