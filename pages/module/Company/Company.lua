require('strict')

--- @module Company
--- Renders the company infobox (Template:Infobox company) via Module:InfoboxLua.
--- Standalone, manual params, no API; pure builders decoupled from p.main so a
--- future organization/faction Entity can consume the company facet.

local infobox = require('Module:InfoboxLua')
local manufacturers = require('Module:Manufacturers')
local button = require('Module:ButtonLua')
local makeList = require('Module:list').makeList

local lang = mw.language.getContentLanguage()

local p = {}

local PROPERTIES = mw.loadJsonData('Module:Company/properties.json')

--- Strip wiki-link markup, keeping display text: [[A|B]] -> B, [[A]] -> A.
--- @param text string|nil
--- @return string|nil
local function delink(text)
	if not text or text == '' then
		return text
	end
	text = text:gsub('%[%[[^%]|]*|([^%]]-)%]%]', '%1') -- piped link -> label
	text = text:gsub('%[%[([^%]]-)%]%]', '%1') -- simple link -> target
	return text
end

--- Extract the link TARGET (page title) for SMW Page properties:
--- [[Target|Label]] -> Target, [[Target]] -> Target, plain text -> itself.
--- @param text string|nil
--- @return string|nil
local function pageTitle(text)
	if not text or text == '' then
		return text
	end
	text = text:gsub('%[%[([^%]|]*)|[^%]]-%]%]', '%1') -- piped -> target
	text = text:gsub('%[%[([^%]]-)%]%]', '%1') -- simple -> target
	return text
end

