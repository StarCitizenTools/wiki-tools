require('strict')

--- @module Dependencies/Parse
--- Reads a page's own source and returns what it depends on: the wiki modules a
--- Lua module requires or loads, the module functions a template invokes, the
--- TemplateStyles stylesheets either one loads, and the image files it names.
--- Pure: the caller passes the source text.

local p = {}

--- Libraries a module may require that are not wiki pages.
local BUILTINS = { libraryUtil = true, strict = true, bit32 = true }

--- Extensions a name must end in to count as a file.
local FILE_EXTENSIONS = { svg = true, png = true, jpg = true, jpeg = true, gif = true, webp = true }

--- A URL on this wiki's file storage, up to the end of its path. The path is
--- `a/ab/<File>` (or `thumb/a/ab/<File>/…`), `ab` being the start of the md5 of
--- the file's name.
local MEDIA_URL = '%a*:?//media%.starcitizen%.tools/[^%s"\'%)%[%]|{}<>]+'

--- A run of wikitext between the characters that cannot be part of a file name
--- and the syntax around one: `[[File:X.svg|20px]]` yields `File`, `X.svg`, `20px`.
local SEGMENT = '[^|=%[%]{}<>\n:"]+'

--- A `string.format` directive, which stands for a value filled in at runtime.
local FORMAT_DIRECTIVE = '%%[-%d%.]*[sdi]'

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

--- A file's name as its page title shows it, without the namespace: underscores
--- as spaces, first letter upper-cased. Nil when `text` is not a file name with
--- an image extension. `%` is refused, so a Lua pattern such as `'%.svg'` is not
--- a file.
--- @param text string
--- @return string|nil
function p.normaliseFile(text)
	local name = mw.text.trim((text:gsub('[%s_]+', ' ')))
	name = name:gsub('^["\']', ''):gsub('["\']$', '')
	local base, extension = name:match('^(.-)%.(%w+)$')
	if
		base == nil
		or not FILE_EXTENSIONS[extension:lower()]
		or not base:find('%w')
		or base:sub(1, 1) == '.'
		or name:find('[#<>%[%]|{}/\\%%]')
	then
		return nil
	end
	return name:sub(1, 1):upper() .. name:sub(2)
end

--- @class DependenciesFileUrl
--- @field name string the file the URL names
--- @field path string the URL's md5 directories, e.g. `e/e8`

--- @class DependenciesFiles
--- @field names string[] file names without the namespace, sorted, unique
--- @field urls DependenciesFileUrl[] the media URLs among them, sorted by name then path
--- @field dynamic string[] names built while the page runs, such as `Sc-icon-brand-….svg`

--- @return table
local function collector()
	return { names = {}, urls = {}, dynamic = {} }
end

