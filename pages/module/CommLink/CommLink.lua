require('strict')

--- @module CommLink
--- Renders a Comm-Link page's rehosting notice, previous/next bar, infobox,
--- categories and SEO metadata for {{CommLink}}, stores the page in the
--- `comm_link` Bucket table, and lists it through {{Comm-Link list}}.

local mbox = require('Module:Mbox')
local infobox = require('Module:InfoboxLua')
local button = require('Module:ButtonLua')

local p = {}

local BUCKET = 'comm_link'
--- The Star Citizen Wiki API's reader page for a Comm-Link, keyed by its RSI
--- number. `/api/comm-links/` is the same record as JSON.
local WIKI_API_URL = 'https://api.star-citizen.wiki/comm-links/'
--- Bucket's per-query row cap.
local SERIES_LIMIT = 5000
local TEXT_PARAMS = { 'title', 'series', 'type', 'publicationdate', 'url', 'image' }
local NOTICE_TITLE = 'This page is rehosted content from the Roberts Space Industries website.'
local NOTICE_TEXT = '[https://robertsspaceindustries.com/comm-link Comm-Links] are official communications of '
	.. '[https://cloudimperiumgames.com/ Cloud Imperium Games Corporation] regarding [[Star Citizen]] & '
	.. '[[Squadron 42 (video game)|Squadron 42]]. The Comm-Link is reproduced here with minimal changes '
	.. '(format & wikilinking), as well as translations when available.'

--- @class CommLinkArgs
--- @field title string|nil
--- @field series string|nil
--- @field type string|nil
--- @field publicationdate string|nil
--- @field url string|nil
--- @field image string|nil

--- @class CommLinkRow
--- @field page_name string|nil  Set on rows read back from Bucket and on the page's own row.
--- @field title string|nil
--- @field series string|nil
--- @field type string|nil
--- @field published string|nil  ISO YYYY-MM-DD
--- @field rsi_id number|nil

--- @param value any
--- @return string|nil
local function clean(value)
	if type(value) ~= 'string' then
		return nil
	end
	local trimmed = mw.text.trim(value)
	if trimmed == '' then
		return nil
	end
	return trimmed
end

--- Normalises the template arguments. A blank value counts as absent.
--- @param raw table
--- @return CommLinkArgs
function p.readArgs(raw)
	local args = {}
	for _, name in ipairs(TEXT_PARAMS) do
		args[name] = clean(raw[name])
	end
	return args
end

--- The first year-month-day date in a publication date, zero-padded to
--- YYYY-MM-DD. A value with no such date (`January 2015`) gives nil.
--- @param value string|nil
--- @return string|nil
function p.normaliseDate(value)
	if value == nil then
		return nil
	end
	local year, month, day = value:match('(%d%d%d%d)%-(%d%d?)%-(%d%d?)')
	if year == nil then
		return nil
	end
	return string.format('%s-%02d-%02d', year, tonumber(month), tonumber(day))
end

--- The RSI Comm-Link number in a source URL: the digits (five or more) that
--- open a path segment before a hyphen (`/16835-Far-From-Home`).
--- @param url string|nil
--- @return number|nil
function p.rsiId(url)
	if url == nil then
		return nil
	end
	local digits = url:match('/(%d%d%d%d%d+)%-')
	if digits == nil then
		return nil
	end
	return tonumber(digits)
end

--- The stored row for a Comm-Link.
--- @param args CommLinkArgs
--- @return CommLinkRow
function p.row(args)
	return {
		title = args.title,
		series = args.series,
		type = args.type,
		published = p.normaliseDate(args.publicationdate),
		rsi_id = p.rsiId(args.url),
	}
end

--- @param a CommLinkRow
--- @param b CommLinkRow
--- @return boolean
local function readsBefore(a, b)
	if a.published ~= b.published then
		if a.published == nil or b.published == nil then
			return b.published == nil
		end
		return a.published < b.published
	end
	if a.rsi_id ~= b.rsi_id then
		if a.rsi_id == nil or b.rsi_id == nil then
			return b.rsi_id == nil
		end
		return a.rsi_id < b.rsi_id
	end
	return mw.ustring.lower(a.page_name or '') < mw.ustring.lower(b.page_name or '')
end

--- A series in reading order: by publication date, then RSI number, then page
--- name. A row without a date, or without a number among rows of the same date,
--- sorts after those that have one.
--- @param rows CommLinkRow[]
--- @return CommLinkRow[]  a new table; `rows` keeps its order
function p.orderSeries(rows)
	local ordered = {}
	for i, row in ipairs(rows) do
		ordered[i] = row
	end
	table.sort(ordered, readsBefore)
	return ordered
end

