---
name: doc-page-from-readme
description: Convert a local README.md (for a wiki module or template) into ready-to-push wikitext for the corresponding `<Namespace>:<Name>/doc` page. Use when deploying a doc page (called by deploy-to-wiki), or when the user asks to "preview the doc page" or "render the README as wikitext".
---

# doc-page-from-readme

Pure transformation skill: takes a README.md plus context (namespace, page name, optional module metadata) and returns a wikitext string ready to be pushed as the page's `/doc` subpage.

## When to invoke

- Deploy pipeline for any `<Namespace>:<Name>/doc` page — `deploy-to-wiki` delegates to this skill.
- Ad-hoc preview: user wants to see what the rendered wikitext will look like before pushing.
- Pre-commit validation: catch malformed READMEs (e.g. broken Parameters table) before they break the wiki.

## Inputs

- `readme` — README.md content (string) or absolute path.
- `namespace` — `"Module"` or `"Template"`. Drives some transformation choices (e.g. templatedata only applies to templates).
- `pageName` — the part after the colon (e.g. `InfoboxLua` or `Entity/Description`). Used to drop the H1 if it matches.
- `moduleMeta` — parsed `module.json` if present (modules only). Affects `{{documentation}}` flags. Optional.
- `wikiDomain` — default `starcitizen.tools`. Used for link internalization. Configurable so the skill works against other MediaWiki installs.

## Output

A single wikitext string. Caller is responsible for writing it to the wiki via the MediaWiki MCP server.

## Transformations (in order)

The README passes through these steps. Each step's output feeds the next.

### 1. Drop the H1 title

The first line matching `# <Namespace>:<pageName>` (or any `# ` heading at the very top) is removed along with the trailing blank line. Reason: redundant on the wiki page — the page title is already shown by MediaWiki's chrome.

### 2. Drop the `## Requirements` section

Remove the heading line `## Requirements` and everything until the next `## ` heading or end of file. Reason: GitHub readers need this; wiki readers get it from `Module:Documentation`'s rendered dependency list.

### 3. Drop the `## Architecture` section

Same mechanic as Requirements — the section is for contributors reading the source, not editors viewing the doc.

### 4. Generate `<templatedata>` (templates only)

If `namespace == "Template"` and a `## Parameters` section exists with a Markdown table:

1. Invoke the `templatedata-from-readme` skill on the (still-Markdown) README content.
2. Take its `<templatedata>` block output.
3. Replace the Parameters table (everything from the start of the table to the next `## ` heading or blank line followed by non-table content) with a single blank line + the `<templatedata>` block + a blank line. Keep the `## Parameters` heading.

If the namespace is `Module`, skip this step — module READMEs use a hand-written Data Reference, not TemplateData.

### 5. Internalize wiki links

For every Markdown link `[Text](URL)`:

- If `URL` starts with `https://<wikiDomain>/` (or `http://`):
  - Strip the prefix to get the page name.
  - URL-decode percent-escapes (`%20` → space).
  - Replace underscores with spaces.
  - If `Text` matches the resulting page name → emit `[[<Page>]]`.
  - Otherwise → emit `[[<Page>|<Text>]]`.
- Other URLs → leave unchanged.

This step runs before Markdown → wikitext so the link transformer sees the canonical Markdown link syntax.

### 6. Markdown → wikitext

Apply standard Markdown-to-wikitext conversions:

- **Headings**: `## X` → `== X ==`, `### X` → `=== X ===`, etc.
- **Bold**: `**X**` → `'''X'''`. **Italic**: `*X*` → `''X''`.
- **Inline code**: `` `X` `` → `<code>X</code>`.
- **Fenced code blocks**: ` ```lang\n...\n``` ` → `<syntaxhighlight lang="lang">...</syntaxhighlight>`. Bare ` ``` ` (no lang) → `<syntaxhighlight>...</syntaxhighlight>`.
- **Lists**: `-` and `*` bullets → wikitext `*`, numbered → `#`. Preserve nesting.
- **Tables**: `| ... |` Markdown tables → `{| class="wikitable"\n|-\n! header\n! header\n|-\n| cell\n| cell\n|}` form. The `<templatedata>` block from step 4 must NOT be re-processed — pass it through untouched.
- **Paragraphs**: collapse single newlines, preserve double newlines as paragraph breaks (mw default).

The `<templatedata>` block, once inserted, contains JSON that includes pipe-like sequences and braces. Treat anything between `<templatedata>` and `</templatedata>` as a literal pass-through region — do not apply Markdown rules inside it.

### 7. Prepend `{{documentation}}`

Build the documentation template invocation:

- Always include `git=true`.
- If `moduleMeta.origin == "wikipedia"` (modules only), add `fromWikipedia=true`.
- Examples:
  - `{{documentation|git=true}}` (default)
  - `{{documentation|git=true|fromWikipedia=true}}` (Wikipedia-imported module)

Prepend this template followed by a single blank line. Don't add it twice if the README already contains `{{documentation` somewhere — instead, halt with an error so the caller can investigate.

## Output discipline

- Trailing newline: exactly one. Strip extras.
- No leading whitespace before `{{documentation`.
- Internal blank lines preserved as in source.

## Edge cases

- **No `## Parameters` section in a Template README** → skip step 4 silently. The deployed doc just won't have a `<templatedata>` block. Acceptable when the template takes no params.
- **Broken Markdown table** (column count mismatch in Parameters) → propagate the error from `templatedata-from-readme`, don't try to repair.
- **Mixed link styles** (reference-style links `[Text][label]` rather than inline `[Text](url)`) → not supported in v1. Convert to inline before running the skill, or extend later.
- **Code block contains a `## Parameters` heading** → step 4 must scan only for headings outside fenced code blocks. Fence tracking required.
- **Page name with slash** (e.g. `Entity/Description`) → the H1 is `# Template:Entity/Description`; the slash is part of the page name, not a path separator at this stage.

## Validation

Before returning:

- Output is non-empty.
- Output starts with `{{documentation`.
- No `# ` (Markdown H1) lines remain at column 0 (would indicate the H1 strip missed).
- No Markdown link syntax (`[X](Y)`) remains where Y is a `starcitizen.tools` URL (would indicate step 5 missed).
- For templates with a Parameters section: a `<templatedata>` block exists.
