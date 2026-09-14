require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()

-- Module:RentalVehicleGrid requires Module:Date unconditionally at load time
-- (only calls it lazily inside formatDateString, not exercised below); it is
-- off-repo and not stubbed centrally in scribuntounit.config.lua, so
-- requiring the real module would error first. package.preload isn't an
-- option here: `package` is absent from live Scribunto's sandbox, so
-- tests/lint-globals.sh flags any read of it even though this file never
-- deploys. Wrapping the global `require` for the one call that loads the
-- module (restored immediately after, even if the load itself errors) resolves
-- the name to a minimal stand-in instead, using only the allowlisted `require`
-- global.
local realRequire = require
require = function(name)
	if name == 'Module:Date' then
		return { _Date = function() end }
	end
	return realRequire(name)
end
local ok, rvg = pcall(realRequire, 'Module:RentalVehicleGrid')
require = realRequire
if not ok then
	error(rvg, 0)
end

function suite:testMapWikiShipsKeysByNormalizedPage()
	local rows = {
		['Aurora MR'] = {
			name = 'Aurora MR',
			manufacturer = 'Manufacturer:RSI',
			role = 'Starter',
			image = 'Aurora.png',
		},
	}
	local wikiShips = rvg._internal.mapWikiShips(rows)
	local entry = wikiShips['aurora mr']
	self:assertEquals('Manufacturer:RSI', entry.manufacturer)
	self:assertEquals('Starter', entry.role)
	self:assertEquals('Aurora.png', entry.image)
end

function suite:testMapWikiShipsNormalizesCaseAndWhitespace()
	local rows = {
		[' Cutlass Black '] = { manufacturer = 'Manufacturer:Drake Interplanetary' },
	}
	local wikiShips = rvg._internal.mapWikiShips(rows)
	self:assertEquals('Manufacturer:Drake Interplanetary', wikiShips['cutlass black'].manufacturer)
end

function suite:testMapWikiShipsPassesThroughMissingFields()
	local rows = { ['Freelancer'] = {} }
	local wikiShips = rvg._internal.mapWikiShips(rows)
	self:assertEquals(nil, wikiShips['freelancer'].manufacturer)
	self:assertEquals(nil, wikiShips['freelancer'].role)
	self:assertEquals(nil, wikiShips['freelancer'].image)
end

function suite:testMapWikiShipsEmptyRowsIsEmpty()
	local wikiShips = rvg._internal.mapWikiShips({})
	self:assertEquals(nil, next(wikiShips))
end

return suite
