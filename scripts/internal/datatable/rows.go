// Package datatable audits the live {{Data table}} calls: ScanGrids reads the
// rendered grids off a page so their row counts can be diffed across a change.
package datatable

import (
	"regexp"
	"sort"
	"strconv"
)

// Grid is one AGGrid container found in a page's rendered HTML, identified by
// the three REST path segments the extension embeds on it.
type Grid struct {
	PageID string
	Token  string
	Index  int
}

// aggridDiv matches one <div class="ext-aggrid" ...> opening tag, non-greedy
// so it stops at that div's own ">" rather than a later one; the extension's
// data-mw-aggrid-options attribute HTML-escapes its embedded JSON (`&quot;`
// for `"`), so no raw '>' appears inside it in practice.
var aggridDiv = regexp.MustCompile(`(?s)<div class="ext-aggrid"(.*?)>`)

// The three REST identifiers are extracted by attribute name, not position:
// the extension does not guarantee data-mw-aggrid-options (a long, escaped
// JSON blob) stays before or after them.
var (
	pageidAttr = regexp.MustCompile(`data-mw-aggrid-pageid="([^"]*)"`)
	tokenAttr  = regexp.MustCompile(`data-mw-aggrid-token="([^"]*)"`)
	indexAttr  = regexp.MustCompile(`data-mw-aggrid-index="([^"]*)"`)
)

// renderError matches Module:DataGrid's inline error markup (see fail() in
// DataGrid.lua). A page showing this never emits an ext-aggrid div for the
// failing call, so its row count cannot be read at all.
var renderError = regexp.MustCompile(`<strong class="error">Module:DataGrid`)

// ScanGrids finds every ext-aggrid container in a page's parsed HTML and
// reports whether a Module:DataGrid rendering error appears anywhere on the
// page. Grids are returned sorted by index.
func ScanGrids(html string) ([]Grid, bool) {
	var grids []Grid
	for _, m := range aggridDiv.FindAllStringSubmatch(html, -1) {
		attrs := m[1]
		pageid := firstMatch(pageidAttr, attrs)
		token := firstMatch(tokenAttr, attrs)
		indexStr := firstMatch(indexAttr, attrs)
		if pageid == "" || token == "" || indexStr == "" {
			continue
		}
		index, err := strconv.Atoi(indexStr)
		if err != nil {
			continue
		}
		grids = append(grids, Grid{PageID: pageid, Token: token, Index: index})
	}
	sort.Slice(grids, func(i, j int) bool { return grids[i].Index < grids[j].Index })
	return grids, renderError.MatchString(html)
}

func firstMatch(re *regexp.Regexp, s string) string {
	m := re.FindStringSubmatch(s)
	if m == nil {
		return ""
	}
	return m[1]
}
