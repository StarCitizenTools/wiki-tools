require('strict')

--- Static counterpart of Module:DataGrid: the same {{Data table}} grammar
--- (`category`, `filter`, `kind`, `columns`, `sort`) and the same
--- Module:BucketQuery query, rendered as a plain wikitable instead of an AG Grid.
--- Every row reaches the parser output, so browser find reaches all of them, and a
--- stored value's own wikitext ("50x [[Council Scrip]]") renders as the link it is.
---
--- Cells are classified from the property's Bucket type, mirroring
--- Module:DataGrid's column dispatch: PAGE becomes a wikilink (comma-separated
--- when repeated), a repeated non-PAGE property one item per line, INTEGER and
--- DOUBLE a grouped number, BOOLEAN a Yes/No, and anything else the stored value
--- verbatim so the parser renders whatever wikitext it carries.
---
--- The page name is the one lead column. Unlike the grid, which carries the page
--- image in a lead card, an image here is an ordinary column the editor places
--- among the others, or leaves out.

local DataGrid = require('Module:DataGrid')
local BucketQuery = require('Module:BucketQuery')
local Util = require('Module:AGGridColumns/Util')
local yesno = require('Module:Yesno')

local p = {}

-- Result-row keys of the two lead columns Module:DataGrid's buildSpec adds here.
local NAME_ALIAS = 'Name'
local DISPLAY_ALIAS = 'DisplayName'

-- The grid's third lead column, the page image, is opted out of: an image belongs
-- wherever the editor's own columns put it, and a table may want none at all.
local RESOLVE_OPTIONS = { leadImage = false }

-- Where Module:BucketQuery keeps the page image. A column is the image column
-- when it resolves to this bucket and field, not when it is spelled `Image`, so
-- `Image ; label=Picture` still renders as a thumbnail.
local IMAGE_BUCKET = 'entity'
local IMAGE_FIELD = 'image'

-- Requested thumbnail width; styles.css caps the rendered image to the same 200px.
local IMAGE_WIDTH = '200px'

--- Whether a resolved column holds the page image.
--- @param entry StoreEntry|nil
--- @return boolean
local function isImageColumn(entry)
	return entry ~= nil and entry.bucket == IMAGE_BUCKET and entry.field == IMAGE_FIELD
end

--- Wrap an error message in the module's inline-error markup.
--- @param msg string
--- @return string
local function fail(msg)
	return '<strong class="error">Module:DataGrid/Static: ' .. mw.text.nowiki(msg) .. '</strong>'
end

--- A wikilink to `target`, piped only when `display` differs from it.
--- @param target string
--- @param display string|nil
--- @return string
local function wikilink(target, display)
	if display and display ~= '' and display ~= target then
		return '[[' .. target .. '|' .. display .. ']]'
	end
	return '[[' .. target .. ']]'
end

