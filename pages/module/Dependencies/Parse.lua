require('strict')

--- @module Dependencies/Parse
--- Reads a page's own source and returns what it depends on: the wiki modules a
--- Lua module requires or loads, the module functions a template invokes, and
--- the TemplateStyles stylesheets either one loads. Pure: the caller passes the
--- source text.

local p = {}

--- Libraries a module may require that are not wiki pages.
local BUILTINS = { libraryUtil = true, strict = true, bit32 = true }

--- The calls that name a module, and the list each one feeds.
local CALLS = {
	{ pattern = 'require', list = 'requires' },
	{ pattern = 'mw%.loadData', list = 'loads' },
	{ pattern = 'mw%.loadJsonData', list = 'loads' },
}

--- A Lua pattern matching `word` in any letter case.
--- @param word string
--- @return string
local function caseless(word)
	return (word:gsub('%a', function(letter)
		return '[' .. letter:upper() .. letter:lower() .. ']'
	end))
end

--- The start of a `<templatestyles … src=` tag, up to the attribute value.
local STYLES_TAG = '<' .. caseless('templatestyles') .. '%s[^>]-' .. caseless('src') .. '%s*=%s*'

--- @param text string wikitext
--- @return string
local function stripHtmlComments(text)
	return (text:gsub('<!%-%-.-%-%->', ''))
end

