require('strict')

--- @module Entity/Contract
--- The Entity component contract as data + a checker. Defines, per role, which
--- lifecycle hooks exist and which are required, and validates a component
--- module against a role. Used by the registry conformance test so a mis-wired
--- kind or facet fails a unit test rather than silently no-opping on-wiki.
---
--- No runtime role in rendering — a contributor-facing guardrail. See
--- Module:Entity/doc for the prose contract reference.

local p = {}

--- Kind: a top-level entity with its own API endpoint, probed by matches().
--- `matches` + `getApiConfigs` identify it; the rest are optional chain-link
--- contributions a kind may also make as a chain root.
---
--- A kind also declares a string `name` (exposed as Data.get().result.kind). It
--- is absent from the spec below because validate() type-checks every spec key as
--- a function hook; `name` is enforced as a non-empty, unique string by the
--- Registry conformance test (Module:Entity/Registry/testcases) instead.
--- @type table<string, boolean>
p.KIND = {
	matches = true,
	getApiConfigs = true,
	resolveSubtype = false,
	enrich = false,
	getTypeInfo = false,
	getSections = false,
	getStructuredData = false,
	getShortDescription = false,
	getExternalSiteItems = false,
	getEditorialManifest = false,
}

--- Facet: a cross-cutting additive aspect matched on a data field.
--- @type table<string, boolean>
p.FACET = {
	matches = true,
	getSections = true,
	getStructuredData = false,
	getShortDescriptionPrefix = false,
}

--- Chain link: a p.parent-linked contributor (Base, Item, subtypes). Every hook
--- optional — a link implements only what it adds.
--- @type table<string, boolean>
p.CHAIN_LINK = {
	getSections = false,
	getStructuredData = false,
	getShortDescription = false,
	getExternalSiteItems = false,
	getTypeInfo = false,
	getApiConfigs = false,
	getSubtitle = false,
	getHeaderBadge = false,
}

--- Validates a component against a role spec. Each required hook must be present
--- and a function; each present spec-hook must be a function. Unknown keys are
--- not flagged (modules expose legitimate public helpers), so a misspelled
--- optional hook is not caught — required hooks are.
---
--- "Required" means the role is inert without that hook (the conformance gate),
--- NOT that a caller throws — Entity.lua still guards each call with `if mod.x`.
--- The contract is deliberately stricter than the lenient runtime: a facet with
--- no getSections wouldn't crash, but it would do nothing, so it's a wiring bug.
---
--- @param component table The module to check
--- @param spec table<string, boolean> A role spec (p.KIND / p.FACET / p.CHAIN_LINK)
--- @return boolean ok True when there are no errors
--- @return string[] errors Human-readable messages (empty when ok)
function p.validate(component, spec)
	if type(component) ~= 'table' then
		return false, { 'component is not a table (got ' .. type(component) .. ')' }
	end
	local errors = {}
	for hook, required in pairs(spec) do
		local value = component[hook]
		if value == nil then
			if required then
				table.insert(errors, 'missing required hook: ' .. hook)
			end
		elseif type(value) ~= 'function' then
			table.insert(errors, 'hook is not a function: ' .. hook .. ' (got ' .. type(value) .. ')')
		end
	end
	return #errors == 0, errors
end

return p