--- A PAGE cell: one wikilink, or a comma-separated list for a repeated property.
--- Values are bare page titles; pageTarget also accepts the `[[:Target|Display]]`
--- markup an older writer may have stored.
--- @param value any
--- @return string
local function pageCell(value)
	local items = (type(value) == 'table' and value[1] ~= nil) and value or { value }
	local parts = {}
	for _, item in ipairs(items) do
		local target, display = Util.pageTarget(item)
		if target then
			parts[#parts + 1] = wikilink(target, display)
		end
	end
	return table.concat(parts, ', ')
end

--- A repeated non-PAGE cell: one value per line. These are whole statements, not
--- tags — a hauling contract's cargo lines, a reward manifest — so a comma-joined
--- run-on would be read as one sentence. Each value is emitted verbatim, so the
--- wikitext inside it ("50x [[Council Scrip]]") renders.
--- @param value any
--- @return string
local function listCell(value)
	local items = (type(value) == 'table' and value[1] ~= nil) and value or { value }
	local lines = {}
	for _, item in ipairs(items) do
		local text = Util.decodeScalar(item)
		if text and text ~= '' then
			lines[#lines + 1] = text
		end
	end
	return table.concat(lines, '<br>')
end

--- A number cell, grouped in the content language ("1,000"). A value that is not
--- a number falls back to its text, so a manifest/stored-type mismatch shows the
--- value instead of a zero.
--- @param value any
--- @return string
local function numberCell(value)
	local n = Util.toNumber(value)
	if n == nil then
		return Util.toText(value) or ''
	end
	return mw.language.getContentLanguage():formatNum(n)
end

--- One cell's wikitext, dispatched on the property's Bucket type in the same
--- order as Module:DataGrid's column classification. BOOLEAN renders as the words
--- Yes/No rather than the grid's icon: this table exists to be searchable, and an
--- icon is not text browser find can reach.
--- @param entry StoreEntry
--- @param value any
--- @return string
local function cell(entry, value)
	if value == nil then
		return ''
	end
	if entry.type == 'PAGE' then
		return pageCell(value)
	elseif entry.repeated then
		return listCell(value)
	elseif entry.type == 'INTEGER' or entry.type == 'DOUBLE' then
		return numberCell(value)
	elseif entry.type == 'BOOLEAN' then
		local flag = yesno(value)
		if flag == nil then
			-- An unparseable value is shown rather than dropped, matching
			-- numberCell: a reader can see what is stored, and the cell does not
			-- read as "no value".
			return Util.decodeScalar(value) or ''
		end
		return flag and 'Yes' or 'No'
	end
	return Util.decodeScalar(value) or ''
end

--- The image cell: a thumbnail linked to the row's page. Guarded the way
--- Module:Entity/Base guards the title it stores, because a stored filename the
--- wikitext parser tolerates but Title validation rejects (one carrying a literal
--- %27, say) would otherwise error the whole table; an unusable name drops its own
--- cell instead.
--- @param value any
--- @param page string
--- @return string
local function imageCell(value, page)
	local file = Util.decodeScalar(value)
	if file == nil then
		return ''
	end
	file = file:gsub('^[Ff]ile:', '')
	if file == '' or page == '' or not mw.title.new('File:' .. file) then
		return ''
	end
	return '[[File:' .. file .. '|' .. IMAGE_WIDTH .. '|link=' .. page .. ']]'
end

--- Order rows by the `sort` column, the static equivalent of the grid's initial
--- sort: a wikitable is served in row order, and the sortable-table script leaves
--- that order alone until a reader clicks a header. Keys are precomputed and
--- compared as numbers only when every present value is one, since a comparator
--- that switches between number and string ordering raises "invalid order
--- function". Ties keep page-title order, which table.sort would otherwise shuffle.
--- @param results table[]
--- @param sort DataGridSort
--- @return table[] results  the same table, sorted in place
local function applySort(results, sort)
	local numeric = true
	for _, row in ipairs(results) do
		local value = row[sort.alias]
		if value ~= nil and Util.toNumber(value) == nil then
			numeric = false
			break
		end
	end
	local keys = {}
	for _, row in ipairs(results) do
		local value = row[sort.alias]
		keys[row] = numeric and (Util.toNumber(value) or -math.huge) or (Util.toText(value) or '')
	end
	table.sort(results, function(a, b)
		if keys[a] ~= keys[b] then
			if sort.direction == 'desc' then
				return keys[b] < keys[a]
			end
			return keys[a] < keys[b]
		end
		return (a[NAME_ALIAS] or '') < (b[NAME_ALIAS] or '')
	end)
	return results
end

--- Build the wikitable: the page name, then one column per editor column, one row
--- per result. Properties resolve once per column rather than once per cell, and a
--- column resolving to the page image renders as a linked thumbnail wherever the
--- editor put it, under its own header text.
--- @param results table[]
--- @param columns DataGridColumn[]
--- @param kind string|nil
--- @return string
local function buildTable(results, columns, kind)
	local aliases, entries = {}, {}
	local root = mw.html.create('table'):addClass('wikitable'):addClass('sortable')
	local header = root:tag('tr')
	header:tag('th'):wikitext(NAME_ALIAS)
	for i, column in ipairs(columns) do
		aliases[i] = DataGrid.columnAlias(column)
		entries[i] = BucketQuery.resolve(column.property, kind)
		local th = header:tag('th')
		-- Sorting on image markup means nothing, so that column opts out.
		if isImageColumn(entries[i]) then
			th:addClass('unsortable')
		end
		th:wikitext(aliases[i])
	end
	for _, row in ipairs(results) do
		local page = row[NAME_ALIAS] or ''
		local tr = root:tag('tr')
		-- A page whose stored name differs from its title (Dragonfly Black) shows the
		-- stored name while the link still targets the page itself.
		local display = Util.decodeScalar(row[DISPLAY_ALIAS])
		tr:tag('td'):wikitext(page ~= '' and wikilink(page, display) or (display or ''))
		for i in ipairs(columns) do
			local value = row[aliases[i]]
			if isImageColumn(entries[i]) then
				tr:tag('td'):addClass('t-datagrid-static__image'):wikitext(imageCell(value, page))
			else
				tr:tag('td'):wikitext(cell(entries[i], value))
			end
		end
	end
	return tostring(root)
end

--- Entry point for {{Data table/static}}. Reads the same arguments as
--- {{Data table}} through Module:DataGrid's resolveArgs, runs the Store query, and
--- returns the wikitable preceded by the styles load. `pinlead` is accepted and
--- ignored: it pins the grid's lead card, which a wikitable does not have.
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local getArgs = require('Module:Arguments').getArgs
	local args = getArgs(frame)

	local request, badArgs = DataGrid.resolveArgs(args, RESOLVE_OPTIONS)
	if badArgs then
		return fail(badArgs)
	end

	local results, queryErr = DataGrid.runQuery(request.spec)
	if queryErr then
		return fail('the query could not be run: ' .. tostring(queryErr))
	end
	DataGrid.sortRows(results)
	if request.sort then
		applySort(results, request.sort)
	end

	local styles = frame:extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:DataGrid/Static/styles.css' },
	})

	return styles .. '<div class="t-datagrid-static">' .. buildTable(results, request.columns, request.kind) .. '</div>'
end

-- Test-only exports. Not part of the public API.
p._internal = {
	buildTable = buildTable,
	applySort = applySort,
	fail = fail,
}

return p
