// Package docindex builds the page catalog in pages/README.md from the
// README.md beside every module and template. Each of those files is the source
// of a live /doc page, so its H1 is the page title and its first sentence is a
// reviewed one-line summary; the catalog is derived rather than hand-kept so it
// cannot drift from the pages that exist.
package docindex

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

const (
	StartMarker = "<!-- docindex:start -->"
	EndMarker   = "<!-- docindex:end -->"

	wikiBase = "https://starcitizen.tools/"
)

// Namespaces are the pages/ subdirectories that carry documented pages, in
// catalog order, with the title prefix each maps to.
var Namespaces = []struct{ Dir, Prefix string }{
	{"module", "Module:"},
	{"template", "Template:"},
}

// Entry is one catalog row.
type Entry struct {
	Title   string // wiki title, e.g. Module:Entity/Location
	Dir     string // path relative to pages/, where the catalog lives, e.g. module/Entity/Location
	Summary string // first sentence of the README's lead paragraph
}

var (
	mdLink   = regexp.MustCompile(`\[([^\]]*)\]\([^)]*\)`)
	mdStrong = regexp.MustCompile(`\*\*([^*]*)\*\*`)
	// A sentence ends at the first terminator followed by whitespace or the end
	// of the paragraph, unless the terminator closes a common abbreviation.
	sentenceEnd = regexp.MustCompile(`[.!?](\s|$)`)
)

// Scan walks pages/<namespace> for README.md files and returns one Entry per
// file, sorted by title within namespace order. It fails when a top-level
// module or template directory has no README, since every such page is
// expected to carry a /doc page.
func Scan(pagesDir string) ([]Entry, error) {
	var entries []Entry
	var missing []string
	for _, ns := range Namespaces {
		root := filepath.Join(pagesDir, ns.Dir)
		tops, err := os.ReadDir(root)
		if err != nil {
			return nil, err
		}
		for _, top := range tops {
			if top.IsDir() {
				if _, err := os.Stat(filepath.Join(root, top.Name(), "README.md")); err != nil {
					missing = append(missing, filepath.ToSlash(filepath.Join(ns.Dir, top.Name())))
				}
			}
		}
		var nsEntries []Entry
		err = filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
			if err != nil || d.IsDir() || d.Name() != "README.md" {
				return err
			}
			rel, _ := filepath.Rel(root, filepath.Dir(path))
			title := ns.Prefix + filepath.ToSlash(rel)
			e, err := readEntry(path, title)
			if err != nil {
				return err
			}
			e.Dir = filepath.ToSlash(filepath.Join(ns.Dir, rel))
			nsEntries = append(nsEntries, e)
			return nil
		})
		if err != nil {
			return nil, err
		}
		sort.Slice(nsEntries, func(i, j int) bool { return nsEntries[i].Title < nsEntries[j].Title })
		entries = append(entries, nsEntries...)
	}
	if len(missing) > 0 {
		return nil, fmt.Errorf("every top-level module and template directory needs a README.md (it becomes the page's /doc); missing under pages/ in:\n  %s", strings.Join(missing, "\n  "))
	}
	return entries, nil
}

// readEntry checks the README's H1 against the title its path implies and
// extracts the first sentence of the lead paragraph.
func readEntry(path, title string) (Entry, error) {
	f, err := os.Open(path)
	if err != nil {
		return Entry{}, err
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	sawH1 := false
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if !sawH1 {
			if line == "" {
				continue
			}
			if line != "# "+title {
				return Entry{}, fmt.Errorf("%s: first line must be %q, got %q", path, "# "+title, line)
			}
			sawH1 = true
			continue
		}
		if line == "" || strings.HasPrefix(line, "#") || strings.HasPrefix(line, "<!--") || strings.HasPrefix(line, "|") || strings.HasPrefix(line, ">") {
			continue
		}
		return Entry{Title: title, Summary: FirstSentence(line)}, sc.Err()
	}
	if err := sc.Err(); err != nil {
		return Entry{}, err
	}
	return Entry{}, fmt.Errorf("%s: no lead paragraph after the H1", path)
}

// FirstSentence reduces a Markdown paragraph to its first sentence as plain
// Markdown: links become their text, bold is unwrapped, inline code is kept.
func FirstSentence(paragraph string) string {
	s := mdLink.ReplaceAllString(paragraph, "$1")
	s = mdStrong.ReplaceAllString(s, "$1")
	s = strings.TrimSpace(s)
	for _, m := range sentenceEnd.FindAllStringIndex(s, -1) {
		head := s[:m[0]]
		if strings.HasSuffix(head, "e.g") || strings.HasSuffix(head, "i.e") || strings.HasSuffix(head, "vs") {
			continue
		}
		return strings.TrimSpace(s[:m[0]+1])
	}
	return s
}

// Render emits the catalog: one table per namespace, each row linking the
// title to its folder and its live /doc page.
func Render(entries []Entry) string {
	var b strings.Builder
	b.WriteString(StartMarker + "\n")
	for _, ns := range Namespaces {
		var rows []Entry
		for _, e := range entries {
			if strings.HasPrefix(e.Title, ns.Prefix) {
				rows = append(rows, e)
			}
		}
		if len(rows) == 0 {
			continue
		}
		fmt.Fprintf(&b, "\n### %s pages\n\n", strings.TrimSuffix(ns.Prefix, ":"))
		b.WriteString("| Page | Summary |\n|---|---|\n")
		for _, e := range rows {
			fmt.Fprintf(&b, "| [%s](%s) ([doc](%s%s/doc)) | %s |\n",
				e.Title, e.Dir, wikiBase, strings.ReplaceAll(e.Title, " ", "_"), strings.ReplaceAll(e.Summary, "|", `\|`))
		}
	}
	b.WriteString("\n" + EndMarker)
	return b.String()
}

// Splice replaces the block between the markers in readme with catalog, which
// must itself begin with StartMarker and end with EndMarker.
func Splice(readme, catalog string) (string, error) {
	start := strings.Index(readme, StartMarker)
	end := strings.Index(readme, EndMarker)
	if start < 0 || end < 0 || end < start {
		return "", fmt.Errorf("README has no %s … %s block", StartMarker, EndMarker)
	}
	return readme[:start] + catalog + readme[end+len(EndMarker):], nil
}
