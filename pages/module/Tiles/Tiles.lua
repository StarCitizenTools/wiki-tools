require('strict')

--- @module Tiles
--- Generic image-led grid renderer. Each tile is an image with optional
--- primary/secondary labels overlaid at the bottom, and the entire tile
--- is clickable via a fakelink (a transparent absolutely-positioned
--- [[Page|Text]] wikilink — MediaWiki's sanitizer strips raw <a> tags,
--- so anchors only exist when the parser generates them from wikitext).
---
--- Pure rendering: callers pass fully resolved rows (page, image,
--- labels). Look-up concerns (SMW page resolution, API fetching) live
--- in the caller. This keeps Tiles testable and reusable across
--- unrelated callers — Module:Entity/Related and Module:Entity/UsedBy
--- both consume it but resolve their data differently.

--- @class TilesRow
--- @field page string|nil       Wiki page to link to. Falls back to linkLabel when nil — the tile becomes a red link to the bare name.
--- @field linkLabel string      Accessible text for the wikilink. Screen readers announce this; sighted users see `primary`.
--- @field image string|nil      Image filename without the `File:` prefix. When nil, falls back to `props.placeholderImage`.
--- @field primary string|nil    Prominent label rendered at the bottom of the tile.
--- @field secondary string|nil  Smaller kicker rendered above `primary` (subtitle style).

--- @class TilesProps
--- @field rows TilesRow[]              Rows to render, in order.
--- @field aspectRatio string|nil       CSS `aspect-ratio` value (e.g. `'16 / 9'`, `'3 / 4'`). Defaults to `'1 / 1'` (square).
--- @field tileMinWidth string|nil      CSS length used as the `minmax(<min>, 1fr)` floor for the grid's auto-fill columns. Larger values push each tile wider before another column wraps in. Defaults to `'120px'` — bump it (e.g. `'200px'`) when tiles need to stay legible at a tall aspect ratio.
--- @field placeholderImage string|nil  Fallback image filename when a row has none. Defaults to `'Placeholderv2.png'`.
--- @field imageWidth string|nil        Thumbnail width hint passed to `[[File:…|<width>|link=]]`. Defaults to `'320px'` — large enough to stay crisp on the largest column.

local DEFAULT_PLACEHOLDER = 'Placeholderv2.png'
local DEFAULT_IMAGE_WIDTH = '320px'

local p = {}

--- @param row TilesRow
--- @param placeholderImage string
--- @param imageWidth string
--- @return mw.html|nil
local function renderTile(row, placeholderImage, imageWidth)
	local linkLabel = row.linkLabel
	if not linkLabel or linkLabel == '' then
		-- Without a label we can't construct a wikilink that survives
		-- the sanitizer (the parser needs the [[Page|Text]] form). Skip
		-- the row defensively rather than emit a half-built tile.
		return nil
	end
	local linkPage = row.page
	if not linkPage or linkPage == '' then
		linkPage = linkLabel
	end
	local image = row.image
	if not image or image == '' then
		image = placeholderImage
	end

	local tile = mw.html.create('div'):addClass('t-tiles__tile')
	tile:tag('div'):addClass('t-tiles__link'):wikitext('[[' .. linkPage .. '|' .. linkLabel .. ']]')
	tile:tag('div'):addClass('t-tiles__image'):wikitext('[[File:' .. image .. '|' .. imageWidth .. '|link=]]')

	local hasPrimary = row.primary and row.primary ~= ''
	local hasSecondary = row.secondary and row.secondary ~= ''
	if hasPrimary or hasSecondary then
		local label = tile:tag('div'):addClass('t-tiles__label')
		-- Secondary first so it renders above primary (subtitle above
		-- title), matching the Entity infobox header pattern.
		if hasSecondary then
			label:tag('div'):addClass('t-tiles__secondary'):wikitext(row.secondary)
		end
		if hasPrimary then
			label:tag('div'):addClass('t-tiles__primary'):wikitext(row.primary)
		end
	end

	return tile
end

--- Renders a tile grid from pre-built rows.
---
--- @param props TilesProps
--- @return string
function p.render(props)
	local placeholderImage = props.placeholderImage or DEFAULT_PLACEHOLDER
	local imageWidth = props.imageWidth or DEFAULT_IMAGE_WIDTH

	local grid = mw.html.create('div'):addClass('t-tiles')
	if type(props.aspectRatio) == 'string' and props.aspectRatio ~= '' then
		-- Inline CSS custom property on the grid; styles.css consumes
		-- it via `aspect-ratio: var(--t-tiles-aspect)` on every tile's
		-- image. One inline style per grid is cheaper than per-tile,
		-- and skin overrides can target the grid selector to theme.
		grid:css('--t-tiles-aspect', props.aspectRatio)
	end
	if type(props.tileMinWidth) == 'string' and props.tileMinWidth ~= '' then
		-- Compose the full `repeat(auto-fill, minmax(<min>, 1fr))`
		-- value here because TemplateStyles rejects nested var() inside
		-- minmax() at the property consumer. Custom properties accept
		-- arbitrary tokens, so we hand the assembled value through
		-- `--t-tiles-columns` and let the stylesheet consume it via
		-- bare `var()` on grid-template-columns.
		grid:css('--t-tiles-columns', 'repeat(auto-fill, minmax(' .. props.tileMinWidth .. ', 1fr))')
	end

	if type(props.rows) == 'table' then
		for _, row in ipairs(props.rows) do
			local tile = renderTile(row, placeholderImage, imageWidth)
			if tile then
				grid:node(tile)
			end
		end
	end

	local styles = mw.getCurrentFrame():extensionTag({
		name = 'templatestyles',
		args = { src = 'Module:Tiles/styles.css' },
	})
	return styles .. tostring(grid)
end

return p
