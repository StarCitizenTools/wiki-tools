require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Tiles = require('Module:Tiles')

local suite = ScribuntoUnit:new()

function suite:testRenderMarksSelectedTile()
	local html = Tiles.render({
		rows = {
			{ page = 'Aurora ES', linkLabel = 'Aurora ES', selected = true },
			{ page = 'Aurora MR', linkLabel = 'Aurora MR' },
		},
	})
	self:assertStringContains('t-tiles__tile--selected', html, true)
end

function suite:testRenderOmitsSelectedClassByDefault()
	local html = Tiles.render({ rows = { { page = 'Aurora MR', linkLabel = 'Aurora MR' } } })
	self:assertNotStringContains('t-tiles__tile--selected', html, true)
end

-- A consumer's geometry reaches the stylesheet only through these two custom
-- properties; tileMinWidth is composed into the whole repeat() value because
-- TemplateStyles rejects a nested var() inside minmax().
function suite:testRenderEmitsGeometryCustomProperties()
	local html = Tiles.render({
		rows = { { page = 'Aurora MR', linkLabel = 'Aurora MR' } },
		aspectRatio = '16 / 9',
		tileMinWidth = '240px',
	})
	self:assertStringContains('--t-tiles-aspect:16 / 9', html, true)
	self:assertStringContains('--t-tiles-columns:repeat(auto-fill, minmax(240px, 1fr))', html, true)
end

function suite:testRenderOmitsGeometryCustomPropertiesByDefault()
	local html = Tiles.render({ rows = { { page = 'Aurora MR', linkLabel = 'Aurora MR' } } })
	self:assertNotStringContains('--t-tiles-aspect', html, true)
	self:assertNotStringContains('--t-tiles-columns', html, true)
end

function suite:testRenderSkipsRowWithoutLinkLabel()
	local html = Tiles.render({ rows = { { page = 'Aurora MR' } } })
	self:assertNotStringContains('t-tiles__tile', html, true)
end

-- CSS assertion, not a rendered-output one: nothing in Tiles.render's HTML
-- proves the `selected` class actually paints differently (that needs a
-- computed-style check against a live/sandboxed page, out of this suite's
-- reach). This only guards the two files staying in sync: Tiles/styles.css
-- (not a consumer's own stylesheet) must own the rule for the class this
-- module emits, compounded with the base tile
-- selector so it beats .t-tiles__tile's `border` shorthand on specificity
-- rather than losing to it on source order.
--
-- `_G.io` (not the bare `io` global): tests/lint-globals.sh's GETGLOBAL scan
-- has no testcases.lua exemption for this check (only for the separate
-- mw.ext.bucket require check), and `io` isn't in its Scribunto-sandbox
-- allowlist — reading local files is meaningless on the live wiki and this
-- file never deploys there anyway, but the indirection keeps the scan green.
function suite:testStylesheetOwnsSelectedModifierRule()
	local root = os.getenv('REPO_ROOT') or '.'
	local path = root .. '/pages/module/Tiles/styles.css'
	local file = _G.io.open(path, 'r')
	self:assertTrue(file ~= nil, 'could not open ' .. path)
	local css = file:read('*a')
	file:close()
	self:assertStringContains('.t-tiles__tile.t-tiles__tile--selected', css, true)
end

return suite
