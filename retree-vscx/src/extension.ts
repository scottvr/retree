import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';

type ParsedNode = {
    depth: number;
    name: string;
    explicitDirectory: boolean;
    explicitFile: boolean;
    explicitSymlink: boolean;
    executable: boolean;
};

type CreateResult = {
    createdDirs: number;
    createdFiles: number;
    errors: string[];
};

function stripInlineComment(line: string): string {
    // Heuristic: treat comment markers as comments only when preceded by whitespace.
    return line.replace(/\s+(?:#|;|\/\/|\/\*).*$/, '');
}

function countDepth(line: string): number {
    const indentPrefix = (line.match(/^[\s│├└┌┐┬┴┼╭╮╯╰─━═║╠╚╔╩╦╬|+`\\-]*/) || [''])[0];
    const normalized = indentPrefix
        .replace(/\t/g, '    ')
        .replace(/[│├└┌┐┬┴┼╭╮╯╰─━═║╠╚╔╩╦╬|+`\\-]/g, ' ');
    return Math.floor(normalized.length / 4);
}

function parseLine(rawLine: string): ParsedNode | null {
    const withoutComment = stripInlineComment(rawLine);
    if (!withoutComment.trim()) {
        return null;
    }

    const depth = countDepth(withoutComment);
    const trimmed = withoutComment.trim();

    const entryWithMarkers = trimmed.replace(/^[│├└┌┐┬┴┼╭╮╯╰─━═║╠╚╔╩╦╬|+`\\\-\s]+/, '').trim();
    if (!entryWithMarkers) {
        return null;
    }

    const explicitDirectory = entryWithMarkers.endsWith('/');
    const explicitSymlink = entryWithMarkers.endsWith('@');
    const executable = entryWithMarkers.endsWith('*');
    const explicitFile = explicitSymlink || executable || /\.[^./\s]+$/.test(entryWithMarkers);

    const name = entryWithMarkers.replace(/[/*@]+$/, '').trim();
    if (!name || name === '.' || name === '..') {
        return null;
    }

    return {
        depth,
        name,
        explicitDirectory,
        explicitFile,
        explicitSymlink,
        executable,
    };
}

function decideNodeKinds(nodes: ParsedNode[]): Array<ParsedNode & { isDirectory: boolean }> {
    return nodes.map((node, i) => {
        const next = nodes[i + 1];
        const inferredDirectory = Boolean(next && next.depth > node.depth);
        const isDirectory = node.explicitDirectory || (!node.explicitFile && inferredDirectory);
        return { ...node, isDirectory };
    });
}

export function createFromTree(tree: string, rootDir: string = '.'): CreateResult {
    const parsed = tree
        .split('\n')
        .map(parseLine)
        .filter((node): node is ParsedNode => node !== null);

    const nodes = decideNodeKinds(parsed);
    const errors: string[] = [];
    let createdDirs = 0;
    let createdFiles = 0;

    const stack = [{ path: rootDir, depth: -1 }];

    for (const node of nodes) {
        while (stack.length > 0 && stack[stack.length - 1].depth >= node.depth) {
            stack.pop();
        }

        const parentPath = stack.length > 0 ? stack[stack.length - 1].path : rootDir;
        const targetPath = path.join(parentPath, node.name);

        try {
            if (node.isDirectory) {
                fs.mkdirSync(targetPath, { recursive: true });
                createdDirs += 1;
                stack.push({ path: targetPath, depth: node.depth });
            } else {
                fs.mkdirSync(parentPath, { recursive: true });
                fs.writeFileSync(targetPath, '', { flag: 'w' });
                if (node.executable && process.platform !== 'win32') {
                    fs.chmodSync(targetPath, 0o744);
                }
                createdFiles += 1;
            }
        } catch (error) {
            const message = error instanceof Error ? error.message : String(error);
            errors.push(`${targetPath}: ${message}`);
        }
    }

    return { createdDirs, createdFiles, errors };
}

export function activate(context: vscode.ExtensionContext) {
    const disposable = vscode.commands.registerCommand('retree.createFromTree', async () => {
        const editor = vscode.window.activeTextEditor;
        if (!editor) {
            vscode.window.showWarningMessage('No active editor found.');
            return;
        }

        const selection = editor.selection;
        const selectedText = editor.document.getText(selection);
        if (!selectedText.trim()) {
            vscode.window.showWarningMessage('Select tree text first, then run Retree.');
            return;
        }

        const rootDirInput = await vscode.window.showInputBox({
            prompt: 'Enter the root directory for the tree (default: current workspace folder)',
            value: vscode.workspace.workspaceFolders?.[0]?.uri.fsPath || '.',
        });

        const rootDir = (rootDirInput || '.').trim() || '.';
        const result = createFromTree(selectedText, rootDir);

        if (result.errors.length > 0) {
            const firstError = result.errors[0];
            vscode.window.showWarningMessage(
                `Retree created ${result.createdDirs} dirs and ${result.createdFiles} files with ${result.errors.length} errors. First: ${firstError}`
            );
            return;
        }

        vscode.window.showInformationMessage(
            `Retree created ${result.createdDirs} directories and ${result.createdFiles} files.`
        );
    });

    context.subscriptions.push(disposable);
}

export function deactivate() {}
