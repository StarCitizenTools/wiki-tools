# Module:ScribuntoUnit

Unit testing framework for [Scribunto](https://www.mediawiki.org/wiki/Extension:Scribunto) modules: write test functions with assertions, run them from a wiki page or the Lua console, and get a pass/fail report. This copy is the wiki-mirrored source for the standalone [mediawiki-scribuntounit](https://github.com/StarCitizenTools/mediawiki-scribuntounit) project, which also provides the headless runner `mise run test` uses off-wiki (see `tests/README.md`).

Required by every `Module:X/testcases` suite in this repository; not invoked from templates.

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
