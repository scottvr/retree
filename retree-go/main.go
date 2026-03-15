package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
)

type parsedNode struct {
	Depth             int
	Name              string
	ExplicitDirectory bool
	ExplicitFile      bool
	ExplicitSymlink   bool
	Executable        bool
	IsDirectory       bool
}

type createResult struct {
	CreatedDirs  int
	CreatedFiles int
	Errors       []string
}

var (
	commentRe   = regexp.MustCompile(`\s+(?:#|;|//|/\*).*$`)
	leadingRe   = regexp.MustCompile(`^[\s│├└┌┐┬┴┼╭╮╯╰─━═║╠╚╔╩╦╬|+` + "`" + `\\-]*`)
	treeStripRe = regexp.MustCompile(`^[\s│├└┌┐┬┴┼╭╮╯╰─━═║╠╚╔╩╦╬|+` + "`" + `\\-]+`)
	treeCharsRe = regexp.MustCompile(`[│├└┌┐┬┴┼╭╮╯╰─━═║╠╚╔╩╦╬|+` + "`" + `\\-]`)
	extRe       = regexp.MustCompile(`\.[^./\s]+$`)
	trailRe     = regexp.MustCompile(`[/*@]+$`)
)

func stripInlineComment(line string) string {
	return commentRe.ReplaceAllString(line, "")
}

func countDepth(line string) int {
	prefix := leadingRe.FindString(line)
	normalized := strings.ReplaceAll(prefix, "\t", "    ")
	normalized = treeCharsRe.ReplaceAllString(normalized, " ")
	return len([]rune(normalized)) / 4
}

func parseLine(rawLine string) *parsedNode {
	withoutComment := stripInlineComment(rawLine)
	if strings.TrimSpace(withoutComment) == "" {
		return nil
	}

	depth := countDepth(withoutComment)
	trimmed := strings.TrimSpace(withoutComment)
	entryWithMarkers := strings.TrimSpace(treeStripRe.ReplaceAllString(trimmed, ""))
	if entryWithMarkers == "" {
		return nil
	}

	explicitDirectory := strings.HasSuffix(entryWithMarkers, "/")
	explicitSymlink := strings.HasSuffix(entryWithMarkers, "@")
	executable := strings.HasSuffix(entryWithMarkers, "*")
	explicitFile := explicitSymlink || executable || extRe.MatchString(entryWithMarkers)

	name := strings.TrimSpace(trailRe.ReplaceAllString(entryWithMarkers, ""))
	if name == "" || name == "." || name == ".." {
		return nil
	}

	return &parsedNode{
		Depth:             depth,
		Name:              name,
		ExplicitDirectory: explicitDirectory,
		ExplicitFile:      explicitFile,
		ExplicitSymlink:   explicitSymlink,
		Executable:        executable,
	}
}

func decideNodeKinds(nodes []parsedNode) []parsedNode {
	result := make([]parsedNode, len(nodes))
	for i, node := range nodes {
		nextDeeper := i+1 < len(nodes) && nodes[i+1].Depth > node.Depth
		node.IsDirectory = node.ExplicitDirectory || (!node.ExplicitFile && nextDeeper)
		result[i] = node
	}
	return result
}

func createFromTree(lines []string, root string) createResult {
	parsed := make([]parsedNode, 0, len(lines))
	for _, line := range lines {
		node := parseLine(line)
		if node != nil {
			parsed = append(parsed, *node)
		}
	}

	nodes := decideNodeKinds(parsed)
	result := createResult{}

	stackPaths := []string{root}
	stackDepths := []int{-1}

	for _, node := range nodes {
		for len(stackDepths) > 0 && stackDepths[len(stackDepths)-1] >= node.Depth {
			stackDepths = stackDepths[:len(stackDepths)-1]
			stackPaths = stackPaths[:len(stackPaths)-1]
		}

		parent := root
		if len(stackPaths) > 0 {
			parent = stackPaths[len(stackPaths)-1]
		}
		target := filepath.Join(parent, node.Name)

		if node.IsDirectory {
			if err := os.MkdirAll(target, 0o755); err != nil {
				result.Errors = append(result.Errors, fmt.Sprintf("%s: %v", target, err))
				continue
			}
			result.CreatedDirs++
			stackPaths = append(stackPaths, target)
			stackDepths = append(stackDepths, node.Depth)
			continue
		}

		if err := os.MkdirAll(parent, 0o755); err != nil {
			result.Errors = append(result.Errors, fmt.Sprintf("%s: %v", target, err))
			continue
		}
		file, err := os.OpenFile(target, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o644)
		if err != nil {
			result.Errors = append(result.Errors, fmt.Sprintf("%s: %v", target, err))
			continue
		}
		_ = file.Close()

		if node.Executable && runtime.GOOS != "windows" {
			if chmodErr := os.Chmod(target, 0o744); chmodErr != nil {
				result.Errors = append(result.Errors, fmt.Sprintf("%s: %v", target, chmodErr))
			}
		}

		result.CreatedFiles++
	}

	return result
}

func main() {
	root := "."
	if len(os.Args) > 1 && strings.TrimSpace(os.Args[1]) != "" {
		root = os.Args[1]
	}

	scanner := bufio.NewScanner(os.Stdin)
	var lines []string
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}
	if err := scanner.Err(); err != nil {
		fmt.Fprintf(os.Stderr, "Error reading input: %v\n", err)
		os.Exit(1)
	}

	result := createFromTree(lines, root)
	if len(result.Errors) > 0 {
		fmt.Fprintf(
			os.Stderr,
			"retree: created %d dirs and %d files with %d errors\nfirst error: %s\n",
			result.CreatedDirs,
			result.CreatedFiles,
			len(result.Errors),
			result.Errors[0],
		)
		os.Exit(1)
	}
}