--- @param found table a collector()
--- @return DependenciesFiles
local function finish(found)
	local urls = {}
	for _, url in pairs(found.urls) do
		urls[#urls + 1] = url
	end
	table.sort(urls, function(a, b)
		return a.name .. '|' .. a.path < b.name .. '|' .. b.path
	end)
	return { names = sortedKeys(found.names), urls = urls, dynamic = sortedKeys(found.dynamic) }
end

--- Adds the files that media URLs in `text` name to `found`, and returns
--- `text` without those URLs.
--- @param text string
--- @param found table a collector()
--- @return string
local function scanUrls(text, found)
	for url in text:gmatch(MEDIA_URL) do
		local path = (url:match('//[^/]+/(.*)$'):gsub('^thumb/', ''))
		local first, pair, file = path:match('^(%x)/(%x%x)/([^/?#]+)')
		local name = first and file and p.normaliseFile(mw.uri.decode(file, 'PATH'))
		if name and pair:sub(1, 1) == first then
			found.names[name] = true
			found.urls[name .. '|' .. first .. '/' .. pair] = { name = name, path = first .. '/' .. pair }
		end
	end
	return (text:gsub(MEDIA_URL, ' '))
end

--- Adds the files `text` names to `found`: media URLs, and every segment
--- (see SEGMENT) that is a whole file name. A name holding `…` is built at
--- runtime and goes to `found.dynamic`.
--- @param text string
--- @param found table a collector()
--- @param transform (fun(segment: string): string)|nil applied to each segment first
local function scan(text, found, transform)
	for segment in scanUrls(text, found):gmatch(SEGMENT) do
		local name = p.normaliseFile(transform and transform(segment) or segment)
		if name and name:find('…', 1, true) then
			found.dynamic[name] = true
		elseif name then
			found.names[name] = true
		end
	end
end

--- Files a template names: `[[File:…]]`, a parameter value that is a whole
--- file name, and media URLs.
--- @param wikitext string|nil
--- @return DependenciesFiles
function p.files(wikitext)
	local found = collector()
	scan(stripHtmlComments(wikitext or ''), found)
	return finish(found)
end

--- Files a stylesheet names through media URLs.
--- @param css string|nil
--- @return DependenciesFiles
function p.stylesheetFiles(css)
	local found = collector()
	scanUrls(((css or ''):gsub('/%*.-%*/', '')), found)
	return finish(found)
end

--- @class DependenciesLiteral
--- @field value string
--- @field first integer the position of its opening quote or bracket
--- @field last integer the position of its closing quote or bracket

--- The string literals in Lua source, in order. Reads comments itself rather
--- than through stripComments(), which also cuts a `--` inside a string (as in
--- a CSS custom property) and so would leave a quote unmatched.
--- @param src string
--- @return DependenciesLiteral[]
local function literals(src)
	local found, i = {}, 1
	while true do
		local at = src:find('[%-\'"%[]', i)
		if at == nil then
			return found
		end
		local char = src:sub(at, at)
		if char == '-' then
			if src:sub(at + 1, at + 1) ~= '-' then
				i = at + 1
			else
				local level = src:match('^%[(=*)%[', at + 2)
				local stop
				if level then
					stop = select(2, src:find(']' .. level .. ']', at + 4 + #level, true))
				else
					stop = src:find('\n', at, true)
				end
				i = (stop or #src) + 1
			end
		elseif char == '[' then
			local level = src:match('^%[(=*)%[', at)
			if level == nil then
				i = at + 1
			else
				local open = at + #level + 2
				local close, stop = src:find(']' .. level .. ']', open, true)
				found[#found + 1] = { value = src:sub(open, (close or #src + 1) - 1), first = at, last = stop or #src }
				i = (stop or #src) + 1
			end
		else
			local parts, j = {}, at + 1
			while true do
				local special = src:find('[\\\n' .. char .. ']', j)
				if special == nil then
					parts[#parts + 1] = src:sub(j)
					j = #src
					break
				end
				parts[#parts + 1] = src:sub(j, special - 1)
				if src:sub(special, special) == '\\' then
					parts[#parts + 1] = src:sub(special + 1, special + 1)
					j = special + 2
				else
					j = special
					break
				end
			end
			found[#found + 1] = { value = table.concat(parts), first = at, last = j }
			i = j + 1
		end
	end
end

--- The text a concatenation ending in `list[k]` builds, with `…` for each part
--- that is not a literal; nil when `list[k]` is not concatenated onto anything.
--- @param src string
--- @param list DependenciesLiteral[]
--- @param k integer
--- @return string|nil
local function concatenated(src, list, k)
	local parts, i = { list[k].value }, k
	while true do
		local before = src:sub(i > 1 and list[i - 1].last + 1 or 1, list[i].first - 1)
		local head = before:match('^(.-)%s*%.%.%s*$')
		if head == nil then
			break
		end
		if head:find('%S') then
			table.insert(parts, 1, '…')
			-- `'a' .. name .. 'b'`: one name, call or index between two literals.
			local operand = (head:gsub('%b()', ''):gsub('%b[]', ''))
			if not operand:find('^%s*%.%.%s*[%w_%.:]+$') then
				break
			end
		end
		if i == 1 then
			break
		end
		i = i - 1
		table.insert(parts, 1, list[i].value)
	end
	if #parts == 1 then
		return nil
	end
	return table.concat(parts)
end

--- A segment with its `string.format` directives as `…`, unless it holds a
--- `%` that is not one, as a Lua pattern does.
--- @param segment string
--- @return string
local function formatted(segment)
	local replaced = segment:gsub(FORMAT_DIRECTIVE, '…')
	if replaced:find('%', 1, true) then
		return segment
	end
	return replaced
end

--- @param src string a Lua module's source
--- @return DependenciesFiles
local function luaFiles(src)
	local found = collector()
	local list = literals(src)
	for k, literal in ipairs(list) do
		local extension = literal.value:match('%.(%w+)%s*$')
		local joined = extension and FILE_EXTENSIONS[extension:lower()] and concatenated(src, list, k)
		scan(joined or literal.value, found, formatted)
	end
	return finish(found)
end

--- @class DependenciesLua
--- @field requires string[] wiki modules required, sorted, unique
--- @field loads string[] modules read with mw.loadData or mw.loadJsonData
--- @field dynamic string[] required patterns such as `Module:X/…`
--- @field strict boolean the module requires `strict`
--- @field styles string[] TemplateStyles pages loaded through frame:extensionTag or a tag in a string
--- @field files DependenciesFiles the files its strings name

--- @param src string|nil a Lua module's source
--- @return DependenciesLua
function p.lua(src)
	local files = luaFiles(src or '')
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
		files = files,
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
