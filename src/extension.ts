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

    // Initialize directory stack with root
    const dirStack: { path: string; indent: number }[] = [{ path: fullRootPath, indent: -1 }];


    let currentPath = rootDir;  // Initialize outside the loop

    lines.forEach((line, i) => {
        const indent = line.search(/\S/);  // Calculate indentation level
        const cleanedLine = line.trim().replace(/│|├|└|─/g, '').trim();  // Clean the line from tree symbols
    
        console.log(`Processing line: "${line}" (cleaned: "${cleanedLine}", indent: ${indent})`);
    
        // Determine if this line describes a directory or a file
        const isDirectory = cleanedLine.endsWith('/') || !cleanedLine.includes('.');
        
        if (isDirectory) {
            // Create the directory
            const newDirPath = path.join(currentPath, cleanedLine.replace(/\/$/, ''));  // Remove trailing slash for directories
            fs.mkdirSync(newDirPath, { recursive: true });
            console.log(`Created directory: ${newDirPath}`);
            
            // Push the new directory onto the stack
            dirStack.push({ path: newDirPath, indent });
            console.log(`Pushed to stack:`, dirStack);
            
            // Update currentPath to this new directory
            currentPath = newDirPath;
        } else if (cleanedLine.includes('.')) {
            // Create the file in the current path
            const filePath = path.join(currentPath, cleanedLine);  // Join with the current path for files
            fs.writeFileSync(filePath, '');
            console.log(`Created file: ${filePath}`);
        }
    
        // Check if we need to pop from the stack after processing the current line
        const nextLine = lines[i + 1] || '';
        const nextIndent = nextLine.search(/\S/);
    
        // Only pop if the next line has a smaller indent (indicating the end of current directory processing)
        if (nextIndent < indent) {
            dirStack.pop();  // Pop the current directory
            // Update currentPath to reflect the new top of the stack
            currentPath = dirStack.length > 0 ? dirStack[dirStack.length - 1].path : rootDir;
            console.log(`Popped from stack. New current path: ${currentPath}`);
        }
    });
    

    // Final update to ensure the last state is correct
    if (dirStack.length === 0) {
        currentPath = rootDir; // Reset to root if we have emptied the stack
    }
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
