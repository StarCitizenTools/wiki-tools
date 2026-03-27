# Module:ScribuntoUnit

Unit testing framework for Scribunto modules. Write test functions with assertions, run them from wiki pages or the Lua console, and get a pass/fail report.

## Usage

### Writing tests

Create a test module (e.g. `Module:MyModule/testcases`):

```lua
local myModule = require( 'Module:MyModule' )
local ScribuntoUnit = require( 'Module:ScribuntoUnit' )
local suite = ScribuntoUnit:new()

function suite:testAddition()
    self:assertEquals( 4, myModule.add( 2, 2 ) )
end

function suite:testName()
    self:assertStringContains( 'hello', myModule.greet( 'hello world' ), true )
end

return suite
```

Any function prefixed with `test` is treated as a test case. Other functions are ignored.

### Running tests

From a wiki page:

```
{{#invoke:MyModule/testcases|run}}
```

Compact output:

```
{{#invoke:MyModule/testcases|run|displayMode=short}}
```

From the Lua console:

```lua
require( 'Module:MyModule/testcases' ).run()
```

## Assertions

All assertions accept an optional `message` parameter as the last argument, shown on failure.

| Method | Description |
|---|---|
| `assertTrue(value)` | Value is truthy (not `false` or `nil`). |
| `assertFalse(value)` | Value is falsy (`false` or `nil`). |
| `assertEquals(expected, actual)` | Values are equal. Numbers use a delta of 1e-8. |
| `assertNotEquals(expected, actual)` | Values are not equal. |
| `assertDeepEquals(expected, actual)` | Tables are recursively equal, respecting metamethods. |
| `assertWithinDelta(expected, actual, delta)` | Numbers are within `delta` of each other. |
| `assertNotWithinDelta(expected, actual, delta)` | Numbers are not within `delta` of each other. |
| `assertStringContains(pattern, s, plain)` | String `s` matches `pattern`. Set `plain` to `true` for literal matching. |
| `assertNotStringContains(pattern, s, plain)` | String `s` does not match `pattern`. |
| `assertTemplateEquals(expected, template, args)` | Template expansion matches `expected`. |
| `assertResultEquals(expected, text)` | Wikitext preprocessing matches `expected`. |
| `assertSameResult(text1, text2)` | Two wikitext strings produce the same output after preprocessing. |
| `assertParserFunctionEquals(expected, pfname, args)` | Parser function output matches `expected`. |
| `assertThrows(fn, expectedMessage)` | Function throws an error. Optionally checks the error message. |
| `assertDoesNotThrow(fn)` | Function does not throw an error. |
| `fail()` | Unconditionally fail. |
| `markTestSkipped()` | Skip the current test. |
