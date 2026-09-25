require('strict')

--- @module CommLink
--- Stores each Comm-Link from {{Infobox commlink}} in the `comm_link` Bucket
--- table, renders the previous/next bar of its series from it, and lists it
--- through {{Comm-Link list}}.

local p = {}

local BUCKET = 'comm_link'
--- Bucket's per-query row cap.
local SERIES_LIMIT = 5000
local TEXT_PARAMS = { 'title', 'series', 'type', 'publicationdate', 'url' }

--- @class CommLinkArgs
--- @field title string|nil
--- @field series string|nil
--- @field type string|nil
--- @field publicationdate string|nil
--- @field url string|nil

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

--- {{Infobox commlink}}'s store call: writes the page's row.
--- @param frame frame
--- @return string
function p.store(frame)
	p.put(p.readArgs(frame:getParent().args))
	return ''
end

--- {{Infobox commlink}}'s previous/next bar, placed before the infobox. Empty
--- without a series.
--- @param frame frame
--- @return string
function p.series(frame)
	local args = p.readArgs(frame:getParent().args)
	if args.series == nil then
		return ''
	end
	local pageName = mw.title.getCurrentTitle().prefixedText
	local before, after = p.neighbours(p.orderSeries(p.seriesRows(args, pageName)), pageName)
	return frame:expandTemplate({ title = 'Prevnext', args = p.prevnextArgs(before, after, args.series) })
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
