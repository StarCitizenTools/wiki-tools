require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local resolver = require('Module:InfoboxLua/ImageResolver')

-- A fake oracle reporting a fixed set of existing filenames.
local function oracle(existing)
	local set = {}
	for _, name in ipairs(existing) do
		set[name] = true
	end
	return {
		fileExists = function(filename)
			return set[filename] == true
		end,
	}
end

function suite:testConventionBaseAppendsSuffix()
	self:assertEquals('Gladius - infobox', resolver.conventionBase('Gladius'))
end

function suite:testResolvePrefersWebp()
	local opts = oracle({ 'Gladius - infobox.webp', 'Gladius - infobox.png' })
	self:assertEquals('Gladius - infobox.webp', resolver.resolveDiscoveredSrc('Gladius - infobox', opts))
end

function suite:testResolveFallsThroughToPng()
	local opts = oracle({ 'Gladius - infobox.png' })
	self:assertEquals('Gladius - infobox.png', resolver.resolveDiscoveredSrc('Gladius - infobox', opts))
end

function suite:testResolveFallsThroughToJpg()
	local opts = oracle({ 'Gladius - infobox.jpg' })
	self:assertEquals('Gladius - infobox.jpg', resolver.resolveDiscoveredSrc('Gladius - infobox', opts))
end

function suite:testResolveReturnsNilWhenNoneExist()
	self:assertEquals(nil, resolver.resolveDiscoveredSrc('Gladius - infobox', oracle({})))
end

function suite:testResolveProbesInOrderAndShortCircuits()
	local probed = {}
	local opts = {
		fileExists = function(filename)
			table.insert(probed, filename)
			return filename == 'X - infobox.png'
		end,
	}
	-- png exists but webp does not: probes webp (miss), then png (hit), then stops.
	self:assertEquals('X - infobox.png', resolver.resolveDiscoveredSrc('X - infobox', opts))
	self:assertEquals('X - infobox.webp', probed[1])
	self:assertEquals('X - infobox.png', probed[2])
	-- Short-circuit: jpg must NOT be probed after the png hit.
	self:assertEquals(2, #probed)
	self:assertEquals(nil, probed[3])
end

return suite
