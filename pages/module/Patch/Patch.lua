require('strict')

--- @module Patch
--- Renders a game update page's status bar and page metadata from {{Patch}},
--- and stores the update in the `patch` Bucket table, which neighbouring
--- update pages read for their previous/next dates and {{Patch list}} lists.

local yesno = require('Module:Yesno')

local p = {}

local BUCKET = 'patch'
local DEFAULT_PRODUCT = 'Star Citizen'
local NAMESPACE = 'Update:'
local UNKNOWN = 'Unknown'
local HUB = 'Patch notes'
local STYLES = 'Module:Patch/styles.css'

--- The plain-text parameters of {{Patch}}. `upcoming` is read separately as a
--- yes/no flag.
local TEXT_PARAMS = { 'prev', 'next', 'version', 'build', 'date', 'image', 'product' }

--- @class PatchArgs
--- @field prev string|nil previous update, Update: page name without the namespace
--- @field next string|nil next update, same form
--- @field version string|nil
--- @field build string|nil
--- @field date string|nil ISO YYYY-MM-DD, estimated while upcoming
--- @field upcoming boolean
--- @field image string|nil
--- @field product string

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
--- @return PatchArgs
function p.readArgs(raw)
	local args = {}
	for _, name in ipairs(TEXT_PARAMS) do
		args[name] = clean(raw[name])
	end
	local upcoming = clean(raw.upcoming)
	args.upcoming = upcoming ~= nil and yesno(upcoming, false) == true
	args.product = args.product or DEFAULT_PRODUCT
	return args
end

--- The status label and its modifier class. An upcoming update reads Upcoming
--- even when an estimated date is set. The label is also the stored `status`,
--- which {{Patch list}} sorts descending to list upcoming updates first, so
--- Upcoming must sort after the other labels alphabetically (the grid's text
--- sort).
--- @param args PatchArgs
--- @return string label
--- @return string|nil modifier
function p.status(args)
	if args.upcoming then
		return 'Upcoming', 'upcoming'
	end
	if args.date then
		return 'Released', 'released'
	end
	return UNKNOWN, nil
end

--- The status label's wikitext. For Star Citizen it links to the hub page that
--- lists every update; other products have no hub.
--- @param args PatchArgs
--- @return string
function p.statusText(args)
	local label = p.status(args)
	if args.product == DEFAULT_PRODUCT then
		return '[[' .. HUB .. '|' .. label .. ']]'
	end
	return label
end

--- The line under the status: the date, prefixed "est." while upcoming, then
--- the rendered {{Time ago}}. Empty without a date.
--- @param args PatchArgs
--- @param timeAgo string
--- @return string
function p.description(args, timeAgo)
	if not args.date then
		return ''
	end
	return (args.upcoming and 'est. ' or '') .. args.date .. ' - ' .. timeAgo
end

--- @param args PatchArgs
--- @return string
function p.shortDescription(args)
	local text = args.product .. ' build'
	if args.date then
		text = text .. (args.upcoming and '&nbsp;scheduled for ' or '&nbsp;released on ') .. args.date
	end
	return text
end

--- Star Citizen updates are split by release state; any other product has one
--- category of its own, released or not.
--- @param args PatchArgs
--- @return string
function p.category(args)
	if args.product ~= DEFAULT_PRODUCT then
		return args.product .. ' patch notes'
	end
	return args.upcoming and 'Upcoming patches' or 'Patch notes'
end

--- @param args PatchArgs
--- @return table
function p.row(args)
	return {
		version = args.version,
		build = args.build,
		release_date = args.date,
		upcoming = args.upcoming,
		status = (p.status(args)),
		product = args.product,
	}
end

--- `prev` and `next` always resolve in the Update: namespace.
--- @param name string|nil
--- @return string|nil
function p.neighbourTitle(name)
	if name == nil then
		return nil
	end
	return NAMESPACE .. name
end

--- @param title string
--- @return string
local function key(title)
	return mw.ustring.lower(title)
end

