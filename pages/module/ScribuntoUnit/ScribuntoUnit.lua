--- Based on https://en.wikipedia.org/w/index.php?title=Module:ScribuntoUnit&oldid=1340585145

--- Unit tests for Scribunto.
require('strict')

local DebugHelper = {}

--- @class ScribuntoUnit
--- @field frame mw.frame
--- @field successCount number
--- @field failureCount number
--- @field skipCount number
--- @field results table[]
--- @field _tests table[]
local ScribuntoUnit = {}
ScribuntoUnit.__meta = {}

-- The cfg table contains all localisable strings and configuration, to make it
-- easier to port this module to another wiki.
local cfg = mw.loadData('Module:ScribuntoUnit/config')

--- Concatenates keys and values, ideal for displaying a template or parser function argument table.
---
--- @param tbl table The table to concatenate.
--- @param keySeparator string|nil Glue between key and value. Defaults to " = ".
--- @param separator string|nil Glue between different key-value pairs. Defaults to ", ".
--- @return string
function DebugHelper.concatWithKeys(tbl, keySeparator, separator)
	keySeparator = keySeparator or ' = '
	separator = separator or ', '
	local concatted = ''
	local i = 1
	local first = true
	local unnamedArguments = true
	for k, v in pairs(tbl) do
		if first then
			first = false
		else
			concatted = concatted .. separator
		end
		if k == i and unnamedArguments then
			i = i + 1
			concatted = concatted .. tostring(v)
		else
			unnamedArguments = false
			concatted = concatted .. tostring(k) .. keySeparator .. tostring(v)
		end
	end
	return concatted
end

--- Compares two tables recursively (non-table values are handled correctly as well).
---
--- @param t1 any
--- @param t2 any
--- @param ignoreMetatable boolean|nil If false, t1.__eq is used for the comparison.
--- @return boolean
function DebugHelper.deepCompare(t1, t2, ignoreMetatable)
	local type1 = type(t1)
	local type2 = type(t2)

	if type1 ~= type2 then
		return false
	end
	if type1 ~= 'table' then
		return t1 == t2
	end

	local metatable = getmetatable(t1)
	if not ignoreMetatable and metatable and metatable.__eq then
		return t1 == t2
	end

	for k1, v1 in pairs(t1) do
		local v2 = t2[k1]
		if v2 == nil or not DebugHelper.deepCompare(v1, v2) then
			return false
		end
	end
	for k2, v2 in pairs(t2) do
		if t1[k2] == nil then
			return false
		end
	end

	return true
end

--- Raises an error with stack information.
---
--- @param details table Error details. Should have a 'text' key with the error message.
--- @param level number|nil Stack level offset.
function DebugHelper.raise(details, level)
	level = (level or 1) + 1
	details.trace = debug.traceback('', level)
	details.source = string.match(details.trace, '^%s*stack traceback:%s*(%S*: )')

	error(details, level)
end

--- Skips the current test.
function ScribuntoUnit:markTestSkipped()
	DebugHelper.raise({ ScribuntoUnit = true, skipped = true }, 3)
end

--- Unconditionally fails a test.
---
--- @param message string|nil Description shown on failure.
function ScribuntoUnit:fail(message)
	DebugHelper.raise({ ScribuntoUnit = true, text = 'Test failed', message = message }, 2)
end

--- Asserts that a value is truthy.
---
--- @param actual any The value to check.
--- @param message string|nil Description shown on failure.
--- @param level number|nil Stack level offset.
function ScribuntoUnit:assertTrue(actual, message, level)
	if not actual then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = string.format('Failed to assert that %s is true', tostring(actual)),
			message = message,
		}, 2 + (level or 0))
	end
end

--- Asserts that a value is falsy.
---
--- @param actual any The value to check.
--- @param message string|nil Description shown on failure.
--- @param level number|nil Stack level offset.
function ScribuntoUnit:assertFalse(actual, message, level)
	if actual then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = string.format('Failed to assert that %s is false', tostring(actual)),
			message = message,
		}, 2 + (level or 0))
	end
end

