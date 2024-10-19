import * as assert from 'assert';
import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { activate, deactivate, createFromTree } from '../extension'; // Adjust the path as necessary

suite('EERT Extension Test Suite', () => {
    const testRootDir = path.join(__dirname, 'testDir'); // Temporary test directory

    // Setup: Create a temporary directory for testing
    setup(() => {
        if (!fs.existsSync(testRootDir)) {
            fs.mkdirSync(testRootDir);
        }
    });

    // Cleanup: Remove the test directory after tests
    teardown(() => {
        fs.rmdirSync(testRootDir, { recursive: true });
    });

    test('Create directory structure from tree', async () => {
        const tree = `
        └── parent/
            ├── child1/
            └── child2/
                └── grandchild.txt
        `;

        // Simulate the command execution
        await createFromTree(tree, testRootDir);

        // Check that the directories and files were created as expected
        const parentDir = path.join(testRootDir, 'parent');
        const child1Dir = path.join(parentDir, 'child1');
        const child2Dir = path.join(parentDir, 'child2');
        const grandchildFile = path.join(child2Dir, 'grandchild.txt');

        assert.ok(fs.existsSync(parentDir), 'Parent directory should exist');
        assert.ok(fs.existsSync(child1Dir), 'Child1 directory should exist');
        assert.ok(fs.existsSync(child2Dir), 'Child2 directory should exist');
        assert.ok(fs.existsSync(grandchildFile), 'Grandchild file should exist');
    });

    test('Create empty directory from tree', async () => {
        const tree = `
        └── emptyDir/
        `;

        await createFromTree(tree, testRootDir);

        const emptyDir = path.join(testRootDir, 'emptyDir');
        assert.ok(fs.existsSync(emptyDir), 'Empty directory should exist');
    });

    test('Handle invalid tree structure gracefully', async () => {
        const invalidTree = `
        └── invalid/
            ├── 
        `;

        await createFromTree(invalidTree, testRootDir);

        const invalidDir = path.join(testRootDir, 'invalid');
        assert.ok(fs.existsSync(invalidDir), 'Invalid directory should still exist even if empty');
    });

    // Additional tests can be added as needed
});
