require('strict')

local p = {}

-- Extensions probed for an auto-discovered infobox image, in priority order.
-- WebP first (house format), then the common screenshot formats. The gadget
-- normalises a .jpeg upload to a .jpg name, so .jpeg is not probed.
local PROBE_EXTENSIONS = { 'webp', 'png', 'jpg' }

--- The conventional filename base for a page's quick-uploaded infobox image.
--- e.g. 'Gladius' -> 'Gladius - infobox'.
--- @param pageTitle string The namespace-less page title.
--- @return string
function p.conventionBase(pageTitle)
	return pageTitle .. ' - infobox'
end

--- Default file-existence oracle: true when File:<filename> exists as media.
--- Expensive (file lookup on a non-current title); only reached in production.
--- @param filename string A filename WITH extension, e.g. 'Gladius - infobox.png'.
--- @return boolean
local function defaultFileExists(filename)
	local title = mw.title.makeTitle('File', filename)
	return title ~= nil and title.file ~= nil and title.file.exists == true
end

--- Resolve the auto-discovered infobox image for a convention base.
--- Probes '<base>.<ext>' for each ext in PROBE_EXTENSIONS, short-circuiting on
--- the first hit. Returns the full filename (with extension) or nil.
--- @param base string The convention base, e.g. 'Gladius - infobox'.
--- @param opts { fileExists: fun(filename: string): boolean }|nil Injectable oracle (tests).
--- @return string|nil
function p.resolveDiscoveredSrc(base, opts)
	local fileExists = (opts and opts.fileExists) or defaultFileExists
	for _, ext in ipairs(PROBE_EXTENSIONS) do
		local filename = base .. '.' .. ext
		if fileExists(filename) then
			return filename
		end
	end
	return nil
end

-- Exposed for tests / callers that want the probe order.
p.PROBE_EXTENSIONS = PROBE_EXTENSIONS

return p