--- Asserts that a string contains a pattern or plain string.
---
--- @param pattern string The pattern or plain string to search for.
--- @param s string The string to search in.
--- @param plain boolean|nil If true, pattern is treated as a plain string.
--- @param message string|nil Description shown on failure.
--- @param level number|nil Stack level offset.
function ScribuntoUnit:assertStringContains(pattern, s, plain, message, level)
	if type(pattern) ~= 'string' then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = mw.ustring.format('Pattern type error (expected string, got %s)', type(pattern)),
			message = message,
		}, 2 + (level or 0))
	end
	if type(s) ~= 'string' then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = mw.ustring.format('String type error (expected string, got %s)', type(s)),
			message = message,
		}, 2 + (level or 0))
	end
	if not mw.ustring.find(s, pattern, nil, plain) then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = mw.ustring.format(
				'Failed to find %s "%s" in string "%s"',
				plain and 'plain string' or 'pattern',
				pattern,
				s
			),
			message = message,
		}, 2 + (level or 0))
	end
end

--- Asserts that a string does not contain a pattern or plain string.
---
--- @param pattern string The pattern or plain string to search for.
--- @param s string The string to search in.
--- @param plain boolean|nil If true, pattern is treated as a plain string.
--- @param message string|nil Description shown on failure.
--- @param level number|nil Stack level offset.
function ScribuntoUnit:assertNotStringContains(pattern, s, plain, message, level)
	if type(pattern) ~= 'string' then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = mw.ustring.format('Pattern type error (expected string, got %s)', type(pattern)),
			message = message,
		}, 2 + (level or 0))
	end
	if type(s) ~= 'string' then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = mw.ustring.format('String type error (expected string, got %s)', type(s)),
			message = message,
		}, 2 + (level or 0))
	end
	local i, j = mw.ustring.find(s, pattern, nil, plain)
	if i then
		local match = mw.ustring.sub(s, i, j)
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = mw.ustring.format(
				'Found match "%s" for %s "%s"',
				match,
				plain and 'plain string' or 'pattern',
				pattern
			),
			message = message,
		}, 2 + (level or 0))
	end
end

--- Asserts that two values are equal. Numbers are compared with a delta of 1e-8.
---
--- @param expected any The expected value.
--- @param actual any The actual value.
--- @param message string|nil Description shown on failure.
--- @param level number|nil Stack level offset.
function ScribuntoUnit:assertEquals(expected, actual, message, level)
	if type(expected) == 'number' and type(actual) == 'number' then
		self:assertWithinDelta(expected, actual, 1e-8, message, (level or 0) + 1)
	elseif expected ~= actual then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = string.format('Failed to assert that %s equals expected %s', tostring(actual), tostring(expected)),
			actual = actual,
			expected = expected,
			message = message,
		}, 2 + (level or 0))
	end
end

--- Asserts that two values are not equal. Numbers are compared with a delta of 1e-8.
---
--- @param expected any The value that actual should not equal.
--- @param actual any The actual value.
--- @param message string|nil Description shown on failure.
--- @param level number|nil Stack level offset.
function ScribuntoUnit:assertNotEquals(expected, actual, message, level)
	if type(expected) == 'number' and type(actual) == 'number' then
		self:assertNotWithinDelta(expected, actual, 1e-8, message, (level or 0) + 1)
	elseif expected == actual then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = string.format(
				'Failed to assert that %s does not equal expected %s',
				tostring(actual),
				tostring(expected)
			),
			actual = actual,
			expected = expected,
			message = message,
		}, 2 + (level or 0))
	end
end

--- Validates that both values are numbers.
---
--- @param expected any
--- @param actual any
--- @param message string|nil
--- @param level number
local function validateNumbers(expected, actual, message, level)
	if type(expected) ~= 'number' then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = string.format('Expected value %s is not a number', tostring(expected)),
			actual = actual,
			expected = expected,
			message = message,
		}, 3 + level)
	end
	if type(actual) ~= 'number' then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = string.format('Actual value %s is not a number', tostring(actual)),
			actual = actual,
			expected = expected,
			message = message,
		}, 3 + level)
	end
end

