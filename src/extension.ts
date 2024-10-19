import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';

function createFromTree(tree: string, rootDir: string = ".") {
    const lines = tree.split('\n').filter(line => line.trim() !== '');

    let fullRootPath = rootDir;
    if (lines[0].trim().endsWith('/')) {
        const root = lines[0].trim().replace(/\/$/, '');
        fullRootPath = path.join(rootDir, root);
        fs.mkdirSync(fullRootPath, { recursive: true });
        lines.shift();  // Remove the root from lines
    }

    const dirStack: { path: string; indent: number }[] = [{ path: fullRootPath, indent: -1 }];

    lines.forEach((line, i) => {
        const indent = line.search(/\S/);  // Find indentation level
        const cleanedLine = line.trim().replace(/│|├|└|─/g, '').trim();  // Remove tree decorations

        // Check if the line represents a directory or a file
        const isDirectory = cleanedLine.endsWith('/');  // Ends with `/` is treated as a directory
        const isFile = cleanedLine.includes('.');       // Contains `.` is treated as a file

        // Move up the directory stack as needed based on indentation
        while (dirStack.length > 0 && dirStack[dirStack.length - 1].indent >= indent) {
            dirStack.pop();
        }

        const currentPath = path.join(dirStack[dirStack.length - 1].path, cleanedLine);

        if (isDirectory) {
            fs.mkdirSync(currentPath, { recursive: true });
            dirStack.push({ path: currentPath, indent });  // Push the new directory to the stack
        } else if (isFile) {
            fs.writeFileSync(currentPath, '');  // Create the file
        }
    });
}

// Command implementation for the VS Code extension
export function activate(context: vscode.ExtensionContext) {
    const disposable = vscode.commands.registerCommand('extension.createFromTree', () => {
        const editor = vscode.window.activeTextEditor;

        if (editor) {
            const selection = editor.selection;
            const selectedText = editor.document.getText(selection);

            // Prompt user for the root directory, defaulting to current workspace folder
            vscode.window.showInputBox({ prompt: 'Enter the root directory for the tree (default: current directory)', value: vscode.workspace.workspaceFolders?.[0]?.uri.fsPath || '.' })
                .then(rootDir => {
                    rootDir = rootDir || '.'; // Use current directory if none is specified
                    createFromTree(selectedText, rootDir);
                    vscode.window.showInformationMessage('Directory tree created successfully!');
                });
        }
    });

    context.subscriptions.push(disposable);
}

export function deactivate() {}