--- @param set table<string, boolean>
--- @return string[]
local function sortedKeys(set)
	local list = {}
	for key in pairs(set) do
		list[#list + 1] = key
	end
	table.sort(list)
	return list
end

--- The string a single literal argument holds, or nil. A value containing its
--- own quote character is the concatenation of two literals, not one.
--- @param arg string
--- @return string|nil
local function literal(arg)
	local quote, value = arg:match('^%s*([\'"])(.-)%1%s*$')
	if value == nil or value:find(quote, 1, true) then
		return nil
	end
	return value
end

--- The string literal assigned to a variable elsewhere in the source, or nil.
--- @param src string
--- @param name string an identifier
--- @return string|nil
local function variableValue(src, name)
	local quote, value = src:match('[^%w_]' .. name .. '%s*=%s*([\'"])(.-)%1')
	if quote == nil then
		return nil
	end
	return value
end

--- Joins a concatenation's literal parts, with `…` for every non-literal part.
--- @param arg string
--- @return string
local function concatenation(arg)
	local parts = {}
	for piece in (arg .. '..'):gmatch('(.-)%.%.') do
		parts[#parts + 1] = literal(piece) or '…'
	end
	return table.concat(parts)
end

--- Removes Lua comments: long comments (`--[[ ]]`, `--[==[ ]==]`) first, then
--- line comments. A `--` inside a string literal is also cut, which can only
--- drop a dependency, never invent one.
--- @param src string
--- @return string
function p.stripComments(src)
	src = src:gsub('%-%-%[(=*)%[.-%]%1%]', '')
	return (src:gsub('%-%-[^\n]*', ''))
end

--- `Module:` plus the name with its first letter upper-cased, or nil when the
--- name is not in the Module namespace.
--- @param name string
--- @return string|nil
function p.normaliseModule(name)
	local rest = mw.text.trim(name):match('^[Mm][Oo][Dd][Uu][Ll][Ee]%s*:%s*(.+)$')
	if rest == nil then
		return nil
	end
	return 'Module:' .. rest:sub(1, 1):upper() .. rest:sub(2)
end

--- The module an `#invoke` names: with or without its `Module:` prefix.
--- @param target string
--- @return string|nil
function p.normaliseInvokeTarget(target)
	local name = mw.text.trim(target):gsub('^[Mm][Oo][Dd][Uu][Ll][Ee]%s*:%s*', '')
	if name == '' then
		return nil
	end
	return 'Module:' .. name:sub(1, 1):upper() .. name:sub(2)
end

--- The page a TemplateStyles `src` names. A `src` without a namespace is a
--- Template page, which is how TemplateStyles resolves it.
--- @param src string
--- @return string|nil
function p.normaliseStylesheet(src)
	local name = mw.text.trim(src)
	if name == '' then
		return nil
	end
	local namespace, rest = name:match('^([^:/]+):%s*(.+)$')
	if namespace == nil then
		namespace, rest = 'Template', name
	else
		namespace = mw.text.trim(namespace)
		local canonical = { module = 'Module', template = 'Template' }
		namespace = canonical[namespace:lower()] or namespace
	end
	return namespace .. ':' .. rest:sub(1, 1):upper() .. rest:sub(2)
end

--- Stylesheets named by `<templatestyles src=…>` tags.
--- @param text string|nil wikitext, or Lua source whose strings hold such tags
--- @return string[] sorted, unique
function p.styles(text)
	local found = {}
	for rest in stripHtmlComments(text or ''):gmatch(STYLES_TAG .. '([^>]*)') do
		local value = rest:match('^"([^"]*)"') or rest:match("^'([^']*)'") or rest:match('^([^%s>"\']+)')
		local name = value and p.normaliseStylesheet((value:gsub('/$', '')))
		if name then
			found[name] = true
		end
	end
	return sortedKeys(found)
end

--- @class DependenciesLua
--- @field requires string[] wiki modules required, sorted, unique
--- @field loads string[] modules read with mw.loadData or mw.loadJsonData
--- @field dynamic string[] required patterns such as `Module:X/…`
--- @field strict boolean the module requires `strict`
--- @field styles string[] TemplateStyles pages loaded through frame:extensionTag or a tag in a string

--- @param src string|nil a Lua module's source
--- @return DependenciesLua
function p.lua(src)
	src = p.stripComments(src or '')
	local found = { requires = {}, loads = {}, dynamic = {} }
	local strict = false

	local function add(list, arg)
		local value = literal(arg)
		if value == nil then
			local identifier = arg:match('^%s*([%a_][%w_]*)%s*$')
			if identifier then
				value = variableValue(src, identifier)
			end
		end
		if value == nil and arg:find('%.%.') then
			local joined = concatenation(arg)
			if joined:find('…', 1, true) then
				local pattern = p.normaliseModule(joined)
				-- `Module:…` (no literal text after the namespace) tells the reader
				-- nothing, so it is dropped rather than recorded.
				if pattern and pattern ~= 'Module:…' then
					found.dynamic[pattern] = true
				end
				return
			end
			value = joined
		end
		if value == nil then
			return
		end
		if value == 'strict' then
			strict = true
		end
		if BUILTINS[value] then
			return
		end
		local name = p.normaliseModule(value)
		if name then
			found[list][name] = true
		end
	end

	for _, call in ipairs(CALLS) do
		local head = '%f[%w_%.:]' .. call.pattern
		for arg in src:gmatch(head .. '%s*(%b())') do
			add(call.list, arg:sub(2, -2))
		end
		for quote, value in src:gmatch(head .. '%s*([\'"])(.-)%1') do
			add(call.list, quote .. value .. quote)
		end
		for arg in src:gmatch('%f[%w_]pcall%s*%(%s*' .. call.pattern .. '%s*,([^%),]+)') do
			add(call.list, arg)
		end
	end

	local styles = {}
	for _, sheet in ipairs(p.styles(src)) do
		styles[sheet] = true
	end
	for _, shape in ipairs({ '%b()', '%b{}' }) do
		for arg in src:gmatch('%f[%w_]extensionTag%s*(' .. shape .. ')') do
			if arg:lower():find('templatestyles', 1, true) then
				local _, value = arg:match('src%s*=%s*([\'"])(.-)%1')
				if value == nil then
					local identifier = arg:match('src%s*=%s*([%a_][%w_]*)%s*[,}]')
					value = identifier and variableValue(src, identifier)
				end
				local name = value and p.normaliseStylesheet(value)
				if name then
					styles[name] = true
				end
			end
		end
	end

	return {
		requires = sortedKeys(found.requires),
		loads = sortedKeys(found.loads),
		dynamic = sortedKeys(found.dynamic),
		strict = strict,
		styles = sortedKeys(styles),
	}
end

--- @class DependenciesInvoke
--- @field module string `Module:Name`
--- @field func string function name; a parameter such as `{{{1}}}` is kept verbatim

--- @param wikitext string|nil a template's source
--- @return DependenciesInvoke[] sorted by module then function, unique
function p.invokes(wikitext)
	local text = stripHtmlComments(wikitext or '')
	local seen, calls = {}, {}
	for target, func in text:gmatch('#[Ii][Nn][Vv][Oo][Kk][Ee]%s*:([^|{}]+)|%s*([^|}]*)') do
		local module = p.normaliseInvokeTarget(target)
		func = mw.text.trim(func)
		if func:sub(1, 3) == '{{{' then
			func = func .. '}}}'
		end
		local key = module and (module .. '|' .. func)
		if key and func ~= '' and not seen[key] then
			seen[key] = true
			calls[#calls + 1] = { module = module, func = func }
		end
	end
	table.sort(calls, function(a, b)
		return a.module .. '|' .. a.func < b.module .. '|' .. b.func
	end)
	return calls
end

return p
