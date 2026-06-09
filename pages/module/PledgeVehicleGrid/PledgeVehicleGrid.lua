require('strict')

-- PledgeVehicleGrid: renders the List of pledge vehicles as an AG Grid via the
-- AGGrid extension. Sources every pledge vehicle from SMW (mw.smw.ask), reshapes
-- the results into AG Grid rowData, and returns the grid. Replaces the former
-- `#ask format=datatables` table: same columns, but virtualised rows, rich cells
-- (linked names, thumbnails, loaner link-lists), and REST-served data.
--
-- SMW value handling: mw.smw.ask returns each row as a flat table of *formatted
-- display strings*. Numerics carry units and embed the nbsp as the literal
-- entity text "&#160;", so values are HTML-decoded before being stripped to a
-- number (otherwise the "160" leaks in). Page/file printouts return
-- wikilink/file markup ("[[:100i|100i]]", "[[File:X.png|frameless|...]]"),
-- parsed to titles here. Multi-valued printouts (Loaner) arrive as arrays.

local aggrid = require('mw.ext.aggrid')

local p = {}

-- Source thumbnail width in px. The display size is fixed by styles.css, so this
-- only governs image resolution.
local IMAGE_WIDTH = 120

-- Source width in px for the manufacturer brand glyph in the card eyebrow.
local GLYPH_WIDTH = 40

-- Manufacturer display name -> { code, short }, from the maintained
-- Module:Manufacturers/data.json (keyed CODE -> { name, short }). `code` resolves
-- the brand glyph (File:Sc-icon-brand-<code>.svg); `short` is the compact label
-- shown in the card eyebrow. Built once at module load.
local MANUFACTURER = {}
do
	local ok, data = pcall(mw.loadJsonData, 'Module:Manufacturers/data.json')
	if ok and type(data) == 'table' then
		for code, entry in pairs(data) do
			if type(entry) == 'table' and entry.name then
				MANUFACTURER[entry.name] = { code = tostring(code):lower(), short = entry.short }
			end
		end
	end
end

-- Decode a single scalar SMW value to clean text.
local function decodeScalar(value)
	if type(value) == 'table' then
		value = value.fulltext or value.fullText or value.text or value.label
	end
	if value == nil then
		return nil
	end
	return mw.text.decode(tostring(value), true)
end

