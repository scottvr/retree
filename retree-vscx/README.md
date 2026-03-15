# retree

`retree` is a VS Code extension that performs the inverse of `tree -F`:
it creates directories/files from selected tree text. It is included as a subdirectory
in the repo https://github.com/scottvr/retree

## Usage

1. Select tree text in the editor.
2. Run `Retree: Create Directories from Tree` from the Command Palette.
3. Enter a destination root directory, or accept the default workspace path.

## Example

1. Open a document with a tree layout.
2. Highlight the tree text.
3. Run the command from the Command Palette.
4. Optionally change the destination root directory.
5. Files/directories are created under that root.

## Package As VSIX

```bash
npm ci
npm run compile
npm run package
```

This creates `retree-<version>.vsix` in the project root.

## Install Locally

```bash
code --install-extension retree-0.1.0.vsix
```

or use VS Code: `Extensions` -> `...` -> `Install from VSIX...`.

## Publish To Marketplace

1. Create a publisher in Azure DevOps/VS Marketplace.
2. Set `"publisher"` in `package.json` to that publisher ID.
3. Authenticate `vsce` with a Personal Access Token:

```bash
npx vsce login <publisher-id>
```

4. Publish:

```bash
npx vsce publish
```
