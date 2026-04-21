---
name: templatedata-from-readme
description: Convert a Markdown Parameters table in a wiki template README to a `<templatedata>` JSON block ready for embedding on a Template namespace doc page. Use when deploying a Template:* page's README to its /doc subpage (called by deploy-to-wiki), or when the user asks to "generate templatedata" / "preview templatedata" for a README.
---

# templatedata-from-readme

Pure transformation skill: takes a README.md following the wiki-tools template-doc convention and returns a `<templatedata>` block that mirrors the Parameters table.

## When to invoke

- Deploy pipeline for a `Template:*/doc` page — `deploy-to-wiki` delegates to this skill.
- Ad-hoc preview: user wants to see the TemplateData JSON before deploy.
- Pre-commit validation: catch malformed Parameters tables before they break the wiki.

## Input format

A README.md following the wiki-tools convention. The Parameters table can be **6 columns** (Label is derived from Name) or **7 columns** (Label provided explicitly). The skill detects column count from the header row.

**6-column form (default):**

```markdown
# Template:Foo/Bar

One-paragraph intro describing what the template renders. This becomes
the TemplateData top-level `description`.

## Usage
...

## Parameters

| Name | Type | Required | Default | Description | Example |
|------|------|----------|---------|-------------|---------|
| `paramA` | string | Yes |  | Brief desc. | `value` |
| `paramB` | number | No | `0` | Another desc. | `42` |
| `paramC` | string | No | (falls back to lookup) | Optional with prose default. | `xyz` |

## Behavior
...
```

**7-column form (explicit Label, useful for acronyms/abbreviations):**

```markdown
| Name | Label | Type | Required | Default | Description | Example |
|------|-------|------|----------|---------|-------------|---------|
| `uuid` | UUID | string | No | (falls back to SMW) | Entity UUID. | `80ee3b95-...` |
| `paramB` | Param B | number | No | `0` | Another desc. | `42` |
```

## Output format

A wikitext block:

```
<templatedata>
{
    "description": "<intro paragraph text>",
    "params": {
        "paramA": { "label": "ParamA", "description": "Brief desc.", "type": "string", "required": true, "example": "value" },
        "paramB": { "label": "ParamB", "description": "Another desc.", "type": "number", "required": false, "default": "0", "example": "42" },
        "paramC": { "label": "ParamC", "description": "Optional with prose default.", "type": "string", "required": false, "example": "xyz" }
    },
    "paramOrder": ["paramA", "paramB", "paramC"],
    "format": "inline"
}
</templatedata>
```

## Conversion rules

Column indices below assume the 6-column form. For the 7-column form, shift Type/Required/Default/Description/Example one cell right and read Label from cell 2.

| README cell | TemplateData field | Rule |
|-------------|--------------------|------|
| Name | key in `params` | Strip backticks. Used verbatim. |
| Label (optional, 7-col only) | `label` | Use the cell value as-is (preserves acronym casing like "UUID"). |
| Type | `type` | Lowercase. Validate against vocabulary (see below). Fall back to `unknown` and warn if unrecognized. |
| Required | `required` | `Yes` / `Y` / `true` → `true`; everything else → `false`. |
| Default | `default` | Wrapped in parens (e.g. `(falls back to ...)`) → prose, omit from JSON. Wrapped in backticks → strip and use as string. Empty cell → omit. |
| Description | `description` | Plain string. Strip surrounding whitespace. |
| Example | `example` | Strip backticks. Empty cell → omit. |
| Top-level | `description` | First paragraph after the H1 title. **Strip link syntax to plain text** — both Markdown `[Text](URL)` → `Text` and wikitext `[[Page\|Text]]` → `Text`, `[[Page]]` → `Page`. TemplateData descriptions are rendered as plain text by VisualEditor; link syntax leaks through ugly. |
| Top-level | `paramOrder` | Order of rows in the table. |
| Top-level | `format` | Default `inline`. Override via HTML comment in the README: `<!-- templatedata: format=block -->`. |
| Derived `label` (6-col only) | `label` | Name with first letter capitalized; underscores replaced with spaces. For acronyms or other custom labels, use the 7-column form. |

### Type vocabulary

Validated against MediaWiki's TemplateData type list:

`string`, `number`, `boolean`, `wiki-page-name`, `wiki-user-name`, `wiki-template-name`, `wiki-file-name`, `date`, `url`, `line`, `unbalanced-wikitext`, `content`, `unknown`.

Unrecognized types fall back to `unknown` with a warning printed to the user.

## Process

1. **Locate the H1 title** (first `# ...` line). Everything after it up to the next blank line is the top-level `description`.
2. **Find the Parameters section** — heading `## Parameters` followed by a Markdown table. If absent, return `nil` and tell the caller (the template has no params; the caller decides whether to omit the block or report an error).
3. **Parse the table** — header row, separator (`|---|---|...`), then body rows. Detect form by the header: `Name | Type | Required | Default | Description | Example` is 6-column; `Name | Label | Type | Required | Default | Description | Example` is 7-column. Reject other shapes — halt with an error pointing at the offending row.
4. **Apply the conversion rules above** to each row.
5. **Look for HTML comment overrides** anywhere in the README:
   - `<!-- templatedata: format=block -->` → `format: "block"`
   - `<!-- templatedata: format=inline -->` → `format: "inline"`
6. **Emit the block** with the JSON pretty-printed and wrapped in `<templatedata>...</templatedata>`.

## Edge cases

- **No Parameters section** → return `nil`.
- **Empty table body** (header only) → emit `<templatedata>` with empty `params` so VisualEditor doesn't show "Unknown template parameters".
- **Pipe character in cell content** must be escaped as `\|` per CommonMark; the parser must respect that.
- **Multi-line cell content** — Markdown tables don't natively support newlines in cells. Use `<br>` (HTML) — passes through to TemplateData fine.
- **Aliases / suggested / autovalue / sets / maps** — not supported by the basic 6-column table. Either add escape-hatch HTML comments later, or extend the table when needed. v1 doesn't handle these; report as out-of-scope.

## Output discipline

- JSON must be valid and parseable. Use a JSON serializer, not string concatenation.
- 4-space indent for the JSON body (matches existing on-wiki style).
- Never inject extra whitespace before `<templatedata>` or after `</templatedata>` — callers control surrounding whitespace.

## Validation

Before emitting:

- All `params` keys are non-empty after backtick stripping.
- All `type` values are in the vocabulary (or warned-and-coerced to `unknown`).
- `paramOrder` covers every key in `params`, in the same order they appeared.
- Top-level `description` is a non-empty string.
