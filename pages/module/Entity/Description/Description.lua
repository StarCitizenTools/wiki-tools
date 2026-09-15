require('strict')

--- @module Entity/Description
--- Renders the game's English description for an entity plus the API version
--- the description was captured at. Designed to be placed separately from the
--- infobox (further down the page, as body prose). Consumes Module:Entity/Data
--- so it shares Apiunto's cache with any other Entity template on the page.

local data = require('Module:Entity/Data')
local tabbedCard = require('Module:TabbedCard')

local p = {}

--- Apiunto unwraps the multi-locale object when the request includes
--- `locale=en_EN`, so `description` arrives as a plain English string on
--- the item endpoint. The table branch stays as a defensive fallback for
--- any future endpoint that returns the full locale map.
---
--- @param apiData table
--- @return string|nil
local function getEnglishDescription(apiData)
	local desc = apiData.description
	if type(desc) == 'string' then
		return desc
	end
	if type(desc) == 'table' then
		return desc.en_EN
	end
	return nil
end

--- The game data leaves some contracts' description as a bare unresolved
--- reference -- `[Contractor|DestroyProbeDescription]` -- rather than prose;
--- 184 of the 1,786 mission records in 4.10 are shaped this way. Rendering one
--- verbatim would print an internal token to the page, so a description that is
--- nothing but a single bracketed reference counts as absent. A description
--- that merely CONTAINS such a reference is prose and is kept: the game
--- substitutes those inline (`head over to [Location|Address] and ...`).
--- @param description string
--- @return boolean
local function isUnresolvedPlaceholder(description)
	return string.match(description, '^%s*%[[^%]]*%]%s*$') ~= nil
end

--- The description worth rendering, or nil when the record has none: absent,
--- empty, or an unresolved placeholder. Exposed so the behaviour is unit
--- testable without a render pipeline.
--- @param apiData table
--- @return string|nil
function p.resolveDescription(apiData)
	local desc = getEnglishDescription(apiData)
	if type(desc) ~= 'string' or desc == '' or isUnresolvedPlaceholder(desc) then
		return nil
	end
	return desc
end

--- The alternative descriptions a record carries in `description_variants`.
---
--- A record whose `description` is an unresolved placeholder very often has the
--- real prose here instead: the game holds several fully-substituted flavour
--- texts and picks one at random each time the contract is offered, so no single
--- variant is the canonical one and all of them are shown. 99 of the 184
--- placeholder-description mission records in 4.10 carry variants, most of them
--- three.
---
--- Filtered the same way as `description`: a variant that is itself only a
--- bracketed reference is not prose.
---
--- @param apiData table
--- @return string[]
function p.resolveVariants(apiData)
	local variants = apiData.description_variants
	if type(variants) ~= 'table' then
		return {}
	end
	local resolved = {}
	for _, variant in ipairs(variants) do
		if type(variant) == 'string' and variant ~= '' and not isUnresolvedPlaceholder(variant) then
			table.insert(resolved, variant)
		end
	end
	return resolved
end

--- Converts the game's `<EMn>` emphasis markup into themed spans so the
--- colored highlight survives into the rendered HTML. `%1` carries the
--- emphasis level (1-4) through to the matching `.t-entity-description-emN`
--- CSS class.
---
--- @param description string
--- @return string
local function formatDescription(description)
	description = string.gsub(description, '<EM(%d)>', '<span class="t-entity-description-em%1">')
	description = string.gsub(description, '</EM(%d)>', '</span>')
	return description
end

--- One quoted description. <blockquote> is the correct semantic for quoted game
--- text; aria-label names the quote's source without baking per-template
--- context into the reusable version footer.
---
--- @param description string
--- @return mw.html
local function quoteHtml(description)
	local quote =
		mw.html.create('blockquote'):addClass('t-entity-description-text'):attr('aria-label', 'In-game description')
	quote:tag('p'):wikitext(formatDescription(description))
	return quote
end

--- Several descriptions, as a Module:TabbedCard. The card replaces the plain
--- container rather than nesting inside it: `.t-entity-description` is already
--- a bordered, rounded, surface-coloured box built from the same Citizen
--- tokens, so one box with a tab strip is the same shape the reader knows, and
--- the API version line lands in the card's own footer.
---
--- Tabs are numbered because the variants have no names and no precedence --
--- the game picks between them at random -- so any other label would invent a
--- distinction the data does not make.
---
--- @param variants string[]
--- @param version string|nil
--- @return string
local function variantsHtml(variants, version)
	local tabs = {}
	for i, variant in ipairs(variants) do
		tabs[i] = {
			label = 'Variant ' .. tostring(i),
			content = tostring(quoteHtml(variant)),
		}
	end
	return tabbedCard.render({
		class = 't-entity-description-variants',
		tabs = tabs,
		footer = version,
	})
end

--- Main entry point. Always renders the container so the layout is stable
--- whether or not the API has a description; falls back to an empty-state
--- message when the description is missing.
---
--- @param frame table
--- @return string
function p.main(frame)
	local args = data.parseArgs(frame)
	local result = data.get(args)

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Entity/Description/styles.css' },
	})

	local description = p.resolveDescription(result.apiData)
	if not description then
		local variants = p.resolveVariants(result.apiData)
		if #variants > 0 then
			return styles .. variantsHtml(variants, result.apiData.version)
		end
	end

	local root = mw.html.create('div'):addClass('t-entity-description')
	if description then
		root:node(quoteHtml(description))
	else
		-- No quote to render, so fall back to <p> rather than an empty
		-- <blockquote> that would mislead semantic parsers.
		root:tag('p')
			:addClass('t-entity-description-text')
			:addClass('t-entity-description-text--empty')
			:wikitext('No description available from the API.')
	end

	if result.apiData.version then
		root:tag('p'):addClass('t-entity-description-source'):wikitext(result.apiData.version)
	end

	return styles .. tostring(root)
end

return p
