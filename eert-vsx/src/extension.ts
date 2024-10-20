import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';

export function createFromTree(tree: string, rootDir: string = ".") {
    const lines = tree.split('\n').filter(line => line.trim() !== '');
    console.log(process.cwd()); 
    let currentPath = rootDir;
    let dirStack = [{ path: currentPath, indent: -1 }];
    
    // Helper function to calculate indentation based on replaced tree characters
    function calculateIndent(line: string): number {
        // Match both tree symbols and leading whitespace
        const match = line.match(/^[│├└─\s]+/g);
        const charCount = match ? match[0].length : 0;
    
        // Divide by 2, assuming two characters represent one indentation level
        return Math.floor(charCount / 2);
    }

    lines.forEach((line, i) => {
        const currentIndent = calculateIndent(line);  // New function to calculate indent based on tree characters
        const cleanedLine = line.trim().replace(/[│├└─]+/g, '').trim();  // Clean up tree symbols
    
        console.log(`Processing line: "${line}" (cleaned: "${cleanedLine}", indent: ${currentIndent})`);
    
        // Determine if this is a directory or a file
        const isDirectory = cleanedLine.endsWith('/') || !cleanedLine.includes('.');
    
        while (dirStack.length > 0 && dirStack[dirStack.length - 1].indent >= currentIndent) {
            dirStack.pop();
            // After popping, update currentPath based on the new top of the stack
            currentPath = dirStack.length > 0 ? dirStack[dirStack.length - 1].path : rootDir;
        }

        // If the stack is not empty, update currentPath to the last valid directory
        if (dirStack.length > 0) {
            currentPath = dirStack[dirStack.length - 1].path;
        }
    
        if (isDirectory) {
            // Create the new directory
            const newDirPath = path.join(currentPath, cleanedLine.replace(/\/$/, ''));  // Remove trailing slash
            fs.mkdirSync(newDirPath, { recursive: true });
            console.log(`Created directory: ${newDirPath}`);
    
            // Push the new directory onto the stack with its indent level
            dirStack.push({ path: newDirPath, indent: currentIndent });
            console.log(`Pushed to stack:`, dirStack);
    
            // Update currentPath to this new directory
            currentPath = newDirPath;
        } else {
            // Create the file in the current directory
            const filePath = path.join(currentPath, cleanedLine);  // Join with the current directory
            fs.writeFileSync(filePath, '');
            console.log(`Created file: ${filePath}`);
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
