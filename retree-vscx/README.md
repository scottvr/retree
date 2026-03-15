# retree

`retree` is a VS Code extension that performs the inverse of `tree -F`:
it creates directories/files from selected tree text. It is included as a subdirectory
in the repo https://github.com/scottvr/retree

## Usage

1. Select tree text in the editor.
2. Run `retree: Create Directories from Tree` from the Command Palette.
3. Enter a destination root directory, or accept the default workspace path.

## Example

1. Open a document with a `tree -F`-styke layout.
2. Highlight the tree text.
3. Run the command from the Command Palette.
4. Optionally change the destination root directory.
5. Files/directories are created under that root.
