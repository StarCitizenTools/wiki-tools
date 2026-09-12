// Command docindex regenerates the page catalog in the repository README from
// the README.md beside every module and template.
//
//	docindex          # rewrite the block between the docindex markers in ../README.md
//	docindex -check   # exit 1 if that block is stale or a top-level page has no README
//
// Unlike the other tools here it neither reads the wiki nor produces wiki
// content: its input is the repository and its output is the repository README.
package main

import (
	"bytes"
	"flag"
	"fmt"
	"os"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/docindex"
)

func main() {
	pages := flag.String("pages", "../pages", "pages/ directory to scan")
	readme := flag.String("readme", "../README.md", "README to rewrite")
	check := flag.Bool("check", false, "report drift instead of writing; exit 1 when the catalog is stale")
	flag.Parse()

	if err := run(*pages, *readme, *check); err != nil {
		fmt.Fprintln(os.Stderr, "docindex:", err)
		os.Exit(1)
	}
}

func run(pages, readmePath string, check bool) error {
	entries, err := docindex.Scan(pages)
	if err != nil {
		return err
	}
	current, err := os.ReadFile(readmePath)
	if err != nil {
		return err
	}
	next, err := docindex.Splice(string(current), docindex.Render(entries))
	if err != nil {
		return err
	}
	if bytes.Equal(current, []byte(next)) {
		fmt.Printf("%s: catalog up to date (%d pages)\n", readmePath, len(entries))
		return nil
	}
	if check {
		return fmt.Errorf("%s: page catalog is stale; run `mise run docindex`", readmePath)
	}
	if err := os.WriteFile(readmePath, []byte(next), 0o644); err != nil {
		return err
	}
	fmt.Printf("%s: catalog rewritten (%d pages)\n", readmePath, len(entries))
	return nil
}
