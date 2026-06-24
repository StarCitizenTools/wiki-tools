require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local SD = require('Module:Entity/StructuredData')

local suite = ScribuntoUnit:new()

local MANIFEST = {
	['%doc'] = 'x',
	['Health'] = { smw = 'Number' },
	['Manufacturer'] = { smw = 'Page' },
	['%patterns'] = { { keyMatch = '^modifier_(.+)$', property = 'Modifier %s' } },
}

function suite:testAutoNameMatchesSmwTransform()
	self:assertEquals('Health', SD._internal.autoName('health'))
	self:assertEquals('Uuid', SD._internal.autoName('uuid'))
	self:assertEquals('Acquisition kind', SD._internal.autoName('acquisition_kind'))
	self:assertEquals('Modifier resistance', SD._internal.autoName('modifier_resistance'))
	-- Contract: autoName does NOT reconstruct acronym capitalisation; acronyms flatten.
	self:assertEquals('Scm speed', SD._internal.autoName('scm_speed'))
end

function suite:testResolveRegisteredStatic()
	local name, registered = SD._internal.resolveName(MANIFEST, 'health')
	self:assertEquals('Health', name)
	self:assertEquals(true, registered)
end

function suite:testResolveRegisteredPattern()
	local name, registered = SD._internal.resolveName(MANIFEST, 'modifier_resistance')
	self:assertEquals('Modifier resistance', name)
	self:assertEquals(true, registered)
end

function suite:testResolveUnregisteredStillNamed()
	local name, registered = SD._internal.resolveName(MANIFEST, 'unknown_key')
	self:assertEquals('Unknown key', name)
	self:assertEquals(false, registered)
end

return suite
