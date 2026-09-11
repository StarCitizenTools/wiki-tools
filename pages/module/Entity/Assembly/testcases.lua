require('strict')

local ScribuntoUnit = require('Module:ScribuntoUnit')
local suite = ScribuntoUnit:new()
local assembly = require('Module:Entity/Assembly')

-- mergeSections

function suite:testMergeSectionsEmptyList()
	local result = assembly.mergeSections({})
	self:assertEquals(0, #result)
end

function suite:testMergeSectionsSingleModule()
	local result = assembly.mergeSections({
		{
			{
				key = 'general',
				label = 'General',
				items = {
					{ label = 'Name', content = 'Test' },
				},
			},
		},
	})
	self:assertEquals(1, #result)
	self:assertEquals('General', result[1].label)
	self:assertEquals(1, #result[1].items)
	self:assertEquals('Name', result[1].items[1].label)
end

function suite:testMergeSectionsAppendItems()
	local result = assembly.mergeSections({
		{
			{ key = 'general', label = 'General', items = { { label = 'Name', content = 'Test' } } },
		},
		{
			{ key = 'general', items = { { label = 'Size', content = '3' } } },
		},
	})
	self:assertEquals(1, #result)
	self:assertEquals('General', result[1].label)
	self:assertEquals(2, #result[1].items)
	self:assertEquals('Name', result[1].items[1].label)
	self:assertEquals('Size', result[1].items[2].label)
end

function suite:testMergeSectionsFirstMetadataWins()
	local result = assembly.mergeSections({
		{
			{
				key = 'general',
				label = 'General',
				collapsible = true,
				items = { { label = 'Name', content = 'Test' } },
			},
		},
		{
			{
				key = 'general',
				label = 'Overridden',
				collapsible = false,
				items = { { label = 'Size', content = '3' } },
			},
		},
	})
	self:assertEquals('General', result[1].label)
	self:assertTrue(result[1].collapsible)
end

function suite:testMergeSectionsPreservesInsertionOrder()
	local result = assembly.mergeSections({
		{ { key = 'general', label = 'General', items = { { label = 'A', content = '1' } } } },
		{ { key = 'specs', label = 'Specs', items = { { label = 'B', content = '2' } } } },
		{ { key = 'damage', label = 'Damage', items = { { label = 'C', content = '3' } } } },
	})
	self:assertEquals(3, #result)
	self:assertEquals('General', result[1].label)
	self:assertEquals('Specs', result[2].label)
	self:assertEquals('Damage', result[3].label)
end

function suite:testMergeSectionsMultipleKeysPerModule()
	local result = assembly.mergeSections({
		{
			{ key = 'general', label = 'General', items = { { label = 'Name', content = 'Test' } } },
			{ key = 'specs', label = 'Specs', items = { { label = 'Size', content = '3' } } },
		},
	})
	self:assertEquals(2, #result)
	self:assertEquals('General', result[1].label)
	self:assertEquals('Specs', result[2].label)
end

function suite:testMergeSectionsNilItemsOmitted()
	local result = assembly.mergeSections({
		{
			{ key = 'general', label = 'General', content = 'Some HTML' },
		},
	})
	self:assertEquals(nil, result[1].items)
	self:assertEquals('Some HTML', result[1].content)
end

-- mergeStructuredData

function suite:testMergeStructuredDataEmpty()
	local result = assembly.mergeStructuredData({})
	self:assertEquals(nil, next(result))
end

function suite:testMergeStructuredDataCombinesKeys()
	local result = assembly.mergeStructuredData({
		{ uuid = '123', name = 'Test' },
		{ size = 3, mass = 100 },
	})
	self:assertEquals('123', result.uuid)
	self:assertEquals('Test', result.name)
	self:assertEquals(3, result.size)
	self:assertEquals(100, result.mass)
end

function suite:testMergeStructuredDataLaterOverrides()
	local result = assembly.mergeStructuredData({
		{ name = 'Original' },
		{ name = 'Override' },
	})
	self:assertEquals('Override', result.name)
end

-- buildChain

function suite:testBuildChainSingleModule()
	local base = { parent = nil }
	local chain = assembly.buildChain(base)
	self:assertEquals(1, #chain)
end

function suite:testMergeSectionsDropsFullyEmptySection()
	-- A section with no items, no content, no sub-sections is dropped entirely
	-- (the old Base 'general' scaffold bug).
	local result = assembly.mergeSections({
		{ { key = 'general', items = {} } },
	})
	self:assertEquals(0, #result)
end

function suite:testMergeSectionsKeepsContentOnlySection()
	local result = assembly.mergeSections({
		{ { key = 'footer', content = 'X' } },
	})
	self:assertEquals(1, #result)
	self:assertEquals('X', result[1].content)
end

-- resolveMostSpecific

function suite:testResolveMostSpecificLeafWins()
	local chain = {
		{
			contextHooks = true,
			getX = function()
				return 'root'
			end,
		},
		{
			contextHooks = true,
			getX = function()
				return 'leaf'
			end,
		},
	}
	self:assertEquals('leaf', assembly.resolveMostSpecific(chain, 'getX'))
end

function suite:testResolveMostSpecificDefaultTakesNil()
	local chain = {
		{
			contextHooks = true,
			getX = function()
				return 'root'
			end,
		},
		{
			contextHooks = true,
			getX = function()
				return nil
			end,
		},
	}
	self:assertEquals(nil, assembly.resolveMostSpecific(chain, 'getX'))
end

function suite:testResolveMostSpecificAcceptNonEmptySkips()
	local chain = {
		{
			contextHooks = true,
			getX = function()
				return 'root'
			end,
		},
		{
			contextHooks = true,
			getX = function()
				return ''
			end,
		},
	}
	self:assertEquals('root', assembly.resolveMostSpecific(chain, 'getX', assembly.acceptNonEmpty))
end

function suite:testResolveMostSpecificForwardsContext()
	local ctx = { a = 'x', b = 'y' }
	local chain = { {
		contextHooks = true,
		getX = function(c)
			return c
		end,
	} }
	self:assertEquals(ctx, assembly.resolveMostSpecific(chain, 'getX', nil, ctx))
end

-- An unflagged link keeps getting its LEGACY_ARGS positional list (real hook
-- name, since an unflagged link goes through the LEGACY_ARGS lookup).
function suite:testResolveMostSpecificForwardsLegacyArgsPositionally()
	local ctx = { apiData = { a = 1 }, args = { b = 2 } }
	local chain = { {
		getSubtitle = function(apiData, args)
			return { apiData, args }
		end,
	} }
	local got = assembly.resolveMostSpecific(chain, 'getSubtitle', nil, ctx)
	self:assertEquals(ctx.apiData, got[1])
	self:assertEquals(ctx.args, got[2])
end

function suite:testResolveMostSpecificNoneDefined()
	self:assertEquals(nil, assembly.resolveMostSpecific({ {}, {} }, 'getX'))
end

-- callHook: an unflagged link is called positionally in LEGACY_ARGS order, a
-- contextHooks link receives the context table itself.
function suite:testCallHookLegacyAndContextShapes()
	local ctx = { apiData = { a = 1 }, args = { b = 2 }, resolved = { c = 3 }, typeInfo = { name = 'T' }, prefix = 'P' }
	local legacy = {
		getShortDescription = function(apiData, args, typeInfo, prefix, resolved)
			return { apiData, args, typeInfo, prefix, resolved }
		end,
	}
	local got = assembly.callHook(legacy, 'getShortDescription', ctx)
	self:assertEquals(ctx.apiData, got[1])
	self:assertEquals(ctx.args, got[2])
	self:assertEquals(ctx.typeInfo, got[3])
	self:assertEquals('P', got[4])
	self:assertEquals(ctx.resolved, got[5])
	local modern = {
		contextHooks = true,
		getShortDescription = function(c)
			return c
		end,
	}
	self:assertEquals(ctx, assembly.callHook(modern, 'getShortDescription', ctx))
end

function suite:testCallHookLegacyNilInTheMiddle()
	local legacy = {
		getShortDescription = function(apiData, args, typeInfo, prefix, resolved)
			return select('#', apiData, args, typeInfo, prefix, resolved), resolved
		end,
	}
	local n, resolved =
		assembly.callHook(legacy, 'getShortDescription', { apiData = {}, args = {}, resolved = { r = true } })
	self:assertEquals(5, n)
	self:assertTrue(resolved.r)
end

-- collect (additive policy: every link's list, root-to-leaf)

function suite:testCollectConcatenatesRootToLeaf()
	local chain = {
		{
			getCategories = function()
				return { 'Root cat' }
			end,
		},
		{},
		{
			getCategories = function(apiData, args)
				return { 'Leaf ' .. apiData .. args }
			end,
		},
	}
	local out = assembly.collect(chain, 'getCategories', { apiData = 'x', args = 'y' })
	self:assertEquals(2, #out)
	self:assertEquals('Root cat', out[1])
	self:assertEquals('Leaf xy', out[2])
end

function suite:testCollectSkipsNilReturns()
	local chain = { {
		getCategories = function()
			return nil
		end,
	} }
	self:assertEquals(0, #assembly.collect(chain, 'getCategories', {}))
end

-- mergeEditorialManifests (root-to-leaf, leaf keys win)

function suite:testMergeEditorialManifestsLeafWins()
	local chain = {
		{
			getEditorialManifest = function()
				return { a = { arg = 'a' }, shared = { arg = 'root' } }
			end,
		},
		{
			getEditorialManifest = function()
				return { b = { arg = 'b' }, shared = { arg = 'leaf' } }
			end,
		},
	}
	local merged = assembly.mergeEditorialManifests(chain)
	self:assertEquals('a', merged.a.arg)
	self:assertEquals('b', merged.b.arg)
	self:assertEquals('leaf', merged.shared.arg)
end

function suite:testMergeEditorialManifestsNilWhenNoneDefined()
	self:assertEquals(nil, assembly.mergeEditorialManifests({ {}, {} }))
end

function suite:testMergeEditorialManifestsIgnoresNonTableFragments()
	local chain = {
		{
			getEditorialManifest = function()
				return nil
			end,
		},
		{
			getEditorialManifest = function()
				return { a = { arg = 'a' } }
			end,
		},
	}
	self:assertEquals('a', assembly.mergeEditorialManifests(chain).a.arg)
	self:assertEquals(
		nil,
		assembly.mergeEditorialManifests({ {
			getEditorialManifest = function()
				return nil
			end,
		} })
	)
end

return suite
