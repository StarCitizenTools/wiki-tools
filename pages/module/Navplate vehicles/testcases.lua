require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()

-- Module:Navplate vehicles requires several off-repo modules unconditionally
-- at load time (Module:Navplate, Module:Common, Module:i18n,
-- Module:Translate); none are mirrored or stubbed centrally in
-- scribuntounit.config.lua, so requiring the real module would error before
-- this suite could run, and package.preload isn't an option here: `package`
-- is absent from live Scribunto's sandbox, so tests/lint-globals.sh flags any
-- read of it even though this file never deploys. Wrapping the global
-- `require` for the one call that loads the module (restored immediately
-- after, even if the load itself errors) resolves those names to minimal
-- stand-ins instead, using only the allowlisted `require` global. Only
-- Module:Common's removeTypeSuffix is exercised by the tests below; it is
-- copied faithfully from the live module
-- (https://starcitizen.tools/Module:Common) since it feeds methodtable.group's
-- display-name logic. The rest only need to exist.
local common
common = {
	removeTypeSuffix = function(pageName, suffix)
		if type(suffix) == 'table' then
			for _, toRemove in pairs(suffix) do
				pageName = common.removeTypeSuffix(pageName, toRemove)
			end
			return pageName
		end
		return mw.text.trim(pageName:gsub('%(' .. suffix .. '%)', ''), '_ ')
	end,
}

local FAKE_MODULES = {
	['Module:Navplate'] = {
		navplateTemplate = function()
			return ''
		end,
	},
	['Module:Common'] = common,
	['Module:i18n'] = {
		new = function()
			return {
				translate = function(_, key)
					return key
				end,
			}
		end,
	},
	['Module:Translate'] = {
		new = function()
			return {
				format = function(_, key)
					return key
				end,
			}
		end,
	},
}

local realRequire = require
require = function(name)
	return FAKE_MODULES[name] or realRequire(name)
end
local ok, nv = pcall(realRequire, 'Module:Navplate vehicles')
require = realRequire
if not ok then
	error(nv, 0)
end

-- Suffix table matching real call sites: methodtable.group's suffix argument
-- is always a table (make() passes the two-element `sections` table).
local SUFFIX = { 'Ship' }

function suite:testSortRowsOrdersByManufacturerThenPage()
	local rows = {
		{ page = 'Ship B', manufacturer = 'Manufacturer:MISC' },
		{ page = 'Ship D', manufacturer = 'Manufacturer:RSI' },
		{ page = 'Ship A', manufacturer = 'Manufacturer:Drake Interplanetary' },
		{ page = 'Ship C', manufacturer = 'Manufacturer:RSI' },
	}
	nv._internal.sortRows(rows)
	self:assertEquals('Ship A', rows[1].page) -- Drake
	self:assertEquals('Ship B', rows[2].page) -- MISC
	self:assertEquals('Ship C', rows[3].page) -- RSI, page 'C' before 'D'
	self:assertEquals('Ship D', rows[4].page)
end

function suite:testSortRowsMissingManufacturerSortsFirst()
	local rows = {
		{ page = 'Ship B', manufacturer = 'Manufacturer:RSI' },
		{ page = 'Ship A' }, -- no manufacturer
	}
	nv._internal.sortRows(rows)
	self:assertEquals('Ship A', rows[1].page)
	self:assertEquals('Ship B', rows[2].page)
end

function suite:testGroupGroupsByManufacturerAndSortsWithinGroup()
	local rows = {
		{ page = 'Ship D', manufacturer = 'Manufacturer:RSI' },
		{ page = 'Ship C', manufacturer = 'Manufacturer:RSI' },
		{ page = 'Ship A', manufacturer = 'Manufacturer:Drake Interplanetary' },
	}
	local grouped = nv._internal.group(rows, 'manufacturer', SUFFIX)
	self:assertEquals(2, #grouped['Manufacturer:RSI'])
	-- Sorted alphabetically by display name within the group, not input order.
	self:assertEquals('[[Ship C|Ship C]]', grouped['Manufacturer:RSI'][1])
	self:assertEquals('[[Ship D|Ship D]]', grouped['Manufacturer:RSI'][2])
	self:assertEquals(1, #grouped['Manufacturer:Drake Interplanetary'])
end

function suite:testGroupStripsSuffixFromDisplayName()
	local rows = { { page = 'Ship A (Ship)', manufacturer = 'Manufacturer:RSI' } }
	local grouped = nv._internal.group(rows, 'manufacturer', SUFFIX)
	self:assertEquals('[[Ship A (Ship)|Ship A]]', grouped['Manufacturer:RSI'][1])
end

function suite:testGroupRowNameOverridesComputedName()
	local rows = { { page = 'Ship A', manufacturer = 'Manufacturer:RSI', name = 'Custom Label' } }
	local grouped = nv._internal.group(rows, 'manufacturer', SUFFIX)
	self:assertEquals('[[Ship A|Custom Label]]', grouped['Manufacturer:RSI'][1])
end

function suite:testGroupInvalidInputReturnsEmpty()
	self:assertEquals(0, #nv._internal.group(nil, 'manufacturer', SUFFIX))
	self:assertEquals(0, #nv._internal.group({}, nil, SUFFIX))
end

function suite:testGroupSkipsRowsMissingGroupKey()
	local rows = { { page = 'Ship A' }, { page = 'Ship B', manufacturer = 'Manufacturer:RSI' } }
	local grouped = nv._internal.group(rows, 'manufacturer', SUFFIX)
	self:assertEquals(nil, grouped[''])
	self:assertEquals(1, #grouped['Manufacturer:RSI'])
end

return suite
