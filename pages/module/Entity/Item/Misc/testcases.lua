require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local Misc = require('Module:Entity/Item/Misc')

local suite = ScribuntoUnit:new()

--- Hook context for direct hook calls (Module:Entity/Types EntityHookContext).
local function ctx(apiData, args, resolved)
	return { apiData = apiData, args = args or {}, resolved = resolved }
end

function suite:testWallPictureRoutesToWallFlair()
	local info = Misc.getTypeInfo(ctx({ sub_type = 'Flair_Wall_Picture' }, {}))
	self:assertEquals('Wall flair', info.name)
	self:assertEquals('Wall flair', info.category)
end

-- Unknown sub_type returns nil so the generic types.json Misc -> Misc items
-- mapping applies.
function suite:testUnknownSubTypeReturnsNil()
	self:assertEquals(nil, Misc.getTypeInfo(ctx({ sub_type = 'SomethingElse' }, {})))
end

function suite:testMissingSubTypeReturnsNil()
	self:assertEquals(nil, Misc.getTypeInfo(ctx({}, {})))
end

return suite
