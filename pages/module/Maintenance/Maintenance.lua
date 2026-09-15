require('strict')

--- @module Maintenance
--- Records a page's maintenance flag in the `maintenance` Bucket table, and
--- renders the report built from it. The banner templates own the reader-facing
--- box; this module only stores what they were told and lists it back.
---
--- Replaces the `{{#set:Reason=}}` that {{Outdated}} carried "for sake of
--- maintenance datatables" -- tables that were never built, because nothing
--- queried the property.

local DataGrid = require('Module:DataGrid')

-- Resolved at call time, not captured at load: requiring the Bucket library
-- hands back a non-callable copy on the wiki, and a bare `bucket` global fails
-- the undeclared-global scan.
local function bucketLib()
	return mw.ext.bucket
end

local p = {}

local BUCKET = 'maintenance'

--- Every status a banner may record, keyed by the token the banner passes. Kept
--- as data so the reader-facing wording in the banner and the stored value cannot
--- drift apart silently. The first three are {{Outdated}}'s, selected by its own
--- parameters; the last two are whole templates.
local STATUSES = {
	obsolete = 'Obsolete',
	update = 'Needs update',
	outdated = 'Outdated',
	cleanup = 'Needs cleanup',
	delete = 'Proposed for deletion',
}

--- Trims to nil, so a blank template parameter stores nothing rather than an
--- empty string (Bucket keeps '' as a value, which then reads as "has a reason").
---
--- Strip markers are killed first. An editor who cites a source inside `why`
--- (`{{Outdated|Reason=... canceled.<ref>...</ref>}}`) hands the module the
--- parser's placeholder for that ref, not the ref, and storing it puts
--- `UNIQ--ref-...-QINU` in the table where it can never render again (live case:
--- Shepherd MediLift Drone).
--- @param value string|nil
--- @return string|nil
local function clean(value)
	if type(value) ~= 'string' then
		return nil
	end
	value = mw.text.trim(mw.text.killMarkers(value))
	return value ~= '' and value or nil
end

--- The row a set of banner arguments stores. Pure, so the mapping is testable
--- without a Bucket or a page.
--- @param args table status, why, banner
--- @return table|nil row nil when the status is not one this module knows, so a
---   banner passing a typo stores nothing rather than a row the report cannot label
function p.buildRow(args)
	local status = STATUSES[clean(args.status) or '']
	if not status then
		return nil
	end
	return {
		status = status,
		-- No default: a banner that does not name itself is a wiring mistake, and a
		-- row silently attributed to {{Outdated}} would be worse than a blank cell.
		banner = clean(args.banner),
		reason = clean(args.why),
	}
end

--- Stores the row for the current page. Main namespace only, matching
--- Module:Entity/StructuredData: a banner on a /doc or a sandbox is not a
--- maintenance task anyone reports on, and a Bucket row would outlive the test
--- page. Wrapped in pcall so a Bucket failure never takes the banner down.
--- @param row table
--- @return boolean stored
local function put(row)
	if mw.title.getCurrentTitle().namespace ~= 0 then
		return false
	end
	local ok = pcall(function()
		bucketLib()(BUCKET).put(row)
	end)
	return ok
end

--- Entry point for the banner templates. Renders nothing: the banner draws its
--- own box, and this call only records the flag.
--- @param frame mw.frame
--- @return string always empty
function p.record(frame)
	local args = require('Module:Arguments').getArgs(frame)
	local row = p.buildRow(args)
	if row then
		put(row)
	end
	return ''
end

--- Entry point for the report page. Delegates to Module:DataGrid with the base
--- table overridden, because most tagged pages are not Entity pages: a filter on
--- a joined bucket makes that join INNER, so rooting on `entity` would silently
--- drop them. Rooting on `maintenance` instead leaves `entity` a LEFT join, and a
--- page with no Entity row still lists, falling back to its page name.
--- @param frame mw.frame
--- @return string
function p.report(frame)
	return DataGrid.main(frame, { primary = BUCKET })
end

p._internal = { STATUSES = STATUSES, clean = clean, BUCKET = BUCKET }

return p