-- Map a function over a (possibly multi-valued) SMW result value, joining the
-- decoded results with ", ". Single values pass straight through `fn`.
local function mapJoin(value, fn)
	if type(value) == 'table' and value[1] ~= nil then
		local parts = {}
		for _, v in ipairs(value) do
			local t = decodeScalar(v)
			if t and t ~= '' then
				parts[#parts + 1] = fn(t)
			end
		end
		return table.concat(parts, ', ')
	end
	local s = decodeScalar(value)
	if s == nil then
		return nil
	end
	return fn(s)
end

local function identity(s)
	return s
end

local function toText(value)
	return mapJoin(value, identity)
end

-- Coerce to a number: decode entities first (drops the nbsp "160" leak), then
-- strip currency, units, and grouping separators.
local function toNumber(value)
	if type(value) == 'number' then
		return value
	end
	if type(value) == 'table' and value[1] ~= nil then
		value = value[1]
	end
	local text = decodeScalar(value)
	if text == nil then
		return nil
	end
	return tonumber((text:gsub('[^%d%.%-]', '')))
end

-- Parse "[[:Target|Display]]" (a single SMW page value) into target, display.
local function parseLink(markup)
	if type(markup) == 'table' then
		markup = markup[1]
	end
	local s = decodeScalar(markup)
	if s == nil then
		return nil
	end
	local inner = s:match('^%[%[(.-)%]%]$') or s
	local target = inner:match('^([^|]*)')
	if target then
		target = target:gsub('^:', '')
	end
	if not target or target == '' then
		return nil
	end
	return target, inner:match('|(.*)$')
end

-- Build a linked-thumbnail cell value from "[[File:X.png|frameless|...]]" markup,
-- linked to the row's own page. nil when the file is absent or missing on-wiki.
local function buildThumb(markup, linkTarget)
	if type(markup) == 'table' then
		markup = markup[1]
	end
	local s = decodeScalar(markup)
	if s == nil then
		return nil
	end
	local inner = s:match('^%[%[(.-)%]%]$') or s
	local file = inner:match('^([^|]*)')
	if not file or file == '' then
		return nil
	end
	return aggrid.thumb(file, IMAGE_WIDTH, linkTarget and { link = linkTarget } or nil)
end

-- Build a link-list cell value from a (possibly multi-valued) page printout.
local function buildLinkList(value)
	if value == nil then
		return nil
	end
	local items = (type(value) == 'table' and value[1] ~= nil) and value or { value }
	local targets = {}
	for _, m in ipairs(items) do
		local target = parseLink(m)
		if target then
			targets[#targets + 1] = target
		end
	end
	if #targets == 0 then
		return nil
	end
	return aggrid.linkList(targets)
end

-- Build the structured value for the combined "Vehicle" card cell consumed by the
-- scwEntityCard renderer (SCW gadget): a thumbnail (image), the ship name as the
-- title, and the manufacturer as the eyebrow (text + brand glyph icon). Every
-- file/URL target is resolved server-side here; the renderer only builds DOM from
-- this value. Returns nil when the row has no resolvable page.
local function buildCard(result)
	local nameTarget, nameDisplay = parseLink(result['Name'])
	if not nameTarget then
		return nil
	end
	local nameLink = aggrid.link(nameTarget, nameDisplay)
	local card = {
		title = (nameLink and nameLink.text) or nameDisplay or nameTarget,
		titleHref = nameLink and nameLink.href,
		image = buildThumb(result['Image'], nameTarget),
	}
	local mfrTarget, mfrDisplay = parseLink(result['Manufacturer'])
	if mfrTarget then
		local mfrName = mfrDisplay or mfrTarget
		local info = MANUFACTURER[mfrName]
		-- Compact eyebrow label: the manufacturer's short name, falling back to the
		-- full name. The link still targets the full manufacturer page. The full
		-- name (eyebrowFull) is the set-filter value, so the filter reads in full.
		card.eyebrow = (info and info.short) or mfrName
		card.eyebrowFull = mfrName
		local mfrLink = aggrid.link(mfrTarget, mfrName)
		card.eyebrowHref = mfrLink and mfrLink.href
		-- Brand glyph: best-effort. The renderer paints it as a CSS mask; the media
		-- host sends CORS headers, so the resolved (cross-origin) URL works. A nil
		-- code or missing file yields a text-only eyebrow (aggrid.thumb returns nil).
		if info and info.code then
			card.eyebrowIcon = aggrid.thumb('File:Sc-icon-brand-' .. info.code .. '.svg', GLYPH_WIDTH)
		end
	end
	return card
end

-- Build a stacked-value cell for the scwStackedValue renderer: a primary number
-- over an optional muted secondary (the original price), shown only when it
-- differs from the current. `value` is the raw current number, kept for sort and
-- the number filter; `text`/`sub` are the formatted display lines.
local function buildPriceStack(current, original)
	if current == nil then
		return nil
	end
	local lang = mw.getContentLanguage()
	local stack = { value = current, text = '$' .. lang:formatNum(current) }
	if original ~= nil and original ~= current then
		stack.sub = '$' .. lang:formatNum(original)
	end
	return stack
end

-- Build a badge cell for the scwBadge renderer (BadgeLua-style pill): the text
-- plus an optional BadgeLua variant ('success'/'warning'/'error') looked up from
-- `variants`. Unmapped values render a neutral base badge; an empty value -> nil.
local function buildBadge(text, variants)
	if text == nil or text == '' then
		return nil
	end
	return { text = text, variant = variants and variants[text] }
end

-- Numeric display formats. The extension applies these client-side via Intl on
-- the real number, so the underlying value (and thus sort / filter / set-filter
-- / CSV export) stays numeric -- only the rendered text gains grouping and a
-- unit. `style` is always 'number'; `useGrouping` defaults to true, so thousands
-- separators come for free. Decimals are left unset to preserve each value's
-- natural precision.
local FMT_AUEC = { style = 'number', suffix = ' aUEC' } -- in-game currency
local FMT_METERS = { style = 'number', suffix = ' m' }
local FMT_KG = { style = 'number', suffix = ' kg' }
local FMT_SCU = { style = 'number', suffix = ' SCU' }
local FMT_SPEED = { style = 'number', suffix = ' m/s' }
local FMT_RATE = { style = 'number', suffix = ' °/s' }
local FMT_PLAIN = { style = 'number' } -- grouping only; SMW stores no unit

-- Production state -> BadgeLua variant. Flight ready is done (success); active /
-- long-term production is in progress (warning); concept and SQ42-only states get
-- the neutral base badge (no variant).
local PRODUCTION_VARIANT = {
	['Flight ready'] = 'success',
	['Active production'] = 'warning',
	['Long term production'] = 'warning',
}

-- Column set mirroring the live List of pledge vehicles #ask. `label` is the SMW
-- printout label the result row is keyed by; `field` is the AG Grid field.
-- `kind` selects a rich renderer; `num` marks numeric; `format` is its numeric
-- display spec (see above). `filter` overrides the default column filter -- the
-- low-cardinality categorical columns use the extension's checkbox set filter
-- ('aggridSet'). `w` is an explicit width: the auto-sizing columns ignore it
-- (the grid auto-sizes via autoSizeStrategy; retained so buildColumnDefs can
-- switch back to fixed widths), but the card column uses it because its custom
-- DOM does not auto-size meaningfully.
local COLUMNS = {
	-- One card cell replaces the former Image + Name + Manufacturer columns:
	-- thumbnail + manufacturer eyebrow + ship name. Rendered by the scwEntityCard
	-- column type (SCW gadget); sorts by name, set filter lists manufacturers.
	{ field = 'vehicle', header = 'Vehicle', kind = 'card', filter = 'aggridSet', w = 300 },
	{ field = 'career', label = 'Career', header = 'Career', filter = 'aggridSet', w = 110 },
	{ field = 'role', label = 'Role', header = 'Role', filter = 'aggridSet', w = 180 },
	{ field = 'size', label = 'Size', header = 'Size', filter = 'aggridSet', w = 80 },
	{
		field = 'production',
		label = 'Production state',
		header = 'Production state',
		kind = 'badge',
		variants = PRODUCTION_VARIANT,
		filter = 'aggridSet',
		w = 200,
	},
	{
		field = 'availability',
		label = 'Pledge availability',
		header = 'Pledge availability',
		filter = 'aggridSet',
		w = 140,
	},
	-- Pledge / Warbond each stack the current price over the original (when the
	-- original differs), rendered by the scwStackedValue column type.
	{
		field = 'pledge',
		header = 'Pledge',
		kind = 'priceStack',
		curLabel = 'Pledge',
		origLabel = 'Orig pledge',
		w = 90,
	},
	{
		field = 'warbond',
		header = 'Warbond',
		kind = 'priceStack',
		curLabel = 'Warbond',
		origLabel = 'Orig warbond',
		w = 90,
	},
	{ field = 'loaner', label = 'Loaner', header = 'Loaner', kind = 'linkList', w = 160 },
	{ field = 'avgPrice', label = 'Avg purchase', header = 'Avg purchase', num = true, format = FMT_AUEC, w = 105 },
	{
		field = 'avgRental',
		label = 'Avg daily rental',
		header = 'Avg daily rental',
		num = true,
		format = FMT_AUEC,
		w = 105,
	},
	{ field = 'length', label = 'Length', header = 'Length', num = true, format = FMT_METERS, w = 80 },
	{ field = 'width', label = 'Width', header = 'Width', num = true, format = FMT_METERS, w = 80 },
	{ field = 'height', label = 'Height', header = 'Height', num = true, format = FMT_METERS, w = 80 },
	{ field = 'mass', label = 'Mass', header = 'Mass', num = true, format = FMT_KG, w = 90 },
	{ field = 'minCrew', label = 'Min crew', header = 'Min crew', num = true, w = 80 },
	{ field = 'maxCrew', label = 'Max crew', header = 'Max crew', num = true, w = 80 },
	{ field = 'stowage', label = 'Stowage', header = 'Stowage', num = true, format = FMT_PLAIN, w = 95 },
	{ field = 'cargo', label = 'Cargo', header = 'Cargo', num = true, format = FMT_SCU, w = 80 },
	{ field = 'scm', label = 'SCM speed', header = 'SCM speed', num = true, format = FMT_SPEED, w = 85 },
	{ field = 'maxSpeed', label = 'Max speed', header = 'Max speed', num = true, format = FMT_SPEED, w = 90 },
	{ field = 'roll', label = 'Roll', header = 'Roll', num = true, format = FMT_RATE, w = 75 },
	{ field = 'pitch', label = 'Pitch', header = 'Pitch', num = true, format = FMT_RATE, w = 75 },
	{ field = 'yaw', label = 'Yaw', header = 'Yaw', num = true, format = FMT_RATE, w = 75 },
	{ field = 'conceptDate', label = 'Concept date', header = 'Concept date', w = 110 },
}

local function buildQuery()
	return {
		'[[:+]] [[Category:Pledge ships||Pledge vehicles]]',
		'?Page Image=Image',
		'?=Name',
		'?Manufacturer',
		'?Career',
		'?Role',
		'?Ship matrix size=Size',
		'?Production state#-=Production state',
		'?Pledge availability#-=Pledge availability',
		'?Pledge price#-=Pledge',
		'?Original pledge price#-=Orig pledge',
		'?Warbond pledge price#-=Warbond',
		'?Original warbond pledge price#-=Orig warbond',
		'?Loaner vehicle=Loaner',
		'?Average price=Avg purchase',
		'?Average rental price (1 day)=Avg daily rental',
		'?Entity length#-=Length',
		'?Entity width#-=Width',
		'?Entity height#-=Height',
		'?Mass#-=Mass',
		'?Minimum crew#-=Min crew',
		'?Maximum crew#-=Max crew',
		'?Vehicle inventory#-=Stowage',
		'?Cargo capacity#-=Cargo',
		'?SCM speed#-=SCM speed',
		'?Maximum speed#-=Max speed',
		'?Roll rate#-=Roll',
		'?Pitch rate#-=Pitch',
		'?Yaw rate#-=Yaw',
		'?Concept announcement date#-=Concept date',
		'mainlabel=-',
		'limit=1000',
	}
end

local function buildRowData(results)
	local rows = {}
	for _, result in ipairs(results) do
		local row = {}
		for _, col in ipairs(COLUMNS) do
			if col.kind == 'card' then
				row[col.field] = buildCard(result)
			elseif col.kind == 'priceStack' then
				row[col.field] = buildPriceStack(toNumber(result[col.curLabel]), toNumber(result[col.origLabel]))
			elseif col.kind == 'badge' then
				row[col.field] = buildBadge(toText(result[col.label]), col.variants)
			elseif col.num then
				row[col.field] = toNumber(result[col.label])
			elseif col.kind == 'linkList' then
				row[col.field] = buildLinkList(result[col.label])
			else
				row[col.field] = toText(result[col.label])
			end
		end
		rows[#rows + 1] = row
	end
	return rows
end

-- Shallow-copy a format spec. The FMT_* constants are shared by several columns,
-- but Scribunto's PHP serializer rejects the same table appearing more than once
-- in a structure ("Cannot pass circular reference to PHP"), so each colDef needs
-- its own instance. Values are scalars, so a shallow copy is enough.
local function cloneFormat(fmt)
	if fmt == nil then
		return nil
	end
	local copy = {}
	for k, v in pairs(fmt) do
		copy[k] = v
	end
	return copy
end

local function buildColumnDefs()
	local defs = {}
	for _, col in ipairs(COLUMNS) do
		local def
		if col.kind == 'card' then
			-- The scwEntityCard column type (SCW gadget) supplies the cellRenderer,
			-- the name comparator, and the manufacturer filterValueGetter the set
			-- filter reads. Pin a width and skip auto-sizing: the custom card DOM
			-- does not measure meaningfully under fitCellContents.
			def = {
				field = col.field,
				headerName = col.header,
				type = 'scwEntityCard',
				filter = col.filter or 'aggridSet',
				sortable = true,
				width = col.w,
				suppressAutoSize = true,
			}
		elseif col.kind == 'priceStack' then
			-- scwStackedValue (SCW gadget) renders the stack and supplies the
			-- comparator + filterValueGetter that key on the current price.
			def = {
				field = col.field,
				headerName = col.header,
				type = 'scwStackedValue',
				filter = 'agNumberColumnFilter',
				cellClass = 'ag-right-aligned-cell',
				headerClass = 'ag-right-aligned-header',
				width = col.w,
				suppressAutoSize = true,
			}
		elseif col.kind == 'badge' then
			-- scwBadge (SCW gadget) renders the BadgeLua-style pill; the set filter
			-- and sort key on the badge text via valueFormatter / comparator.
			def = {
				field = col.field,
				headerName = col.header,
				type = 'scwBadge',
				filter = col.filter or 'aggridSet',
				sortable = true,
				width = col.w,
				suppressAutoSize = true,
			}
		elseif col.kind == 'linkList' then
			def = aggrid.linkListColumn({
				field = col.field,
				header = col.header,
				filter = col.filter or 'agTextColumnFilter',
			})
		elseif col.num then
			def = {
				field = col.field,
				headerName = col.header,
				filter = col.filter or 'agNumberColumnFilter',
				type = 'numericColumn',
				format = cloneFormat(col.format),
			}
		else
			def = { field = col.field, headerName = col.header, filter = col.filter or 'agTextColumnFilter' }
		end
		defs[#defs + 1] = def
	end
	return defs
end

--- Entry point. Renders the pledge-vehicle grid.
--- @param frame mw.frame
--- @return string
function p.main(frame)
	local results = mw.smw.ask(buildQuery())
	if type(results) ~= 'table' then
		return '<strong class="error">Module:PledgeVehicleGrid: no results from SMW.</strong>'
	end

	local gridOptions = {
		columnDefs = buildColumnDefs(),
		rowData = buildRowData(results),
		-- No pagination: all vehicles in one virtualised, internally-scrolling
		-- grid. Only the visible rows are ever in the DOM.
		pagination = false,
		-- Row height tuned to the card cell (thumbnail + two text lines).
		rowHeight = 64,
		-- Auto-size plain columns to their content. The custom-rendered columns
		-- (card, stacked prices, badges) opt out via suppressAutoSize and use their `w`.
		autoSizeStrategy = { type = 'fitCellContents' },
		defaultColDef = {
			sortable = true,
			resizable = true,
		},
	}

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:PledgeVehicleGrid/styles.css' },
	})

	return styles .. '<div class="t-pledge-grid">' .. aggrid.render(gridOptions) .. '</div>'
end

return p
