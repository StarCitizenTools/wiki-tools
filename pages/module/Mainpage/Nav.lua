require('strict')

--- @module Mainpage/Nav
--- The page's two link lists — the hero's chip strip and the directory at the
--- foot — and the one function that turns a settings entry into wikitext.
---
--- Loading belongs to Module:Mainpage/Config; this module only shapes what
--- comes back. It exists separately because rendering a link is a concern of
--- its own: two callers need the same treatment of internal versus external
--- targets, and neither should have to know how a settings entry is spelled.

local cfg = require('Module:Mainpage/Config')

local p = {}

--- @class NavLink
--- @field page? string   Internal target. Mutually exclusive with `url`.
--- @field url? string    External target. Mutually exclusive with `page`.
--- @field label? string  Display text. Optional for `page`, required for `url`.

--- Renders one link as wikitext rather than as an <a> element, so MediaWiki
--- builds the href, applies the cached page-existence class (a red link stays
--- visibly red here), and picks up the reader's language variant.
---
--- An external link is emitted in single-bracket form; suppressing its arrow
--- icon is the caller's job, by putting `plainlinks` on the containing
--- element.
---
--- @param link NavLink
--- @return string|nil  nil when the entry names no target at all
function p.renderLink(link)
	if link.url and link.url ~= '' then
		return string.format('[%s %s]', link.url, link.label or link.url)
	end

	if not link.page or link.page == '' then
		return nil
	end

	if link.label and link.label ~= '' and link.label ~= link.page then
		return string.format('[[%s|%s]]', link.page, link.label)
	end

	return string.format('[[%s]]', link.page)
end

--- True when any entry in the group points off-wiki, which is what decides
--- whether the group needs `plainlinks`. Checked per group rather than applied
--- to the whole directory so an all-internal group is not given a class that
--- does nothing.
---
--- @param links NavLink[]
--- @return boolean
function p.hasExternal(links)
	for _, link in ipairs(links) do
		if link.url and link.url ~= '' then
			return true
		end
	end
	return false
end

--- The hero's chip strip.
--- @return NavLink[]
function p.chips()
	return cfg.list('chips')
end

--- The foot directory, as a list of { label, links } groups.
--- @return table[]
function p.directory()
	return cfg.list('directory')
end

return p
