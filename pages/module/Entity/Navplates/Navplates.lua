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
local vehicleUtil = require('Module:Entity/Vehicle/Util')

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

--- Counts the rows one Module:BucketQuery filter matches, or nil when there is
--- no filter or the read failed. nil and 0 are deliberately different: nil
--- suppresses the count line, 0 would claim an empty destination.
---
--- @param filter string|table|nil a Module:BucketQuery filter
--- @return number|nil
local function countRows(filter)
	if filter == nil then
		return nil
	end

	local ok, rows = pcall(BucketQuery.query, {
		filters = { filter },
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

--- The hub a whole kind browses to, from `kinds` in hubs.json, or nil.
---
--- Matched exactly against the resolved kind and never through the shared type
--- index: kind names (Item, Location) are generic words an unrelated hub could
--- capture. A kind listed there browses to its hub exclusively, because its type
--- strings are a different vocabulary from the one the index is keyed on:
--- commodity subject types are substances, and `Food` is both a commodity type
--- and the consumable food hub.
---
--- @param kind string|nil
--- @return { hub: string, label: string }|nil
local function kindHub(kind)
	if type(kind) ~= 'string' then
		return nil
	end
	local doc = mw.loadJsonData(HUBS_PAGE)
	local hub = doc.kinds and doc.kinds[kind]
	if not hub then
		return nil
	end
	return { hub = hub, label = doc.hubs[hub] or mw.ustring.lower(hub) }
end

--- The Module:BucketQuery filter that counts the set a hub lists, or nil where
--- nothing counts it.
---
--- A hub named in `selects` is counted by the selector its own grid uses. Its
--- rows span many subject types, so counting the page's own type would caption
--- a link to every commodity with the metals alone. Every other hub is counted
--- by the `Subject type` its candidate carried.
---
--- @param hub string
--- @param countOn string|nil
--- @return string|table|nil
local function countFilter(hub, countOn)
	local selects = mw.loadJsonData(HUBS_PAGE).selects
	local selector = selects and selects[hub]
	if selector then
		return selector
	end
	if type(countOn) == 'string' and countOn ~= '' then
		return { 'Subject type', countOn }
	end
	return nil
end

--- Maps role strings to their browse hubs, most specific first. The lookup and
--- the reason it is scoped away from the shared type index live in
--- Module:Entity/Vehicle/Util.roleHub; this only shapes the result into
--- candidates.
---
--- Carries no count. Of the hubs a role reaches, the ones that predate the map
--- select their rows by category, not by Role, so counting `Role` would size a
--- different set from the page linked.
---
--- @param roles string[]|nil
--- @param family string|nil
--- @return { hub: string, label: string }[]
local function roleHubs(roles, family)
	local out = {}
	if type(roles) ~= 'table' then
		return out
	end
	for _, role in ipairs(roles) do
		local hub = vehicleUtil.roleHub(role, family)
		if hub then
			out[#out + 1] = { hub = hub, label = mw.ustring.lower(hub) }
		end
	end
	return out
end

--- Resolves a candidate list to the hub page that carries the `#list` anchor,
--- and the plural that hub's own heading uses. The label is carried in the data
--- rather than derived: "armor" is uncountable, the dietary-effect hubs are
--- adjectives that need "items" appended, and several hub titles are proper
--- nouns. The headings already settled all three, so this reuses their wording
--- instead of inventing a second one.
---
--- A candidate is one of two shapes. `{ hub, label }` already names its
--- destination and is returned as-is, never looked up, which is what keeps a
--- role out of the shared type index. `{ value, countOn }` is a type string
--- matched against that index, and carries the `Subject type` value that counts
--- the hub it resolves to, or nil where nothing counts it. The two travel
--- together because the count has to describe the set the cell links to: a hub
--- reached through a browse category ("Medium ships") holds a curated page set
--- that no single subject type selects, so counting the page's own type there
--- sizes a different, much larger set than the reader is being sent to.
---
--- @param candidates ({ hub: string, label: string }|{ value: string|nil, countOn: string|nil })[] most specific first
--- @return string|nil hub page title
--- @return string|nil plural label
--- @return string|nil the value to count on, nil when the hub is uncountable
local function resolveHub(candidates)
	local index, labels
	for _, candidate in ipairs(candidates) do
		-- A role candidate already names its hub page, so it never goes through
		-- the shared index: that is what keeps a generic role out of an item hub.
		if candidate.hub then
			return candidate.hub, candidate.label, candidate.countOn
		end
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
	-- A sentinel names no company to link, whichever path produced it: an
	-- editorial |manufacturer=NONE is stored as written, so the page's row can
	-- carry one although the API path filters them.
	if manufacturer and base.namesNoMaker(manufacturer.code) then
		manufacturer = nil
	end
	if manufacturer and manufacturer.page then
		table.insert(
			cells,
			buildCell({
				page = manufacturer.page,
				eyebrow = 'More from',
				title = manufacturer.name,
				meta = countLine(countRows({ 'Manufacturer', manufacturer.name }), 'products', manufacturer.name),
			})
		)
	end

	-- Type first, then the browse categories the chain contributed, leaf-first.
	-- A spacecraft's own type resolves to nothing (Ships is a prose overview
	-- with no index to anchor), but its role categories are anchored hubs, so a
	-- fighter reaches Light fighters instead of rendering no type cell at all.
	local typeInfo = result.typeInfo
	local typeName = typeInfo and typeInfo.name
	local candidates = {}
	-- A kind listed in `kinds` browses to its hub alone; see kindHub.
	local kindCandidate = kindHub(result.kind)
	if kindCandidate then
		candidates[1] = kindCandidate
	else
		-- A vehicle's role outranks its type and the chain's browse categories:
		-- "Light freighters" and "Anti-air vehicles" both say more than the type
		-- hub they would otherwise fall back to ("Ground vehicles", 42 rows), and a
		-- spacecraft's own type resolves to no hub at all.
		-- The page's stored row wins over the API record, because the editorial
		-- `role=` an editor wrote on {{Entity}} is frequently a CORRECTION of a wrong
		-- upstream value, and a sibling invocation cannot see that arg itself. The
		-- Cyclone is "Passenger" upstream and "Exploration / Recon" on the page; the
		-- MOLE is "Medium Mining" and "Prospecting / Mining". Reading the API first
		-- made the browse row contradict the infobox beside it.
		--
		-- One read, at one precedence point. A vehicle page with a blank `uuid`
		-- resolves no record, so a sibling sees kind "Item" and an empty apiData
		-- (Cydnus, Arrastra); that is why an empty record qualifies too, rather than
		-- kind alone. Items reach neither branch and pay nothing.
		local family = vehicleUtil.family(result.apiData)
		if result.kind == 'Vehicle' or next(result.apiData or {}) == nil then
			local stored = Store.selfValues('Role', 'Vehicle')
			if stored then
				-- A row exists, so it is the answer, even when it names roles no hub
				-- covers: falling back to the API there would put the upstream value
				-- back in front of the editor's. The Cutter Scout is "Pathfinder"
				-- upstream and "Reconnaissance / Intelligence" on the page, and it
				-- must reach no role hub rather than Pathfinders.
				candidates = roleHubs(stored, family)
			elseif result.kind == 'Vehicle' then
				-- No row yet, which is a page that has never had a link update. The
				-- API record is all there is.
				candidates = roleHubs(vehicleUtil.resolveRole(result.apiData or {}, args), family)
			end
		end
		local typeCandidates = {
			{ value = typeInfo and typeInfo.category, countOn = typeName },
			{ value = typeName, countOn = typeName },
			{ value = result.displayType, countOn = typeName },
		}
		for _, candidate in ipairs(typeCandidates) do
			candidates[#candidates + 1] = candidate
		end
		local browse = result.chainCategories or {}
		for i = #browse, 1, -1 do
			candidates[#candidates + 1] = { value = browse[i] }
		end
	end

	local hub, noun, countOn = resolveHub(candidates)
	if not hub then
		-- Same reason as the role above: a sibling cannot see the `type` an
		-- editor set on the page's own {{Entity}} call, but the Bucket row can.
		-- Read last and only on a miss, so the pages the chain already answers
		-- for do not each pay a Bucket query for a value they never consult.
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
				meta = countLine(countRows(countFilter(hub, countOn)), noun, title),
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
	kindHub = kindHub,
	countFilter = countFilter,
}

return p
