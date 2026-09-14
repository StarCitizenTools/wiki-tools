require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local PageResolver = require('Module:Entity/PageResolver')
local bucketLib = require('mw.ext.bucket')

local suite = ScribuntoUnit:new()

function suite:testEmptyListNoQuery()
	bucketLib._reset()
	self:assertDeepEquals({}, PageResolver.resolve({}))
	self:assertEquals(0, #bucketLib._chains)
end

function suite:testResolvesPagesAndImages()
	bucketLib._reset()
	bucketLib._setRows('entity', {
		{ uuid = 'u1', page_name = 'A', image = 'A.png' },
		{ uuid = 'u2', page_name = 'B' },
	})
	local map = PageResolver.resolve({ 'u1', 'u2', 'u3' })
	self:assertDeepEquals({ page = 'A', image = 'A.png' }, map.u1)
	self:assertDeepEquals({ page = 'B' }, map.u2)
	self:assertEquals(nil, map.u3)
end

--- A Bucket infrastructure failure must degrade to the documented fallback
--- (same possibly-wrong link as before), not error the section render.
function suite:testResolveContainsBucketFailure()
	bucketLib._reset()
	bucketLib._failNext = true
	self:assertDeepEquals({}, PageResolver.resolve({ 'u1' }))
end

return suite