--- The rows either side of a page in an ordered series. The page name matches
--- case-insensitively, as Bucket matches page names.
--- @param ordered CommLinkRow[]
--- @param pageName string
--- @return CommLinkRow|nil before
--- @return CommLinkRow|nil after
function p.neighbours(ordered, pageName)
	local wanted = mw.ustring.lower(pageName)
	for i, row in ipairs(ordered) do
		if row.page_name ~= nil and mw.ustring.lower(row.page_name) == wanted then
			return ordered[i - 1], ordered[i + 1]
		end
	end
	return nil, nil
end

--- Writes the Comm-Link's row. A failed put is ignored so the page still renders.
--- @param args CommLinkArgs
function p.put(args)
	pcall(function()
		mw.ext.bucket(BUCKET).put(p.row(args))
	end)
end

--- Every stored row of the page's series, with the page's own row built from its
--- arguments rather than read: the page is placed by its current date before its
--- row is first written and after an edit changes it. A failed read leaves only
--- the page's own row. Queried directly rather than through Module:BucketQuery,
--- which would load every registered manifest on each Comm-Link page.
--- @param args CommLinkArgs  with `series` set
--- @param pageName string
--- @return CommLinkRow[]
function p.seriesRows(args, pageName)
	local rows = {}
	local ok, stored = pcall(function()
		return mw.ext
			.bucket(BUCKET)
			.select('page_name', 'title', 'published', 'rsi_id')
			.where('series', args.series)
			.limit(SERIES_LIMIT)
			.run()
	end)
	local own = mw.ustring.lower(pageName)
	if ok and type(stored) == 'table' then
		for _, row in ipairs(stored) do
			if type(row.page_name) == 'string' and mw.ustring.lower(row.page_name) ~= own then
				rows[#rows + 1] = {
					page_name = row.page_name,
					title = clean(row.title),
					published = clean(row.published),
					rsi_id = tonumber(row.rsi_id),
				}
			end
		end
	end
	local ownRow = p.row(args)
	ownRow.page_name = pageName
	rows[#rows + 1] = ownRow
	return rows
end

--- The text a neighbour is shown by: its title, else its page name without the
--- namespace.
--- @param row CommLinkRow
--- @return string
local function label(row)
	return row.title or row.page_name:match('^[^:]+:(.+)$') or row.page_name
end

--- The {{Prevnext}} arguments for a page: the previous and next Comm-Link of its
--- series, each only when it exists, around the series name linked to its
--- category.
--- @param before CommLinkRow|nil
--- @param after CommLinkRow|nil
--- @param series string
--- @return table<string, string>
function p.prevnextArgs(before, after, series)
	local args = { title = '[[:Category:' .. series .. '|' .. series .. ']]' }
	if before ~= nil then
		args.prev = before.page_name
		args.prevTitle = label(before)
		args.prevDesc = before.published
	end
	if after ~= nil then
		args.next = after.page_name
		args.nextTitle = label(after)
		args.nextDesc = after.published
	end
	return args
end

--- The rehosting notice text placed above the infobox. `citation` (the
--- {{Cite RSI}} expansion) is nil on a page with no `url`, which drops the
--- "original source" sentence rather than linking a blank URL.
--- @param citation string|nil
--- @return string
function p.noticeText(citation)
	if citation == nil then
		return NOTICE_TEXT
	end
	return NOTICE_TEXT .. ' The original source for this specific Comm-Link can be found at &nbsp;' .. citation
end

--- The infobox footer: a button to the Comm-Link on the RSI website when
--- `url` is set, and one to it on the Star Citizen Wiki API when `url` holds
--- an RSI number. `url` is linked as given: {{Link RSI}}'s normalisation
--- prefixes the RSI domain onto a `www.` or `starcitizen.` RSI URL.
--- @param args CommLinkArgs
--- @return table|nil  a Module:InfoboxLua section, nil without either button
function p.footerSection(args)
	local buttons = {}
	if args.url then
		buttons[#buttons + 1] = button.render({
			label = 'Official site',
			url = args.url,
			icon = 'Sc-icon-brand-rsi.svg',
			class = 't-button--branded t-button--rsi',
		})
	end
	local rsiId = p.rsiId(args.url)
	if rsiId ~= nil then
		buttons[#buttons + 1] = button.render({
			label = 'Wiki API',
			url = WIKI_API_URL .. rsiId,
			icon = 'Star Citizen Wiki API - Logo.svg',
			class = 't-button--branded t-button--wiki-api',
		})
	end
	if #buttons == 0 then
		return nil
	end
	return {
		content = tostring(mw.html.create('div'):addClass('t-infobox-footer-actions'):wikitext(table.concat(buttons))),
		class = 't-infobox-section--footer',
	}
