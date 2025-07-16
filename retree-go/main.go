// File: main.go
package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"path/filepath"
)

type DirEntry struct {
	Path   string
	Indent int
}

func calculateIndent(line string) int {
	count := 0
	for _, ch := range line {
		if strings.ContainsRune("│├└", ch) {
			count++
		}
	}
	return count
}

func stripTreeGlyphs(line string) string {
	return strings.TrimSpace(strings.Map(func(r rune) rune {
		if strings.ContainsRune("│├└─", r) {
			return -1
		}
		return r
	}, line))
}

func createFromTree(lines []string, root string) error {
	stack := []DirEntry{{Path: root, Indent: -1}}

	for _, line := range lines {
		line = strings.Split(line, "#")[0] // Strip comments
		line = strings.TrimRight(line, " ")
		if line == "" {
			continue
		}

		indent := calculateIndent(line)
		name := stripTreeGlyphs(line)
		isDir := strings.HasSuffix(name, "/")
		name = strings.TrimSuffix(name, "/")
		name = strings.TrimSuffix(name, "*")

		// Pop stack to correct parent level
		for len(stack) > 0 && stack[len(stack)-1].Indent >= indent {
			stack = stack[:len(stack)-1]
		}

		parent := root
		if len(stack) > 0 {
			parent = stack[len(stack)-1].Path
		}
		path := filepath.Join(parent, name)

		if isDir {
			err := os.MkdirAll(path, 0755)
			if err != nil {
				return fmt.Errorf("failed to create directory %q: %w", path, err)
			}
			stack = append(stack, DirEntry{Path: path, Indent: indent})
		} else {
			file, err := os.Create(path)
			if err != nil {
				return fmt.Errorf("failed to create file %q: %w", path, err)
			}
			file.Close()
		}
	}
	return nil
}

func main() {
	scanner := bufio.NewScanner(os.Stdin)
	var lines []string
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "Error reading input: %v\n", err)
		os.Exit(1)
	}

	if err := createFromTree(lines, "."); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