--- Asserts that actual is within delta of expected.
---
--- @param expected number The expected value.
--- @param actual number The actual value.
--- @param delta number The maximum allowed difference.
--- @param message string|nil Description shown on failure.
--- @param level number|nil Stack level offset.
function ScribuntoUnit:assertWithinDelta(expected, actual, delta, message, level)
	validateNumbers(expected, actual, message, level or 0)
	local diff = expected - actual
	if diff < 0 then
		diff = -diff
	end
	if diff > delta then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = string.format('Failed to assert that %f is within %f of expected %f', actual, delta, expected),
			actual = actual,
			expected = expected,
			message = message,
		}, 2 + (level or 0))
	end
end

--- Asserts that actual is not within delta of expected.
---
--- @param expected number The expected value.
--- @param actual number The actual value.
--- @param delta number The minimum required difference.
--- @param message string|nil Description shown on failure.
--- @param level number|nil Stack level offset.
function ScribuntoUnit:assertNotWithinDelta(expected, actual, delta, message, level)
	validateNumbers(expected, actual, message, level or 0)
	local diff = expected - actual
	if diff < 0 then
		diff = -diff
	end
	if diff <= delta then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = string.format('Failed to assert that %f is not within %f of expected %f', actual, delta, expected),
			actual = actual,
			expected = expected,
			message = message,
		}, 2 + (level or 0))
	end
end

--- Asserts that two tables are recursively equal, respecting metamethods.
---
--- @param expected any The expected value.
--- @param actual any The actual value.
--- @param message string|nil Description shown on failure.
--- @param level number|nil Stack level offset.
function ScribuntoUnit:assertDeepEquals(expected, actual, message, level)
	if not DebugHelper.deepCompare(expected, actual) then
		if type(expected) == 'table' then
			expected = mw.dumpObject(expected)
		end
		if type(actual) == 'table' then
			actual = mw.dumpObject(actual)
		end
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = string.format('Failed to assert that %s equals expected %s', tostring(actual), tostring(expected)),
			actual = actual,
			expected = expected,
			message = message,
		}, 2 + (level or 0))
	end
end

--- Asserts that wikitext preprocessing produces the expected result.
---
--- @param expected string The expected preprocessed output.
--- @param text string The wikitext to preprocess.
--- @param message string|nil Description shown on failure.
function ScribuntoUnit:assertResultEquals(expected, text, message)
	local frame = self.frame
	local actual = frame:preprocess(text)
	if expected ~= actual then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = string.format(
				'Failed to assert that %s equals expected %s after preprocessing',
				text,
				tostring(expected)
			),
			actual = actual,
			actualRaw = text,
			expected = expected,
			message = message,
		}, 2)
	end
end

--- Asserts that two wikitext strings produce the same preprocessed output.
---
--- @param text1 string First wikitext string.
--- @param text2 string Second wikitext string.
--- @param message string|nil Description shown on failure.
function ScribuntoUnit:assertSameResult(text1, text2, message)
	local frame = self.frame
	local processed1 = frame:preprocess(text1)
	local processed2 = frame:preprocess(text2)
	if processed1 ~= processed2 then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = string.format(
				'Failed to assert that %s equals expected %s after preprocessing',
				processed1,
				processed2
			),
			actual = processed1,
			actualRaw = text1,
			expected = processed2,
			expectedRaw = text2,
			message = message,
		}, 2)
	end
end

--- Asserts that a parser function produces the expected output.
---
--- @param expected string The expected output.
--- @param pfname string The parser function name.
--- @param args table The parser function arguments.
--- @param message string|nil Description shown on failure.
function ScribuntoUnit:assertParserFunctionEquals(expected, pfname, args, message)
	local frame = self.frame
	local actual = frame:callParserFunction({ name = pfname, args = args })
	if expected ~= actual then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = string.format(
				'Failed to assert that %s with args %s equals expected %s after preprocessing',
				DebugHelper.concatWithKeys(args),
				pfname,
				expected
			),
			actual = actual,
			actualRaw = pfname,
			expected = expected,
			message = message,
		}, 2)
	end
end

--- Asserts that a template expansion produces the expected output.
---
--- @param expected string The expected output.
--- @param template string The template name.
--- @param args table The template arguments.
--- @param message string|nil Description shown on failure.
function ScribuntoUnit:assertTemplateEquals(expected, template, args, message)
	local frame = self.frame
	local actual = frame:expandTemplate({ title = template, args = args })
	if expected ~= actual then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = string.format(
				'Failed to assert that %s with args %s equals expected %s after preprocessing',
				DebugHelper.concatWithKeys(args),
				template,
				expected
			),
			actual = actual,
			actualRaw = template,
			expected = expected,
			message = message,
		}, 2)
	end
