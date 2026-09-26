require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Jurisdiction = require('Module:Entity/Location/Jurisdiction')

local suite = ScribuntoUnit:new()

--- A fetch over a fixed uuid → record table, recording every uuid asked for.
local function fakeFetch(records)
	local asked = {}
	return function(uuid)
		asked[#asked + 1] = uuid
		return records[uuid]
	end, asked
end

function suite:testOwnJurisdictionWinsWithoutFetching()
	local fetch, asked = fakeFetch({})
	local record = { jurisdiction = { name = 'Rough & Ready' }, parent = { uuid = 'pyro' } }
	self:assertEquals('Rough & Ready', Jurisdiction.walk(record, fetch))
	self:assertEquals(0, #asked)
end

--- A moon has none of its own; its planet defines it.
function suite:testMoonInheritsItsPlanetsJurisdiction()
	local fetch, asked = fakeFetch({
		hurston = { uuid = 'hurston', jurisdiction = { name = 'Hurston Dynamics' } },
	})
	local aberdeen = { uuid = 'aberdeen', parent = { uuid = 'hurston', type_name = 'Planet' } }
	self:assertEquals('Hurston Dynamics', Jurisdiction.walk(aberdeen, fetch))
	self:assertDeepEquals({ 'hurston' }, asked)
end

--- A Lagrange station's GAME parent is the star, so it is under the system's
--- law, not the planet its curated parent names.
function suite:testLagrangeStationTakesTheStarsJurisdiction()
	local fetch = fakeFetch({ stanton = { uuid = 'stanton', jurisdiction = { name = 'UEE' } } })
	local hurL1 = { uuid = 'hurl1', parent = { uuid = 'stanton', type_name = 'Star' } }
	self:assertEquals('UEE', Jurisdiction.walk(hurL1, fetch))
end

function suite:testWalkStopsAtMaxHops()
	local records = {}
	for i = 1, Jurisdiction.MAX_HOPS + 2 do
		records['n' .. i] = { uuid = 'n' .. i, parent = { uuid = 'n' .. (i + 1) } }
	end
	local fetch, asked = fakeFetch(records)
	self:assertEquals(nil, Jurisdiction.walk({ parent = { uuid = 'n1' } }, fetch))
	self:assertEquals(Jurisdiction.MAX_HOPS, #asked)
end

function suite:testWalkStopsWhenAFetchFails()
	local fetch = fakeFetch({})
	self:assertEquals(nil, Jurisdiction.walk({ parent = { uuid = 'gone' } }, fetch))
end

--- The API's 13 jurisdiction names, each with its exact expected link.
--- United Empire of Earth, MicroTech (company), ArcCorp (company), Hurston
--- Dynamics, Crusader Industries and People's Alliance each have a
--- "Jurisdiction" section; Rough and Ready, Citizens for Prosperity,
--- Headhunters, XenoThreat, Klescher Rehabilitation Facilities, Jurisdiction
--- - Green Imperial and Jurisdictions do not.
local EXPECTED_LINKS = {
	UEE = '[[United Empire of Earth#Jurisdiction|UEE]]',
	microTech = '[[MicroTech (company)#Jurisdiction|microTech]]',
	ArcCorp = '[[ArcCorp (company)#Jurisdiction|ArcCorp]]',
	['Hurston Dynamics'] = '[[Hurston Dynamics#Jurisdiction|Hurston Dynamics]]',
	['Crusader Industries'] = '[[Crusader Industries#Jurisdiction|Crusader Industries]]',
	['Rough & Ready'] = '[[Rough and Ready|Rough & Ready]]',
	['Citizens For Prosperity'] = '[[Citizens for Prosperity|Citizens for Prosperity]]',
	Headhunters = '[[Headhunters|Headhunters]]',
	["People's Alliance"] = "[[People's Alliance#Jurisdiction|People's Alliance]]",
	XenoThreat = '[[XenoThreat|XenoThreat]]',
	['Klescher Rehabilitation'] = '[[Klescher Rehabilitation Facilities|Klescher Rehabilitation]]',
	Green = '[[Jurisdiction - Green Imperial|Green Imperial]]',
	Ungoverned = '[[Jurisdictions|Ungoverned]]',
}

function suite:testDisplayLinksEveryApiJurisdictionName()
	for name, expected in pairs(EXPECTED_LINKS) do
		self:assertEquals(expected, Jurisdiction.display(name), name)
	end
end

function suite:testDisplaySpecialTargets()
	self:assertEquals('[[Jurisdiction - Green Imperial|Green Imperial]]', Jurisdiction.display('Green Imperial'))
	self:assertEquals(nil, Jurisdiction.display(nil))
	self:assertEquals(nil, Jurisdiction.display(''))
end

return suite