--- Split a semicolon-separated list into trimmed, non-empty parts. Semicolon is
--- the multi-value separator (collision-resistant vs commas, which appear inside
--- company names, addresses, and link labels).
--- @param text string
--- @return string[]
local function splitSemi(text)
	local parts = {}
	for part in (text .. ';'):gmatch('([^;]*);') do
		part = mw.text.trim(part)
		if part ~= '' then
			parts[#parts + 1] = part
		end
	end
	return parts
end

--- The TARGET of the last wikilink in a string ([[A|B]] / [[A]] -> A), or nil.
--- Used for Headquarters: the convention is "place, …, system", so the last
--- link of each HQ segment is its star system.
--- @param text string
--- @return string|nil
local function lastLink(text)
	local last
	for target in text:gmatch('%[%[([^%]]-)%]%]') do
		last = mw.text.trim((target:gsub('|.*$', '')))
	end
	if last == '' then
		last = nil
	end
	return last
end

--- Founded display: a bare SC year renders via {{Start date and age}} (so the
--- editor passes a clean year and SMW stores the year, not rendered template
--- output); any other value (full date, "Unknown", …) shows as-is.
--- @param value string|nil
--- @return string|nil
local function foundedDisplay(value)
	if value and value:match('^%s*%d+%s*$') then
		return '{{Start date and age|' .. mw.text.trim(value) .. '|sctime=yes}}'
	end
	return value
end

--- Display helper for multi-value fields: a semicolon list with 2+ items renders
--- as a Module:list unbulleted list with a hanging indent; a single item renders
--- plain. Calls Module:list directly (rather than the {{Unbulleted indent list}}
--- wrapper) to avoid re-parsing a template invocation per field — items pass as
--- Lua values, so piped links need no {{!}} escaping.
--- @param value string|nil
--- @return string|nil
local function multiList(value)
	if not value or value == '' then
		return value
	end
	local items = splitSemi(value)
	if #items <= 1 then
		return value
	end
	-- Hanging indent matches Template:Unbulleted indent list's default.
	items.list_style = 'margin-left:1em;text-indent:-1em'
	return makeList('unbulleted', items)
end

--- Append a {label, content} item only when content is a non-empty string.
--- @param items table[]
--- @param label string
--- @param content string|nil
local function push(items, label, content)
	if content ~= nil and content ~= '' then
		items[#items + 1] = { label = label, content = content }
	end
end

--- Build a section from a dense items array; nil when no items survived.
--- InfoboxLua renders an empty <dl> for a section whose items array is
--- non-empty but all-dropped, so filtering MUST happen here.
--- @param items table[]
--- @param opts table|nil  -- { label, collapsible, collapsed, columns, class }
--- @return table|nil
local function makeSection(items, opts)
	if #items == 0 then
		return nil
	end
	local section = { items = items }
	if opts then
		section.label = opts.label
		section.collapsible = opts.collapsible
		section.collapsed = opts.collapsed
		section.columns = opts.columns
		section.class = opts.class
	end
	return section
end

local TRANSFORMS = {
	-- Page scalar: single link target.
	page = function(v)
		return pageTitle(v)
	end,
	-- Page list: semicolon-split, each item's link target.
	pageList = function(v)
		local out = {}
		for _, item in ipairs(splitSemi(v)) do
			out[#out + 1] = pageTitle(item)
		end
		return out
	end,
	-- Headquarters: one star system per HQ — the last wikilink of each
	-- semicolon-separated HQ segment (the convention is "place, …, system").
	hqSystems = function(v)
		local out = {}
		for _, segment in ipairs(splitSemi(v)) do
			local sys = lastLink(segment)
			if sys then
				out[#out + 1] = sys
			end
		end
		return out
	end,
	-- Industry/Products: semicolon-split; each item lcfirst + delinked (display
	-- label kept), the legacy delink/lcfirst normalisation applied per value.
	textList = function(v)
		local out = {}
		for _, item in ipairs(splitSemi(v)) do
			out[#out + 1] = delink(lang:lcfirst(item))
		end
		return out
	end,
}

--- Race, trimmed; defaults to "Human" when absent.
--- @param race string|nil
--- @return string
function p.normalizeRace(race)
	race = race and mw.text.trim(race) or ''
	if race == '' then
		return 'Human'
	end
	return race
end

--- Resolve the manufacturer code by looking up the company name via
--- Module:Manufacturers, the single source of truth. There is deliberately no
--- override parameter — the registry is authoritative, so an explicit `code`
--- arg is ignored. Returns nil when the name matches no known manufacturer.
--- @param args table
--- @return string|nil
function p.resolveCode(args)
	local name = args.name and mw.text.trim(args.name) or nil
	local record = name and manufacturers.resolve(name) or nil
	return record and record.code or nil
end

--- The Race infobox cell: a link to the per-race companies category
--- (matches the legacy template). Always present (race defaults to Human).
--- @param args table
--- @return string
function p.raceLink(args)
	local race = p.normalizeRace(args.race)
	return '[[:Category:' .. race .. ' companies|' .. race .. ']]'
end

--- Build the SMW property table from the manifest. Pure (no frame).
--- @param args table
--- @return table<string, string|string[]>
function p.getStructuredData(args)
	local src = {
		name = args.name,
		industry = args.industry,
		products = args.products,
		code = p.resolveCode(args),
		race = args.race,
		headquarters = args.headquarters,
		areaserved = args.areaserved,
		founder = args.founder,
		founded = args.founded,
		parent = args.parent,
		subsidiaries = args.subsidiaries,
		predecessor = args.predecessor,
		successor = args.successor,
	}

	local data = {}
	for prop, def in pairs(PROPERTIES) do
		if prop:sub(1, 1) ~= '%' then
			local value = src[def.source]
			if type(value) == 'string' then
				value = mw.text.trim(value)
			end
			if (value == nil or value == '') and def.default then
				value = def.default
			end
			if value ~= nil and value ~= '' then
				if def.transform then
					value = TRANSFORMS[def.transform](value)
				end
				if type(value) == 'table' then
					if #value > 0 then
						data[prop] = value
					end
				elseif value ~= '' then
					data[prop] = value
				end
			end
		end
	end
	return data
end

--- Short description: "<race> company in the <industry> industry", or
--- "<race> company in Star Citizen" when no industry. Industry is lcfirst+
--- delinked (faithful to the legacy template). Pure (no frame).
--- @param args table
--- @return string
function p.getShortDescription(args)
	local race = p.normalizeRace(args.race)
	local industry = args.industry and mw.text.trim(args.industry) or ''
	if industry ~= '' then
		-- Use the first (primary) industry so the description stays concise.
		local first = splitSemi(industry)[1] or industry
		return race .. ' company in the ' .. delink(lang:lcfirst(first)) .. ' industry'
	end
	return race .. ' company in Star Citizen'
end

--- Content categories (mainspace gating is the caller's job). Pure.
--- @param args table
--- @return string[]
function p.getCategories(args)
	local race = p.normalizeRace(args.race)
	return { 'Companies', race .. ' companies' }
end

--- @class CompanyHeaderData
--- @field title string
--- @field subtitle string
--- @field image table|nil

--- Header data for InfoboxLua. Pure. image is nil when no filename (InfoboxLua
--- supplies its own placeholder); imagebg maps to the image background class.
--- @param args table
--- @return CompanyHeaderData
function p.getHeader(args)
	local bgClass = nil
	if args.imagebg == 'light' then
		bgClass = 't-infobox-image--light'
	elseif args.imagebg == 'dark' then
		bgClass = 't-infobox-image--dark'
	end

	local image = nil
	if args.image and args.image ~= '' then
		image = { src = args.image, class = bgClass }
	end

	return {
		title = (args.name and args.name ~= '' and args.name) or mw.title.getCurrentTitle().text,
		subtitle = 'Company',
		image = image,
	}
end

--- The grouped content sections: an unlabelled top group (common descriptive
--- fields, always inline) plus collapsible People / History / Relations.
--- Metadata / external-sites / footer are added by getSections. Pure (no
--- frame). Empty rows and empty groups self-drop.
--- @param args table
--- @return table[]
function p.getContentSections(args)
	local sections = {}
	local function add(section)
		if section then
			sections[#sections + 1] = section
		end
	end

	-- Top group (unlabelled) — the common descriptive fields appear immediately,
	-- with no collapse header. Manufacturer code is an identifier, not descriptive
	-- content, so it lives in the collapsed Metadata section, mirroring Entity.
	local top = {}
	push(top, 'Industry', multiList(args.industry))
	push(top, 'Products', multiList(args.products))
	push(top, 'Race', p.raceLink(args)) -- always present (defaults to Human)
	push(top, 'Headquarters', multiList(args.headquarters))
	push(top, 'Area served', multiList(args.areaserved))
	add(makeSection(top))

	-- Founding context (Founder + Founded) sits with People rather than the
	-- top group; intentional grouping, differs from Wikipedia's layout.
	local people = {}
	push(people, 'Key people', multiList(args.keypeople))
	push(people, 'Founder', multiList(args.founder))
	push(people, 'Founded', foundedDisplay(args.founded))
	add(makeSection(people, { label = 'People', collapsible = true }))

	local history = {}
	push(history, 'Fate', args.fate)
	push(history, 'Defunct', args.defunct)
	push(history, 'Formerly', args.formerly)
	push(history, 'Predecessor', args.predecessor)
	push(history, 'Successor', args.successor)
	add(makeSection(history, { label = 'History', collapsible = true }))

	local relations = {}
	push(relations, 'Parent', args.parent)
	push(relations, 'Subsidiaries', multiList(args.subsidiaries))
	push(relations, 'Allies', multiList(args.allies))
	push(relations, 'Rivals', multiList(args.rivals))
	add(makeSection(relations, { label = 'Relations', collapsible = true }))

	return sections
end

--- Collapsed "Metadata" section for identifiers (manufacturer code) rather than
--- descriptive content, mirroring Module:Entity/Infobox's metadata section.
--- nil when there is no metadata. Pure (no frame).
--- @param args table
--- @return table|nil
function p.getMetadataSection(args)
	local items = {}
	push(items, 'Manufacturer code', p.resolveCode(args))
	return makeSection(items, { label = 'Metadata', collapsible = true, collapsed = true })
end

--- Collapsed "External sites" section holding the Portfolio link (the Entity
--- external-sites pattern). nil when no portfolio URL.
--- @param args table
--- @return table|nil
function p.getExternalSitesSection(args)
	if not args.portfoliourl or args.portfoliourl == '' then
		return nil
	end
	return {
		label = 'External sites',
		collapsible = true,
		collapsed = true,
		items = {
			{ label = 'Portfolio', content = '[' .. args.portfoliourl .. ' RSI Portfolio]' },
		},
	}
end

--- Footer action row with the Galactapedia button (Module:ButtonLua), mirroring
--- Module:Entity/Infobox buildFooterSection. Flat (not collapsible). nil when no
--- Galactapedia URL.
--- @param args table
--- @return table|nil
function p.getFooterSection(args)
	if not args.galactapediaurl or args.galactapediaurl == '' then
		return nil
	end
	local btn = button.render({
		label = 'Galactapedia',
		url = args.galactapediaurl,
		icon = 'Sc-icon-galactapedia.svg',
		weight = 'normal',
		class = 't-button--galactapedia',
	})
	local actions = mw.html.create('div'):addClass('t-infobox-footer-actions'):wikitext(btn)
	return {
		content = tostring(actions),
		class = 't-infobox-section--footer',
	}
end

--- All infobox sections: content groups, then metadata, then external sites,
--- then footer (mirrors Module:Entity/Infobox's assembly order).
--- @param args table
--- @return table[]
function p.getSections(args)
	local sections = p.getContentSections(args)
	local meta = p.getMetadataSection(args)
	if meta then
		sections[#sections + 1] = meta
	end
	local ext = p.getExternalSitesSection(args)
	if ext then
		sections[#sections + 1] = ext
	end
	local footer = p.getFooterSection(args)
	if footer then
		sections[#sections + 1] = footer
	end
	return sections
end

--- Wikitext entry point. Renders the infobox and wires page-meta.
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local args = require('Module:Arguments').getArgs(frame)

	local styles = frame:extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Company/styles.css' },
	})

	local header = p.getHeader(args)
	local html = infobox.render({
		title = header.title,
		subtitle = header.subtitle,
		image = header.image,
		class = 't-company',
		sections = p.getSections(args),
	})

	-- Short description (matches legacy: emitted in every transcluding namespace).
	frame:callParserFunction('SHORTDESC', p.getShortDescription(args))

	-- Structured data + content categories: mainspace only, so /doc and sandbox
	-- pages don't pollute canonical SMW / the category tree.
	local categories = ''
	if mw.title.getCurrentTitle():inNamespace(0) then
		-- Capture the pcall result so SMW write failures are surfaced as a
		-- tracking category, consistent with Module:Entity/Categories.
		local smwOk = pcall(mw.smw.set, p.getStructuredData(args))
		if not smwOk then
			categories = categories .. '[[Category:Pages with structured data errors]]'
		end
		for _, name in ipairs(p.getCategories(args)) do
			categories = categories .. '[[Category:' .. name .. ']]'
		end
	end

	return styles .. html .. categories
end

return p
