# Retree Parser Capability Matrix and Canonical Spec

## Goal
Unify parser behavior across all four implementations:
- `retree-bash/retree.sh`
- `retree-python/retree.py`
- `retree-go/main.go`
- `retree-vscx/src/extension.ts`

## Current Capability Matrix
Legend: `Y` = supported, `P` = partial/inconsistent, `N` = not supported.

| Capability | Bash | Python | Go | VS Code TS |
|---|---:|---:|---:|---:|
| Unicode `tree -F` line-art (`│ ├ └ ─`) | Y | Y | Y | Y |
| Indent-only hierarchy (no line-art) | N | N | N | Y |
| ASCII line-art (`|`, `+`, `-`, `\\`) | P | N | N | P |
| Inline `#` comments | Y | Y | Y | Y |
| Inline `//` comments | N | N | N | Y |
| Inline `/*` comments | N | N | N | Y |
| Inline `;` comments | N | N | N | Y |
| Tabs in indentation | P | P | P | Y |
| Explicit directory marker `/` | Y | Y | Y | Y |
| Executable marker `*` parsing | Y | Y | Y | Y |
| Executable bit (`chmod +x`) | Y | N | N | N |
| Symlink marker `@` parsing | Y | N | N | N |
| Symlink creation behavior | P (placeholder file) | N | N | N |
| Directory inference by lookahead depth | N | N | N | Y |
| Per-entry error collection (continue on error) | P | N | N | Y |
| Root path override parameter | Y | Y | N (fixed `.`) | Y |
| DOS/Windows `tree` format intent | P (input format flag exists, converter stub) | N | N | N |

## Canonical Superset Spec (Target)

### 1. Input Forms
Parser accepts:
1. Unicode tree line-art (`tree -F` style).
2. ASCII tree line-art (`|`, `+`, `-`, `\\` branch styles).
3. Indent-only outlines (spaces/tabs only).

### 2. Comment Handling
- Strip inline comments only when marker is preceded by whitespace.
- Supported markers: `#`, `//`, `/*`, `;`.
- Ignore blank/comment-only lines.

### 3. Depth Model
- Normalize tabs to 4 spaces.
- Compute `depth = floor(prefix_visual_columns / 4)` where prefix includes whitespace + connector glyphs.
- Accept mixed connector/indent prefixes.

### 4. Entry Extraction
- Remove leading connector/prefix tokens.
- Preserve interior path characters and whitespace in names.
- Ignore empty entries and `.`/`..`.

### 5. Type Resolution Rules
Per parsed node:
1. `name/` => directory (explicit).
2. `name@` => symlink placeholder entry (explicit).
3. `name*` => file (explicit executable marker).
4. `name.ext` => file (explicit file heuristic).
5. Otherwise infer by lookahead: if next node is deeper, treat as directory; else file.

### 6. Creation Semantics
- Use stack-by-depth to resolve parent path.
- Always ensure parent directories exist before file creation.
- Directory: `mkdir -p` / recursive equivalent.
- File: create empty file if missing; overwrite behavior is implementation-defined but should be documented.
- Executable marker: set user-executable bit where supported.
- Symlink marker: for now create placeholder file (no target info in source text).

### 7. Error Handling
- Continue processing after per-entry errors.
- Return/report summary: created dirs, created files, error count, first error.

## Explicit Non-Goals (for now)
1. True symlink target reconstruction from tree output (target path is absent in plain tree text).
2. Round-tripping metadata (owner/perms/timestamps).
3. Full DOS `tree` parser with every switch variant.
4. CP437 byte-level decoding guarantees across all locales.

## Glaring Omissions To Consider Next
1. Optional strict mode to reject ambiguous entries instead of inferring.
2. Path traversal guardrails (`..`, absolute paths) for safer default behavior.
3. Conflict policy: skip/overwrite/prompt on existing files.
4. Shared cross-language golden test fixtures to prevent drift.

## Convergence Plan
1. Lock this spec.
2. Port parser core in each implementation to match sections 1-7.
3. Add a shared fixture folder with expected outputs and a tiny runner per language.
4. Verify parity before adding advanced formats.
