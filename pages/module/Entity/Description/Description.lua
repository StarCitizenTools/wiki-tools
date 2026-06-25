require('strict')

--- @module Entity/Description
--- Renders the game's English description for an entity plus the API version
--- the description was captured at. Designed to be placed separately from the
--- infobox (further down the page, as body prose). Consumes Module:Entity/Data
--- so it shares Apiunto's cache with any other Entity template on the page.

local data = require('Module:Entity/Data')

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

	local root = mw.html.create('div'):addClass('t-entity-description')
	local description = getEnglishDescription(result.apiData)
	if description then
		-- <blockquote> is the correct semantic for the quoted game text.
		-- aria-label identifies the quote source ("in-game description")
		-- without baking per-template context into the reusable version
		-- footer below.
		root:tag('blockquote')
			:addClass('t-entity-description-text')
			:attr('aria-label', 'In-game description')
			:tag('p')
			:wikitext(formatDescription(description))
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
