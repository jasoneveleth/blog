# Blog markup dialect

A small **djot subset** plus a few custom extensions. The site generator parses
this directly (no preprocessor). Input files live under `content/YYYY/MM/DD/name.md`.

Design goals: a regular, hand-parseable grammar; one block-extension mechanism
(`@@`); opaque spans for math/code so KaTeX/highlighting input is never mangled.

## Frontmatter

Each file opens with a `+++` fence containing a small TOML subset:

```
+++
title = "Solving the Game of 24"
date = 2025-11-03          # posted date (authoritative; mirrors the path)
updated = 2025-11-04       # optional; pin last-edited (see Dates)
tags = []
rss = "one-line summary"
draft = false              # optional
+++
```

Only `key = value` lines are supported: strings (`"..."`), dates (`YYYY-MM-DD`),
bools, and flat arrays. No nested tables, no expressions.

## Block grammar

Blocks are separated by blank lines. `@@` blocks nest via a stack.

| Construct | Syntax | Output |
|---|---|---|
| Heading | `#` … `######` then inline text | `<h1>`..`<h6>` |
| Fenced code | ` ```lang ` … ` ``` ` | opaque → `<pre><code class="language-lang">` |
| Div / directive | `@@name` … `@@` (or `@@name@@` for empty) | see below |
| Raw HTML | `~~~` … `~~~` | emitted verbatim |
| List | `- item` / `N. item`, indentation nests | `<ul>` / `<ol>` |
| Blockquote | `> text` | `<blockquote>` |
| Footnote def | `[^id]: text` | collected, rendered at foot of page |
| Paragraph | anything else | `<p>` |

### `@@` divs and directives

`@@name` opens a block, a line containing only `@@` closes it. Children are
parsed as markdown. Rendering dispatches on `name`:

- **Registered directive** (`toc`, `comments`): calls a generator function.
  `@@toc@@` emits the table-of-contents (with its own `<details>` wrapper);
  `@@comments@@` emits the utterances `<script>`.
- **Anything else**: `<div class="name">…children…</div>`. So `im-most`,
  `figure`, `warn`, etc. are just CSS classes — no code per name. Nest two to
  apply two classes (`@@figure` then `@@im-800`).

## Inline grammar

| Construct | Syntax | Notes |
|---|---|---|
| Inline code | `` `code` `` | **opaque** |
| Inline / display math | `$…$`, `$$…$$` | **opaque**, passed to KaTeX; `$$` matched before `$` |
| Inline raw HTML | `~~~…~~~` | **opaque** (e.g. `~~~<span class='date'>…</span>~~~`) |
| Bold | `*bold*` | single star (djot) |
| Italic | `_italic_` | single underscore (djot) |
| Link | `[text](url)` | |
| Image | `![alt](url)` | |
| Footnote ref | `[^id]` | |
| Escape | `\` + punctuation | literal character |

Text scanning stops on: `` ` `` `$` `~` `*` `_` `[` `!` `\` and newline.

**Invariant:** opaque spans (code, math, raw) are scanned only for their closing
delimiter. Their contents are never interpreted for `*`, `_`, `\`, etc. This is
what lets math-heavy posts (`\bm`, `\frac`, `\begin{align*}`) pass through intact.

## Disambiguation & edge cases

These are pinned against the actual corpus; see the golden posts noted.

- **List nesting** is by indentation *relative to the parent's content column*,
  not a fixed tab width. A list line nests under the innermost open list whose
  content column (the column after `marker + space` — col 2 for `- `, col 3 for
  `10. `) is `≤` the line's leading indent. The corpus has one nested list
  (`glium.md`, 4-space indent under `- `, single level); implement the relative
  rule so a future 2-space sublist also works. Lightly exercised — golden-test it.

- **`~~~` block vs inline**: a line whose *entire trimmed content* is `~~~`
  toggles a **block** raw fence (raw content runs on the following lines until the
  next bare-`~~~` line). A `~~~` that shares its line with other content is an
  **inline** raw span, scanned to the next `~~~` on that line (e.g.
  `~~~<span class='date'>11/03</span>~~~ [title](url)` in `index.md`).

- **Footnote labels** are any run of non-`]`, non-whitespace characters
  (`[^1]`, `[^note]`). Anchors use the literal label: `id="fndef:<label>"`,
  `#fnref:<label>`. The *visible* marker is a sequential counter in order of first
  reference. The corpus is integer-only and authored in order, so label and
  counter coincide (`[1]`, `[2]`) — either reproduces current output; prefer the
  counter so non-numeric labels still render cleanly. (Watch for false positives:
  `[^/]`-style regex/glob character classes inside code spans are **not**
  footnotes — the opaque-code-span invariant already protects these.)

## Dates

- **Posted date**: frontmatter `date` (authoritative; the `YYYY/MM/DD` path mirrors it).
- **Last edited**: frontmatter `updated` if present; otherwise derived from git
  (`git log -1 --format=%cI -- <path>`). Never file mtime (nondeterministic across
  checkouts). Add `updated` only to pin it when a trivial commit shouldn't count.
- Build must run in a full clone (CI: `fetch-depth: 0`). Uncommitted/untracked
  files fall back to the posted date.
