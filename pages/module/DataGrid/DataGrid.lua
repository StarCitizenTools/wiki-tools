require('strict')

--- Generic browse-table component on AG Grid (Extension:AGGrid). Reads through
--- Module:BucketQuery (Bucket): `category` (direct membership, `A; B` for
--- disjunction), `filter` (one clause per line) and `kind` (only needed to
--- disambiguate a property stored per kind) become a Store spec; result rows
--- and manifest types drive the AG Grid rowData + columnDefs.
---
--- Column model: a single card lead (thumbnail + linked name, optional eyebrow
--- from a column flagged `eyebrow`), then one column per editor line. An eyebrow
--- column feeds the lead card and is not emitted as its own column. Each
--- remaining editor column is classified from its manifest type: PAGE becomes a
--- link column (aggridLink), or a link list (aggridLinkList) when repeated; a
--- repeated non-PAGE property becomes a value list; INTEGER/DOUBLE becomes a
--- numeric column; BOOLEAN becomes the tri-state icon column; anything else is
--- plain (the gadget's scwSmart type). `kind=effect|bar|boolean` overrides the
--- classification. A `filter`-flagged column gets the extension's set filter,
--- which splits each cell into one option per value.

local Util = require('Module:AGGridColumns/Util')
local AGGridColumns = require('Module:AGGridColumns')
local aggrid = require('mw.ext.aggrid')
local yesno = require('Module:Yesno')
local BucketQuery = require('Module:BucketQuery')

local p = {}

-- Result-row keys for the lead columns buildSpec adds ahead of the editor's own.
local IMAGE_ALIAS = 'Image'
local NAME_ALIAS = 'Name'
local DISPLAY_ALIAS = 'DisplayName'

--- @class DataGridOptions
--- @field leadImage? boolean  `false` drops the Image lead column and frees its
--- alias for an editor column. Module:DataGrid/Static passes it, because a
--- wikitable's image is a column the editor places; the grid's lead card is the
--- image, so the grid never does.
--- @field primary? string  Base table the Store query roots on, default `entity`.
--- Deliberately not an editor-facing `{{Data table}}` parameter: rooting on the
--- wrong table silently changes which rows exist rather than erroring. A table
--- whose subject is not an Entity page sets it (Module:Maintenance roots on
--- `maintenance`, because filtering a joined bucket makes that join INNER and
--- rooting on `entity` would drop every page with no Entity row).

--- Whether a caller keeps the Image lead column. No options at all is the grid's
--- shape: all three lead columns, `Image` reserved.
--- @param options DataGridOptions|nil
--- @return boolean
local function wantsLeadImage(options)
	return options == nil or options.leadImage ~= false
end

-- `kind=` values Store's manifests disambiguate on.
local KINDS = {
	Vehicle = true,
	Item = true,
	Commodity = true,
	Location = true,
	Mission = true,
	Company = true,
	['Wearable set'] = true,
}

local NUMBER_FORMAT = { style = 'number' }

-- Operator patterns. findOperator (below) picks whichever of these starts
-- earliest in the line, so a relational operator inside the VALUE (e.g. "Name
-- = A<=B") never pre-empts an earlier "=". List order only breaks a tie
-- between two candidates starting at the same position ("<=" over "<", ">="
-- over ">"): longer wins.
local OPERATORS = { '<=', '>=', '!=', '=', '<', '>' }
local NUMERIC_OPS = { ['<'] = true, ['<='] = true, ['>'] = true, ['>='] = true }

-- Lead card geometry. The lead flexes to absorb any leftover horizontal space
-- (the data columns auto-size to content, so short tables would otherwise leave a
-- ragged gap on the right); LEAD_WIDTH is its floor, not a fixed width. Rows are
-- compact when the card is just thumbnail + name, taller when an eyebrow adds a
-- second line.
local LEAD_WIDTH = 260
local ROW_HEIGHT = 48
local EYEBROW_ROW_HEIGHT = 60

--- Strip `[[…]]`/`[[:…]]` wikilink markup to its target, else trim the value as-is.
--- @param value string
--- @return string
local function stripLink(value)
	local inner = value:match('^%[%[:?(.-)%]%]$')
	if inner then
		value = inner:match('^([^|]*)') or inner
	end
	return mw.text.trim(value)
end

--- Wrap an error message in the module's inline-error markup.
--- @param msg string
--- @return string
local function fail(msg)
	return '<strong class="error">Module:DataGrid: ' .. mw.text.nowiki(msg) .. '</strong>'
end

--- @class DataGridColumn
--- @field property string
--- @field label? string
--- @field size? string    Parsed for forward-compatibility; unused (see README).
--- @field filter? boolean
--- @field eyebrow? boolean Promote this column into the lead card's eyebrow.
--- @field kind? string  Override the auto-classified column kind (e.g. `effect`, `bar`).
--- @field good? string  For `kind=bar`: 'higher' | 'lower', the direction that helps.
--- @field group? string  Header this column sits under; consecutive matches nest together.
--- @field prefix? string  For `eyebrow`: joined before the value, no space ("1" -> "S1").
--- @field suffix? string  For `eyebrow`: unit appended after a space ("5" -> "5 charges").
--- @field suffix1? string  The `suffix` to use when the value is exactly 1 ("1 charge").

--- Parse the multi-line `columns` value. Carried over from Module:DataTableLua:
--- one column per non-blank line; within a line, `;`-separated clauses where the
--- first is the property and the rest are modifiers (`label=X`, `size=X`,
--- `kind=X`, `good=higher|lower`, `group=X`, `prefix=X`, `suffix=X`, `suffix1=X`,
--- or the bare flags `filter` / `eyebrow`).
--- `eyebrow` promotes the column into the lead card instead of rendering it as its
--- own column. `good` applies to `kind=bar` only, naming the direction that helps
--- the reader. Unknown clauses are ignored. Empty-property lines drop.
--- @param raw string
--- @return DataGridColumn[]
function p.parseColumns(raw)
	local columns = {}
	for line in (tostring(raw or '') .. '\n'):gmatch('([^\n]*)\n') do
		line = mw.text.trim(line)
		if line ~= '' then
			local column = {}
			local isFirst = true
			for clause in (line .. ';'):gmatch('([^;]*);') do
				clause = mw.text.trim(clause)
				if isFirst then
					column.property = clause
					isFirst = false
				elseif clause ~= '' then
					local key, value = clause:match('^(.-)%s*=%s*(.*)$')
					if key == 'label' then
						column.label = value
					elseif key == 'size' then
						column.size = value
					elseif key == 'kind' then
						column.kind = value
					elseif key == 'good' then
						column.good = value
					elseif key == 'group' then
						column.group = value
					elseif key == 'prefix' then
						column.prefix = value
					elseif key == 'suffix' then
						column.suffix = value
					elseif key == 'suffix1' then
						column.suffix1 = value
					elseif clause == 'filter' then
						column.filter = true
					elseif clause == 'eyebrow' then
						column.eyebrow = true
					end
				end
			end
			if column.property and column.property ~= '' then
				columns[#columns + 1] = column
			end
		end
	end
	return columns
end

--- The result-row key for an editor column: its `label`, else the property name
--- verbatim.
--- @param column DataGridColumn
--- @return string
function p.columnAlias(column)
	if column.label and column.label ~= '' then
		return column.label
	end
	return column.property
end

--- @class DataGridSort
--- @field alias string  The matching column's result-row key (`columnAlias`).
--- @field direction 'asc'|'desc'

--- Parse the `sort` argument: `<label or property> [asc|desc]`, direction
--- defaulting to `asc`. The name matches a column's alias (`columnAlias`) or its
--- raw `property`, so `sort=Subtype` still finds a column relabelled `label=Type`.
--- A name may itself contain spaces (e.g. "Weapon class"), so the whole string is
--- tried as a bare name first; only when that fails is the trailing word split off
--- as the direction. An `eyebrow` column is excluded from matching: it is folded
--- into the lead card rather than getting its own spec, so naming one is an error
--- (`no column named`), not a silent no-op.
--- @param raw string|nil
--- @param columns DataGridColumn[]
--- @return DataGridSort|nil sort  nil for an empty (or absent) `raw`
--- @return string|nil error  ready to display as-is
function p.parseSort(raw, columns)
	raw = mw.text.trim(tostring(raw or ''))
	if raw == '' then
		return nil, nil
	end
	-- An `eyebrow` column is folded into the lead card and never gets its own spec,
	-- so it has nothing for AG Grid to sort; skip it here rather than resolve to an
	-- alias that then matches no spec and silently does nothing.
	local function findAlias(name)
		for _, column in ipairs(columns) do
			if not column.eyebrow then
				local alias = p.columnAlias(column)
				if alias == name or column.property == name then
					return alias
				end
			end
		end
		return nil
	end
	local alias = findAlias(raw)
	if alias then
		return { alias = alias, direction = 'asc' }, nil
	end
	local name, word = raw:match('^(.-)%s+(%S+)$')
	if not name then
		return nil, 'sort "' .. raw .. '": no column named ' .. raw
	end
	alias = findAlias(name)
	if not alias then
		return nil, 'sort "' .. name .. '": no column named ' .. name
	end
	if word ~= 'asc' and word ~= 'desc' then
		return nil, 'sort "' .. word .. '": direction must be asc or desc'
	end
	return { alias = alias, direction = word }, nil
end

--- The first editor column whose alias collides with another column or with a lead
--- key. Store keys rows by alias, so a collision silently drops a column's data.
--- @param columns DataGridColumn[]
--- @param options DataGridOptions|nil
--- @return string|nil  the offending alias, or nil when all are unique
function p.duplicateAlias(columns, options)
	local seen = { [NAME_ALIAS] = true, [DISPLAY_ALIAS] = true }
	if wantsLeadImage(options) then
		seen[IMAGE_ALIAS] = true
	end
	for _, column in ipairs(columns) do
		local alias = p.columnAlias(column)
		if seen[alias] then
			return alias
		end
		seen[alias] = true
	end
	return nil
end

--- Finds the operator a filter line splits on: whichever OPERATORS candidate
--- starts earliest in the line (so an operator-shaped substring inside the
--- VALUE never pre-empts an earlier one, e.g. "Name = A<=B" splits on the
--- first "="); among candidates tied at the same start position, the longest
--- wins ("<=" over "<", "!=" over "=").
--- @param line string
--- @return string|nil op
--- @return integer|nil at  1-based index the match starts at
local function findOperator(line)
	local bestOp, bestAt
	for _, candidate in ipairs(OPERATORS) do
		local at = line:find(candidate, 1, true)
		if at and (bestAt == nil or at < bestAt or (at == bestAt and #candidate > #bestOp)) then
			bestOp, bestAt = candidate, at
		end
	end
	return bestOp, bestAt
end

--- Parse the multi-line `filter` value. One clause per non-blank line:
--- `Property = Value`, `Property = A; B`, `Property != Value`, `Property = +`,
--- `Property <op> Number` for <, <=, >, >=. `||` is also accepted for the Or
--- form (it arrives from an editor's `{{!}}{{!}}`); `;` is preferred because a
--- raw `|` cannot survive inside a template parameter. The property name and
--- every value are entity-decoded, so a `{{PAGENAME}}`-derived value
--- (`Klaus &#38; Werner`) matches Bucket's stored text.
--- A value containing `;` is not expressible: the separator wins.
--- @param raw string|nil
--- @return table[]|nil filters  Store filter entries
--- @return string|nil error  the first line that does not parse
function p.parseFilters(raw)
	local filters = {}
	for line in (tostring(raw or '') .. '\n'):gmatch('([^\n]*)\n') do
		line = mw.text.trim(line)
		if line ~= '' then
			local property, op, rest
			local bestOp, at = findOperator(line)
			if bestOp then
				property, op, rest = mw.text.trim(line:sub(1, at - 1)), bestOp, mw.text.trim(line:sub(at + #bestOp))
				-- Decode BEFORE splitting on ";": an HTML entity's own syntax ends in
				-- ";" (e.g. "&#38;"), so splitting first would fragment it.
				property = mw.text.decode(property, true)
				rest = mw.text.decode(rest, true)
			end
			if not property or property == '' or rest == '' then
				return nil, line
			end
			if op == '=' and rest == '+' then
				filters[#filters + 1] = { property, '+' }
			elseif op == '=' and (rest:find(';', 1, true) or rest:find('||', 1, true)) then
				local any = {}
				for chunk in (rest .. ';'):gmatch('([^;]*);') do
					for part in (chunk .. '||'):gmatch('(.-)||') do
						part = stripLink(part)
						if part ~= '' then
							any[#any + 1] = { property, '=', part }
						end
					end
				end
				if #any == 0 then
					return nil, line
				end
				filters[#filters + 1] = { any = any }
			elseif NUMERIC_OPS[op] then
				local n = tonumber(rest)
				if n == nil then
					return nil, line
				end
				filters[#filters + 1] = { property, op, n }
			else
				filters[#filters + 1] = { property, op, stripLink(rest) }
			end
		end
	end
	return filters, nil
end

--- Parse `category`: names separated by `;` (or legacy `||`, which arrives
--- from an editor's `{{!}}{{!}}`), direct membership only. Names are
--- entity-decoded, so a `{{PAGENAME}}`-derived name matches a real category.
--- @param raw string|nil
--- @return string|table|nil filter
--- @return string|nil error  a part carrying a `|` or `+depth` modifier
function p.parseCategory(raw)
	raw = mw.text.trim(tostring(raw or ''))
	if raw == '' then
		return nil, nil
	end
	-- Decode BEFORE splitting on ";": an HTML entity's own syntax ends in ";"
	-- (e.g. "&#38;"), so splitting first would fragment it.
	raw = mw.text.decode(raw, true)
	local parts = {}
	for chunk in (raw .. ';'):gmatch('([^;]*);') do
		for part in (chunk .. '||'):gmatch('(.-)||') do
			part = mw.text.trim(part)
			if part:find('|', 1, true) or part:find('+depth', 1, true) then
				return nil, part
			end
			if part ~= '' then
				parts[#parts + 1] = 'Category:' .. part
			end
		end
	end
	if #parts == 0 then
		return nil, raw
	end
	if #parts == 1 then
		return parts[1], nil
	end
	return { any = parts }, nil
end

--- The Store spec for a table. Resolves every column so a bad name is an error
--- the editor sees, not an empty column.
--- @param kind string|nil
--- @param categoryFilter string|table|nil
--- @param filters table[]
--- @param columns DataGridColumn[]
--- @param options DataGridOptions|nil
--- @return table|nil spec
--- @return string|nil error
function p.buildSpec(kind, categoryFilter, filters, columns, options)
	local lead = { { builtin = 'page_name', as = NAME_ALIAS } }
	if wantsLeadImage(options) then
		lead[#lead + 1] = { property = 'Image', as = IMAGE_ALIAS }
	end
	lead[#lead + 1] = { property = 'Name', as = DISPLAY_ALIAS }
	local spec = {
		primary = options and options.primary or nil,
		kind = kind,
		filters = {},
		columns = lead,
		limit = 1000,
	}
	if categoryFilter then
		spec.filters[1] = categoryFilter
	end
	for _, f in ipairs(filters) do
		spec.filters[#spec.filters + 1] = f
	end
	-- `op` is given only for a filter clause: a relational operator over a
	-- non-numeric entry or `!=` over a repeated one is a static contract
	-- violation, caught here rather than surfacing as a Store runtime error.
	local function check(property, op)
		local entry = BucketQuery.resolve(property, kind)
		if entry == nil then
			if BucketQuery.needsKind(property) then
				if kind then
					return '"' .. property .. '" is not stored for kind ' .. kind
				end
				return '"'
					.. property
					.. '" lives in a different table per kind; add kind= (Vehicle, Item, Commodity, Location, Mission, Company or Wearable set)'
			end
			return "unknown property '" .. property .. "'"
		end
		if NUMERIC_OPS[op] and entry.type ~= 'INTEGER' and entry.type ~= 'DOUBLE' then
			return '"' .. property .. '" is not numeric; ' .. op .. ' needs a number column'
		end
		if op == '!=' and entry.repeated then
			return '"' .. property .. '" is a list; != cannot be applied'
		end
	end
	for _, column in ipairs(columns) do
		local err = check(column.property)
		if err then
			return nil, err
		end
		spec.columns[#spec.columns + 1] = { property = column.property, as = p.columnAlias(column) }
	end
	for _, f in ipairs(filters) do
		local names = f.any and f.any or { f }
		for _, sub in ipairs(names) do
			local err = check(sub[1], sub[2])
			if err then
				return nil, err
			end
		end
	end
	return spec, nil
end

--- One eyebrow column's value as `{ text, href? }`: a linked label for a PAGE
--- property, else plain text. `page` decides which, since a plain-text
--- property's raw value must never be treated as a page title. No icon — the
--- brand glyph is PledgeVehicleGrid-specific. nil when the value is empty.
---
--- A composed eyebrow strips the column headers that would otherwise say what a
--- number is — "S1 · 1 · Active" tells a reader nothing — so `prefix` and `suffix`
--- put the unit back. They join differently on purpose, matching how each is
--- actually written: `prefix` has NO space, because Star Citizen writes a size as
--- "S1"; `suffix` takes one, because a unit is a separate word ("5 charges",
--- "60 s"). `suffix1` is the singular, used when the value is exactly 1 — most
--- passive modules have one charge, so "1 charges" would be wrong on more rows
--- than it is right.
--- @param result table
--- @param part table  { alias, page, prefix?, suffix?, suffix1? }
--- @return table|nil
local function eyebrowPart(result, part)
	local value = result[part.alias]
	if part.page then
		local target, display = Util.pageTarget(value)
		if target then
			local link = aggrid.link(target, display)
			return {
				text = (link and link.text) or display or target,
				href = link and link.href,
			}
		end
	end
	local text = Util.toText(value)
	if text == nil or text == '' then
		return nil
	end
	local suffix = part.suffix
	if suffix and part.suffix1 and tonumber(text) == 1 then
		suffix = part.suffix1
	end
	if suffix and suffix ~= '' then
		text = text .. ' ' .. suffix
	end
	if part.prefix and part.prefix ~= '' then
		text = part.prefix .. text
	end
	return { text = text }
end

--- The lead card's eyebrow resolver, closed over every `eyebrow` column's key.
--- Several columns compose one line — "Active · 5 charges · 60 s" — so the specs a
--- reader needs to identify a row travel in the lead instead of costing a column
--- each. Only a single part keeps its link: a composed line has no one target.
---
--- `filterPart` is the column the lead's set filter keys on, surfaced separately as
--- `full` (the Card kind's set-filter value). Without it the whole composed line
--- would become the filter option, which is one option per row.
--- @param parts table[]  { alias, page, prefix?, suffix?, suffix1? }
--- @param filterPart table|nil
--- @return fun(result: table): table|nil
local function eyebrowResolver(parts, filterPart)
	return function(result)
		local rendered = {}
		local single
		for _, part in ipairs(parts) do
			local resolved = eyebrowPart(result, part)
			if resolved then
				rendered[#rendered + 1] = resolved.text
				single = (#rendered == 1) and resolved or nil
			end
		end
		if #rendered == 0 then
			return nil
		end
		local text = table.concat(rendered, ' · ')
		local full = text
		if filterPart then
			-- The filter keys on ONE column, not the composed line, which would give an
			-- option per row. It uses that column's DECORATED text, so a size filter
			-- lists "S1" — the term a reader recognises — rather than a bare "1".
			local resolved = eyebrowPart(result, filterPart)
			full = resolved and resolved.text or nil
		end
		return {
			text = text,
			full = full,
			href = single and single.href or nil,
		}
	end
end

--- Build the AGGridColumns column specs for this query: a single card lead
--- (thumbnail + linked name, optional eyebrow), then one spec per editor column,
--- classified from its manifest type. A column flagged `eyebrow` feeds the lead
--- card and is not emitted as its own column.
--- @param results table[]
--- @param columns DataGridColumn[]
--- @param eyebrowColumns DataGridColumn[]
--- @param pinLead boolean
--- @param kind string|nil
--- @param sort DataGridSort|nil  Applied to the spec whose `label` matches `sort.alias`.
--- @return table[]
local function buildSpecs(results, columns, eyebrowColumns, pinLead, kind, sort)
	local leadSpec = {
		kind = 'card',
		field = 'lead',
		header = NAME_ALIAS,
		titleLabel = NAME_ALIAS,
		imageLabel = IMAGE_ALIAS,
		displayLabel = DISPLAY_ALIAS,
		filterOn = 'title',
		filter = 'agTextColumnFilter',
	}
	-- Sizing. Unpinned, the lead grows to fill horizontal slack left by the
	-- content-sized data columns, so rows span the full container instead of ending
	-- short; LEAD_WIDTH floors it. Pinned, it takes that as a FIXED width: a pinned
	-- column lives outside AG Grid's centre viewport, where flex has nothing to flex
	-- against, and the two together leave the column unpinned.
	--
	-- Pinning keeps the lead on screen while the data columns scroll under it.
	-- Sideways scrolling is not what makes a wide table unusable; losing track of
	-- which row you are reading is. Opt-in, because pinning splits the viewport and
	-- draws a divider even when nothing overflows.
	if pinLead then
		leadSpec.pinned = 'left'
		leadSpec.width = LEAD_WIDTH
	else
		leadSpec.flex = 1
		leadSpec.minWidth = LEAD_WIDTH
	end
	if eyebrowColumns[1] then
		local parts, filterPart = {}, nil
		for _, column in ipairs(eyebrowColumns) do
			local entry = BucketQuery.resolve(column.property, kind)
			local part = {
				alias = p.columnAlias(column),
				page = entry.type == 'PAGE',
				prefix = column.prefix,
				suffix = column.suffix,
				suffix1 = column.suffix1,
			}
			parts[#parts + 1] = part
			if column.filter and not filterPart then
				filterPart = part
			end
		end
		leadSpec.eyebrow = eyebrowResolver(parts, filterPart)
		-- A `filter`-flagged eyebrow moves the lead's filter off the name and onto
		-- that value as a checkbox set — "show me only the Active modules". The name
		-- stays searchable through the grid's quickSearch box, so nothing is lost.
		if filterPart then
			leadSpec.filterOn = 'eyebrow'
			leadSpec.filter = 'aggridSet'
		end
	end
	local specs = { leadSpec }
	local groups = { false }
	for i, column in ipairs(columns) do
		if not column.eyebrow then
			groups[#specs + 1] = (column.group ~= nil and column.group ~= '') and column.group or false
			local alias = p.columnAlias(column)
			local header = (column.label and column.label ~= '') and column.label or column.property
			if column.kind == 'effect' then
				-- Dietary-effect badge list: each value classified by Module:DietaryEffect;
				-- the set filter splits the cell into one option per effect.
				specs[#specs + 1] = {
					kind = 'badgeList',
					field = 'c' .. i,
					header = header,
					label = alias,
					classify = require('Module:DietaryEffect').gridClassify,
					filter = 'aggridSet',
				}
			elseif column.kind == 'bar' then
				-- Bars are scaled on the column, so the spec carries the largest
				-- magnitude in it; a per-cell scale would make two rows incomparable,
				-- which is the whole point of drawing them.
				local max = 0
				for _, result in ipairs(results) do
					local n = Util.toNumber(result[alias])
					if n ~= nil and math.abs(n) > max then
						max = math.abs(n)
					end
				end
				specs[#specs + 1] = {
					kind = 'signedBar',
					field = 'c' .. i,
					header = header,
					label = alias,
					good = column.good,
					max = max,
				}
			elseif column.kind == 'boolean' then
				-- Tri-state boolean: each value classified by Module:Boolean,
				-- rendered icon-only; the set filter keys on "Yes"/"No".
				specs[#specs + 1] = {
					kind = 'boolean',
					field = 'c' .. i,
					header = header,
					label = alias,
					filter = 'aggridSet',
				}
			else
				local entry = BucketQuery.resolve(column.property, kind)
				local filter = column.filter and 'aggridSet' or 'agTextColumnFilter'
				local spec = { field = 'c' .. i, header = header, label = alias }
				if entry.type == 'PAGE' then
					spec.kind = entry.repeated and 'linkList' or 'link'
					spec.filter = filter
				elseif entry.repeated then
					spec.kind = 'valueList'
					spec.filter = filter
				elseif entry.type == 'INTEGER' or entry.type == 'DOUBLE' then
					spec.kind = 'number'
					spec.format = NUMBER_FORMAT
					spec.filter = column.filter and 'aggridSet' or nil
				elseif entry.type == 'BOOLEAN' then
					spec.kind = 'boolean'
					spec.filter = 'aggridSet'
				else
					spec.kind = 'smart'
					spec.filter = filter
				end
				specs[#specs + 1] = spec
			end
		end
	end
	-- Every kind's buildColDef passes `sort` through to AG Grid's initial-sort key,
	-- so setting it on the matching spec is enough regardless of column kind.
	if sort then
		for i = 2, #specs do
			if specs[i].label == sort.alias then
				specs[i].sort = sort.direction
				break
			end
		end
	end
	return specs, groups
end

--- Nest runs of consecutive columns that share a `group` into AG Grid column
--- groups. Grouping is what turns nine unfamiliar stat names into the two or three
--- questions a reader actually has ("what does the rock do", "what do I take
--- home"), so it is a header row, not decoration.
---
--- Only CONSECUTIVE matches nest: a group is a position in the table, and letting
--- non-adjacent columns join one would silently reorder the editor's columns.
--- @param defs table[]
--- @param groups (string|false)[]  aligned with defs
--- @return table[]
local function groupColumnDefs(defs, groups)
	local out = {}
	local i = 1
	while i <= #defs do
		local group = groups[i]
		if not group then
			out[#out + 1] = defs[i]
			i = i + 1
		else
			local children = {}
			while i <= #defs and groups[i] == group do
				children[#children + 1] = defs[i]
				i = i + 1
			end
			out[#out + 1] = { headerName = group, children = children }
		end
	end
	return out
end

--- Runs the Store query, catching a Bucket infrastructure failure (a
--- QueryException, the per-query execution limit, the per-page budget, or an
--- unregistered bucket during a staged deploy) instead of letting it
--- script-error the page: every programming mistake (an unknown property, a
--- bad operator) is already caught by buildSpec before this runs, so a
--- failure here is infrastructure, not an editing mistake. An Rdbms
--- DBQueryError (the self-join class) is not catchable from Lua and still
--- propagates.
--- @param spec table
--- @return table[]|nil results
--- @return string|nil err
function p.runQuery(spec)
	local ok, results = pcall(BucketQuery.query, spec)
	if not ok then
		return nil, results
	end
	return results, nil
end

--- Sort query results by the `Name` alias (the `page_name` builtin), byte
--- comparison, so a table opens in page-title order (Bucket otherwise returns
--- store order). AG Grid's initial `sort=` sort overrides the visible order
--- regardless, so this is unconditional.
--- @param results table[]
--- @return table[] results  the same table, sorted in place
function p.sortRows(results)
	table.sort(results, function(a, b)
		return (a[NAME_ALIAS] or '') < (b[NAME_ALIAS] or '')
	end)
	return results
end

--- @class DataGridRequest
--- @field spec table  the Module:BucketQuery query spec
--- @field columns DataGridColumn[]  the editor's columns, in order
--- @field kind string|nil
--- @field sort DataGridSort|nil

--- Resolve a {{Data table}} argument table into the Store spec and the parsed
--- columns. Every contract violation comes back as a ready-to-display message,
--- in the order an editor meets them (unsupported argument, kind, category,
--- filter, columns, properties, sort). Shared with Module:DataGrid/Static so the
--- two templates accept one grammar and report one set of failures; `options`
--- is how that caller drops the Image lead column it renders itself.
--- @param args table
--- @param options DataGridOptions|nil  passed on to duplicateAlias and buildSpec
--- @return DataGridRequest|nil request
--- @return string|nil error
function p.resolveArgs(args, options)
	if args.conditions and mw.text.trim(args.conditions) ~= '' then
		return nil, '"conditions" is not supported; use "filter" (see Template:Data table)'
	end

	local kind = mw.text.trim(args.kind or '')
	if kind == '' then
		kind = nil
	elseif not KINDS[kind] then
		return nil, 'unknown kind "' .. kind .. '"'
	end

	local categoryFilter, badCategory = p.parseCategory(args.category)
	if badCategory then
		return nil, 'category "' .. badCategory .. '": use plain names separated by ";"; membership is direct only'
	end

	local filters, badLine = p.parseFilters(args.filter)
	if badLine then
		return nil,
			'filter line "'
				.. badLine
				.. '" is not Property = Value, Property = A; B, Property != Value, Property = + or Property <op> Number'
	end

	if not categoryFilter and #filters == 0 then
		return nil, 'provide "category" or "filter"'
	end

	local columns = p.parseColumns(args.columns)
	if #columns == 0 then
		return nil, 'no columns defined'
	end

	local duplicate = p.duplicateAlias(columns, options)
	if duplicate then
		return nil, 'duplicate column "' .. duplicate .. '"'
	end

	local spec, badSpec = p.buildSpec(kind, categoryFilter, filters, columns, options)
	if badSpec then
		return nil, badSpec
	end

	local sort, badSort = p.parseSort(args.sort, columns)
	if badSort then
		return nil, badSort
	end

	return { spec = spec, columns = columns, kind = kind, sort = sort }, nil
end

--- Entry point for {{Data table}}. Reads `category`, `filter`, `kind`, `columns`,
--- `pinlead` and `sort` from the parent frame, runs the Store query, builds the
--- grid, and returns it preceded by the styles load.
--- @param frame mw.frame
--- @param options DataGridOptions|nil  Caller-side options; {{Data table}} passes
--- none. A module wrapping this one uses it to set `primary` (Module:Maintenance).
--- @return string
function p.main(frame, options)
	local getArgs = require('Module:Arguments').getArgs
	local args = getArgs(frame)

	local request, badArgs = p.resolveArgs(args, options)
	if badArgs then
		return fail(badArgs)
	end
	local columns, kind, sort = request.columns, request.kind, request.sort

	-- Every `eyebrow` column composes the lead card's second line, in the order the
	-- editor wrote them.
	local eyebrowColumns = {}
	for _, column in ipairs(columns) do
		if column.eyebrow then
			eyebrowColumns[#eyebrowColumns + 1] = column
		end
	end
	local pinLead = yesno(args.pinlead, false)

	local results, queryErr = p.runQuery(request.spec)
	if queryErr then
		return fail('the query could not be run: ' .. tostring(queryErr))
	end
	p.sortRows(results)

	local specs, groups = buildSpecs(results, columns, eyebrowColumns, pinLead, kind, sort)
	local gridOptions = {
		columnDefs = groupColumnDefs(AGGridColumns.buildColumnDefs(specs), groups),
		rowData = AGGridColumns.buildRowData(results, specs),
		quickSearch = true,
		expand = true,
		pagination = false,
		rowHeight = eyebrowColumns[1] and EYEBROW_ROW_HEIGHT or ROW_HEIGHT,
		autoSizeStrategy = { type = 'fitCellContents' },
		defaultColDef = { sortable = true, resizable = true },
	}

	local styles = frame:extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:DataGrid/styles.css' },
	})

	return styles .. '<div class="t-datagrid">' .. aggrid.render(gridOptions) .. '</div>'
end

-- Test-only exports. Not part of the public API.
p._internal = {
	buildSpecs = buildSpecs,
	groupColumnDefs = groupColumnDefs,
	eyebrowResolver = eyebrowResolver,
}

return p