end

--- Asserts that a function throws an error. Optionally checks the error message.
---
--- @param fn function The function to test.
--- @param expectedMessage any|nil The expected error message.
--- @param message string|nil Description shown on failure.
--- @param ... any Arguments to pass to fn.
function ScribuntoUnit:assertThrows(fn, expectedMessage, message, ...)
	local succeeded, actualMessage = pcall(fn, ...)
	if succeeded then
		DebugHelper.raise({
			ScribuntoUnit = true,
			text = 'Expected exception but none was thrown',
			message = message,
		}, 2)
	end
	-- For strings, strip the line number added to the error message
	actualMessage = type(actualMessage) == 'string' and string.match(actualMessage, 'Module:[^:]*:[0-9]*: (.*)')
		or actualMessage
	local messagesMatch = DebugHelper.deepCompare(expectedMessage, actualMessage)
	if expectedMessage and not messagesMatch then
		DebugHelper.raise({
			ScribuntoUnit = true,
			expected = expectedMessage,
			actual = actualMessage,
			text = string.format(
				'Expected exception with message %s, but got message %s',
				tostring(expectedMessage),
				tostring(actualMessage)
			),
			message = message,
		}, 2)
	end
end

--- Asserts that a function does not throw an error.
---
--- @param fn function The function to test.
--- @param message string|nil Description shown on failure.
--- @param ... any Arguments to pass to fn.
function ScribuntoUnit:assertDoesNotThrow(fn, message, ...)
	local succeeded, actualMessage = pcall(fn, ...)
	if succeeded then
		return
	end
	-- For strings, strip the line number added to the error message
	actualMessage = type(actualMessage) == 'string' and string.match(actualMessage, 'Module:[^:]*:[0-9]*: (.*)')
		or actualMessage
	DebugHelper.raise({
		ScribuntoUnit = true,
		actual = actualMessage,
		text = string.format('Expected no exception, but got exception with message %s', tostring(actualMessage)),
		message = message,
	}, 2)
end

--- Set up metatable
ScribuntoUnit.__meta.__index = ScribuntoUnit

--- @param key string
--- @param value any
function ScribuntoUnit.__meta:__newindex(key, value)
	if type(key) == 'string' and key:find('^test') and type(value) == 'function' then
		-- Store test functions in the order they were defined
		table.insert(self._tests, { name = key, test = value })
	else
		rawset(self, key, value)
	end
end

--- Creates a new test suite.
---
--- @return ScribuntoUnit
function ScribuntoUnit.new()
	local self = {}
	self._tests = {}

	setmetatable(self, ScribuntoUnit.__meta)
	self.run = function(frame)
		return ScribuntoUnit.run(self, frame)
	end

	return self
end

--- Resets counters and results.
---
--- @param frame mw.frame|nil
function ScribuntoUnit:init(frame)
	self.frame = frame or mw.getCurrentFrame()
	self.successCount = 0
	self.failureCount = 0
	self.skipCount = 0
	self.results = {}
end

--- Runs a single test case.
---
--- @param name string The test name.
--- @param test function The test function.
function ScribuntoUnit:runTest(name, test)
	local success, details = pcall(test, self)

	if success then
		self.successCount = self.successCount + 1
		table.insert(self.results, { name = name, success = true })
	elseif type(details) ~= 'table' or not details.ScribuntoUnit then -- a real error, not a failed assertion
		self.failureCount = self.failureCount + 1
		table.insert(self.results, { name = name, error = true, message = 'Lua error -- ' .. tostring(details) })
	elseif details.skipped then
		self.skipCount = self.skipCount + 1
		table.insert(self.results, { name = name, skipped = true })
	else
		self.failureCount = self.failureCount + 1
		local message = details.source or ''
		if details.message then
			message = message .. details.message .. '\n'
		end
		message = message .. details.text
		table.insert(self.results, {
			name = name,
			error = true,
			message = message,
			expected = details.expected,
			actual = details.actual,
			testname = details.message,
		})
	end
