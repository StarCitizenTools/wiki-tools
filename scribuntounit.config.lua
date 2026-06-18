-- SPDX-License-Identifier: MIT
--- Consumer config for mediawiki-scribuntounit (the off-wiki ScribuntoUnit runner).
--- Declares where this wiki's modules live plus the wiki-specific stubs and
--- extensions the generic runner cannot know about. The generic mw.* surface
--- (mw.html/text/uri + ustring/language/title/site shims) is provided by the lib.
return {
	moduleRoot = 'pages/module',

	-- Scribunto lualib ref the runner fetches (mw.html/text/uri fidelity is pinned
	-- to this MediaWiki release). Overridable via the SCRIBUNTO_REF env var.
	scribunto = { ref = 'REL1_43' },

	-- Render primitives: visual / HTML-building modules whose render() returns
	-- opaque strings consumed by facet getSections(); stubbed inert (every method
	-- → '') so suites that only need a string back don't need a render pipeline.
	-- A module that ships its own testcases.lua is loaded for real regardless.
	stubs = {
		'ProgressTiles',
		'RangeBar',
		'MeterBar',
		'FalloffChart',
		'Tiles',
		'Dimensions',
		'Dimensions/presets',
		'Rarity',
		'CardLua',
		'CollapsibleCard',
		'TableLua',
		'ButtonLua',
		'InfoboxLua',
		'Details',
	},

	setup = function(api)
		-- Module:Yesno — boolean conversion (not in this repo).
		api.stub('Yesno', function(v, default)
			if v == nil then
				return default
			end
			if type(v) == 'boolean' then
				return v
			end
			local s = tostring(v):lower()
			if s == 'yes' or s == 'true' or s == '1' then
				return true
			end
			if s == 'no' or s == 'false' or s == '0' then
				return false
			end
			return default
		end)

		-- Module:BadgeLua — echoes its text so Module:Rarity's badge test exercises
		-- the resolve→label logic; BadgeLua's own HTML is out of scope.
		api.stub('BadgeLua', {
			render = function(opts)
				return tostring((type(opts) == 'table' and opts.text) or '')
			end,
		})

		-- Module:list — list builder (not in this repo). Faithful enough for the
		-- multi-value display logic: makeList returns a <ul> of the positional
		-- items; named options (list_style, etc.) are ignored in the stub. The
		-- real list markup is verified on-wiki / in the browser.
		api.stub('list', {
			makeList = function(_, args)
				local html = mw.html.create('ul')
				for _, item in ipairs(args) do
					html:tag('li'):wikitext(item)
				end
				return tostring(html)
			end,
		})

		-- mw.ext.aggrid — require-able stand-in for the AGGrid extension, required
		-- at load time by Module:AGGridColumns / Module:DataGrid. Their suites assert
		-- pure logic, so the builders only need to exist and return plausible shapes.
		api.preload('mw.ext.aggrid', function()
			local aggrid = {}
			local function column(o, columnType)
				o = o or {}
				return {
					field = o.field,
					headerName = o.header,
					type = columnType,
					filter = o.filter,
					sortable = o.sortable,
					width = o.width,
					suppressAutoSize = o.suppressAutoSize,
				}
			end
			function aggrid.imageColumn(o)
				return column(o, 'aggridImage')
			end
			function aggrid.linkColumn(o)
				return column(o, 'aggridLink')
			end
			function aggrid.linkListColumn(o)
				return column(o, 'aggridLinkList')
			end
			function aggrid.link(target, display)
				return { text = display or target, href = target }
			end
			function aggrid.thumb(file, width, opts)
				return { file = file, width = width, link = opts and opts.link }
			end
			function aggrid.linkList(targets)
				return { links = targets }
			end
			function aggrid.render()
				return ''
			end
			function aggrid.register() end
			return aggrid
		end)
	end,
}