--- Release dates of the given update pages from one Bucket read, keyed by the
--- lowercased page name: Bucket matches page names case-insensitively and
--- returns the stored spelling. Queried directly rather than through
--- Module:BucketQuery, which would load and link every registered manifest on
--- each update page. A failed read returns an empty table.
--- @param titles string[]
--- @return table<string, string>
function p.neighbourDates(titles)
	local dates = {}
	if titles[1] == nil then
		return dates
	end
	local conditions = {}
	for i, title in ipairs(titles) do
		conditions[i] = { 'page_name', title }
	end
	local ok, rows = pcall(function()
		local bucket = mw.ext.bucket
		return bucket(BUCKET).select('page_name', 'release_date').where(bucket.Or(unpack(conditions))).run()
	end)
	if not ok or type(rows) ~= 'table' then
		return dates
	end
	for _, row in ipairs(rows) do
		if type(row.page_name) == 'string' and type(row.release_date) == 'string' and row.release_date ~= '' then
			dates[key(row.page_name)] = row.release_date
		end
	end
	return dates
end

--- @param dates table<string, string>
--- @param title string|nil
--- @return string|nil
function p.dateFor(dates, title)
	if title == nil then
		return nil
	end
	return dates[key(title)]
end

--- Stores the update's row. A failed put is ignored so the page still renders.
--- @param args PatchArgs
function p.store(args)
	pcall(function()
		mw.ext.bucket(BUCKET).put(p.row(args))
	end)
end

--- {{Patch}}'s entry point: stores the row and renders the status bar with the
--- page's category, short description, interlanguage links and SEO metadata.
--- A neighbour's date is read, not tracked: Bucket registers no page
--- dependency, so it shows as of this page's last parse.
--- @param frame table
--- @return string
function p.main(frame)
	local args = p.readArgs(frame:getParent().args)
	p.store(args)

	local prevTitle = p.neighbourTitle(args.prev)
	local nextTitle = p.neighbourTitle(args.next)
	local wanted = {}
	if prevTitle then
		wanted[#wanted + 1] = prevTitle
	end
	if nextTitle then
		wanted[#wanted + 1] = nextTitle
	end
	local dates = p.neighbourDates(wanted)

	local _, modifier = p.status(args)
	local status = mw.html.create('span'):addClass('t-patch-status'):wikitext(p.statusText(args))
	if modifier then
		status:addClass('t-patch-status--' .. modifier)
	end

	local timeAgo = ''
	if args.date then
		local timeArgs = { args.date }
		if args.upcoming then
			timeArgs.magnitude = 'days'
			timeArgs.ago = ''
		end
		timeAgo = frame:expandTemplate({ title = 'Time ago', args = timeArgs })
	end

	local bar = frame:expandTemplate({
		title = 'Prevnext',
		args = {
			prev = prevTitle or '',
			prevTitle = args.prev or '',
			prevDesc = p.dateFor(dates, prevTitle) or UNKNOWN,
			title = tostring(status),
			desc = p.description(args, timeAgo),
			next = nextTitle or '',
			nextTitle = args.next or '',
			nextDesc = nextTitle and (p.dateFor(dates, nextTitle) or UNKNOWN) or '',
		},
	})

	frame:callParserFunction('SHORTDESC', p.shortDescription(args))

	local title = mw.title.getCurrentTitle()
	local seo = {
		-- #seo needs a positional argument (the Lua form of {{#seo:|…}}); callParserFunction throws without one.
		'',
		title = title.text .. ' Update - Star Citizen Wiki',
		site_name = 'Star Citizen Wiki',
		type = 'article',
		locale = frame:preprocess('{{PAGELANGUAGE}}'),
	}
	if args.image then
		seo.image = args.image
		seo.pageimage = args.image
	end
	frame:callParserFunction('#seo', seo)

	return bar
		.. '[[Category:'
		.. p.category(args)
		.. ']]'
		.. frame:expandTemplate({ title = 'Interlanguage links', args = { title.fullText, de = title.text } })
		.. frame:extensionTag({ name = 'templatestyles', args = { src = STYLES } })
end

--- {{Patch list}}'s entry point: Module:DataGrid rooted on the `patch` table,
--- because update pages have no `entity` row and a filter on a joined bucket
--- would make that join INNER. Required here so an update page render does not
--- load the grid.
--- @param frame table
--- @return string
function p.list(frame)
	return require('Module:DataGrid').main(frame, { primary = BUCKET })
end

return p