end

--- Runs all tests and returns the results.
---
--- @param frame mw.frame|nil
--- @return table
function ScribuntoUnit:runSuite(frame)
	self:init(frame)
	for i, testDetails in ipairs(self._tests) do
		self:runTest(testDetails.name, testDetails.test)
	end
	return {
		successCount = self.successCount,
		failureCount = self.failureCount,
		skipCount = self.skipCount,
		results = self.results,
	}
end

--- Entry point for running tests. Can be called without a frame.
---
--- @param frame mw.frame|nil
--- @return string
function ScribuntoUnit:run(frame)
	local testData = self:runSuite(frame)
	if frame and frame.args then
		return self:displayResults(testData, frame.args.displayMode or 'table')
	else
		return self:displayResults(testData, 'log')
	end
end

--- Displays test results in the given mode.
---
--- @param testData table
--- @param displayMode string 'table', 'log', or 'short'.
--- @return string
function ScribuntoUnit:displayResults(testData, displayMode)
	if displayMode == 'table' then
		return self:displayResultsAsTable(testData)
	elseif displayMode == 'log' then
		return self:displayResultsAsLog(testData)
	elseif displayMode == 'short' then
		return self:displayResultsAsShort(testData)
	else
		error('unknown display mode')
	end
end

--- @param testData table
function ScribuntoUnit:displayResultsAsLog(testData)
	if testData.failureCount > 0 then
		mw.log('FAILURES!!!')
	elseif testData.skipCount > 0 then
		mw.log(
			'Some tests could not be executed without a frame and have been skipped. Invoke this test suite as a template to run all tests.'
		)
	end
	mw.log(
		string.format(
			'Assertions: success: %d, error: %d, skipped: %d',
			testData.successCount,
			testData.failureCount,
			testData.skipCount
		)
	)
	mw.log('-------------------------------------------------------------------------------')
	for _, result in ipairs(testData.results) do
		if result.error then
			mw.log(string.format('%s: %s', result.name, result.message))
		end
	end
end

--- @param testData table
--- @return string
function ScribuntoUnit:displayResultsAsShort(testData)
	local text = string.format(cfg.shortResultsFormat, testData.successCount, testData.failureCount, testData.skipCount)
	if testData.failureCount > 0 then
		text = '<span class="error">' .. text .. '</span>'
	end
	return text
end

--- @param testData table
--- @return string
function ScribuntoUnit:displayResultsAsTable(testData)
	local successIcon, failIcon =
		self.frame:preprocess(cfg.successIndicator), self.frame:preprocess(cfg.failureIndicator)
	local text = ''
	if testData.failureCount > 0 then
		local msg = mw.message.newRawMessage(cfg.failureSummary, testData.failureCount):plain()
		msg = self.frame:preprocess(msg)
		if cfg.failureCategory then
			msg = cfg.failureCategory .. msg
		end
		text = text .. failIcon .. ' ' .. msg .. '\n'
	else
		text = text .. successIcon .. ' ' .. cfg.successSummary .. '\n'
	end
	text = text .. '{| class="wikitable scribunto-test-table"\n'
	text = text .. '!\n! ' .. cfg.nameString .. '\n! ' .. cfg.expectedString .. '\n! ' .. cfg.actualString .. '\n'
	for _, result in ipairs(testData.results) do
		text = text .. '|-\n'
		if result.error then
			text = text .. '| ' .. failIcon .. '\n| '
			if result.expected and result.actual then
				local name = result.name
				if result.testname then
					name = name .. ' / ' .. result.testname
				end
				text = text
					.. mw.text.nowiki(name)
					.. '\n| '
					.. mw.text.nowiki(tostring(result.expected))
					.. '\n| '
					.. mw.text.nowiki(tostring(result.actual))
					.. '\n'
			else
				text = text
					.. mw.text.nowiki(result.name)
					.. '\n| '
					.. ' colspan="2" | '
					.. mw.text.nowiki(result.message)
					.. '\n'
			end
		else
			text = text .. '| ' .. successIcon .. '\n| ' .. mw.text.nowiki(result.name) .. '\n|\n|\n'
		end
	end
	text = text .. '|}\n'
	return text
end

return ScribuntoUnit