end

--- The InfoboxLua data for {{CommLink}}. Empty fields are omitted rather than
--- shown as "Unknown", unlike the legacy template's ID field.
--- @param args CommLinkArgs
--- @param pageText string  the current page's title, without namespace
--- @return table  Module:InfoboxLua's `data` (see its README)
function p.infoboxData(args, pageText)
	local items = {}
	if args.series then
		items[#items + 1] = { label = 'Series', content = '[[:Category:' .. args.series .. '|' .. args.series .. ']]' }
	end
	if args.type then
		items[#items + 1] = { label = 'Type', content = '[[:Category:' .. args.type .. '|' .. args.type .. ']]' }
	end
	local rsiId = p.rsiId(args.url)
	if rsiId ~= nil then
		items[#items + 1] = { label = 'ID', content = tostring(rsiId) }
	end
	if args.publicationdate then
		items[#items + 1] = { label = 'Published', content = args.publicationdate }
	end

	local sections = {}
	if #items > 0 then
		sections[#sections + 1] = { columns = 2, items = items }
	end
	local footer = p.footerSection(args)
	if footer ~= nil then
		sections[#sections + 1] = footer
	end

	return {
		title = args.title or pageText,
		subtitle = 'Comm-Link',
		image = args.image,
		sections = sections,
	}
end

--- The category wikitext {{CommLink}} places on the page.
--- @param args CommLinkArgs
--- @return string
function p.categories(args)
	local categories = '[[Category:Comm-Link]]'
	if args.type then
		categories = categories .. '[[Category:' .. args.type .. ']]'
	end
	if args.series then
		categories = categories .. '[[Category:' .. args.series .. ']]'
	end
	return categories
end

--- The `#seo` parser function's arguments for a Comm-Link page. The title
--- falls back to `pageText` without a `title` argument, so a page missing the
--- (required) parameter still renders instead of erroring on a nil
--- concatenation; the description keeps its own "This" fallback, matching the
--- legacy template's `{{{title|This}}}`.
--- @param args CommLinkArgs
--- @param locale string  {{PAGELANGUAGE}}, expanded by the caller
--- @param pageText string  the current page's title, without namespace
--- @return table
function p.seoArgs(args, locale, pageText)
	return {
		-- A positional argument is the Lua form of {{#seo:|…}}; callParserFunction throws without one.
		'',
		title = (args.title or pageText) .. ' - Comm-Link Archive - Star Citizen Wiki',
		site_name = 'Star Citizen Wiki',
		type = 'article',
		description = (args.title or 'This') .. ' is part of the Comm-Link Archive on the Star Citizen Wiki.',
		locale = locale,
		image = args.image or 'Placeholderv2.png',
	}
end

--- {{CommLink}}'s previous/next bar, placed before the infobox. Empty without
--- a series.
--- @param frame frame
--- @param args CommLinkArgs
--- @return string
local function seriesBar(frame, args)
	if args.series == nil then
		return ''
	end
	local pageName = mw.title.getCurrentTitle().prefixedText
	local before, after = p.neighbours(p.orderSeries(p.seriesRows(args, pageName)), pageName)
	return frame:expandTemplate({ title = 'Prevnext', args = p.prevnextArgs(before, after, args.series) })
end

--- {{CommLink}}'s entry point: the rehosting notice, the previous/next bar,
--- the infobox, the categories and the page's SEO metadata, and stores the
--- page's row.
--- @param frame frame
--- @return string
function p.main(frame)
	local args = p.readArgs(frame:getParent().args)
	p.put(args)
	local pageText = mw.title.getCurrentTitle().text
	local citation
	if args.url then
		citation =
			frame:expandTemplate({ title = 'Cite RSI', args = { url = args.url, text = args.title or pageText } })
	end
	local notice = mbox.render({
		title = NOTICE_TITLE,
		text = p.noticeText(citation),
		icon = 'WikimediaUI-Notice.svg',
		iconMask = true,
	})
	frame:callParserFunction('#seo', p.seoArgs(args, frame:preprocess('{{PAGELANGUAGE}}'), pageText))
	return notice
		.. seriesBar(frame, args)
		.. frame:extensionTag({ name = 'templatestyles', args = { src = 'Module:CommLink/styles.css' } })
		.. infobox.render(p.infoboxData(args, pageText))
		.. p.categories(args)
end

--- {{Comm-Link list}}'s entry point.
--- @param frame frame
--- @return string
function p.list(frame)
	-- Required here, not at the top: Module:DataGrid loads Module:BucketQuery and
	-- every registered manifest, which a Comm-Link page render does not need.
	return require('Module:DataGrid').main(frame, { primary = BUCKET })
end

return p
