package datatable

import "testing"

// twoGridsOneError mirrors a page carrying three {{Data table}} calls: two
// render fine (their ext-aggrid attributes deliberately in different orders,
// since the extension does not promise one), the third fails and leaves only
// the inline error text with no container at all.
const twoGridsOneError = `<div class="t-datagrid"><div class="ext-aggrid" data-mw-aggrid-options="{&quot;a&quot;:1}" data-mw-aggrid-pageid="101" data-mw-aggrid-token="tok-a" data-mw-aggrid-index="0" aria-busy="true"></div></div>
<p>Some prose in between.</p>
<div class="t-datagrid"><div class="ext-aggrid" data-mw-aggrid-index="1" data-mw-aggrid-token="tok-b" data-mw-aggrid-options="{&quot;b&quot;:2}" data-mw-aggrid-pageid="101" aria-busy="true"></div></div>
<strong class="error">Module:DataGrid: "conditions" is not supported; use "filter" (see Template:Data table)</strong>`

func TestScanGridsFindsBothContainersAndTheError(t *testing.T) {
	grids, hasError := ScanGrids(twoGridsOneError)
	if !hasError {
		t.Fatal("hasError = false, want true")
	}
	want := []Grid{
		{PageID: "101", Token: "tok-a", Index: 0},
		{PageID: "101", Token: "tok-b", Index: 1},
	}
	if len(grids) != len(want) {
		t.Fatalf("grids = %+v, want %+v", grids, want)
	}
	for i := range want {
		if grids[i] != want[i] {
			t.Errorf("grids[%d] = %+v, want %+v", i, grids[i], want[i])
		}
	}
}

func TestScanGridsCleanPageHasNoError(t *testing.T) {
	html := `<div class="ext-aggrid" data-mw-aggrid-pageid="7897" data-mw-aggrid-token="deadbeef" data-mw-aggrid-index="0"></div>`
	grids, hasError := ScanGrids(html)
	if hasError {
		t.Error("hasError = true, want false")
	}
	if len(grids) != 1 || grids[0] != (Grid{PageID: "7897", Token: "deadbeef", Index: 0}) {
		t.Errorf("grids = %+v", grids)
	}
}

func TestScanGridsNoContainerNoError(t *testing.T) {
	grids, hasError := ScanGrids(`<p>No grid on this page.</p>`)
	if hasError {
		t.Error("hasError = true, want false")
	}
	if len(grids) != 0 {
		t.Errorf("grids = %+v, want none", grids)
	}
}

func TestScanGridsSkipsAContainerMissingAnIdentifier(t *testing.T) {
	// A container with no token attribute cannot be queried, so it must not
	// produce a Grid with a zero-value token that would silently mis-key a
	// REST request.
	html := `<div class="ext-aggrid" data-mw-aggrid-pageid="1" data-mw-aggrid-index="0"></div>`
	grids, _ := ScanGrids(html)
	if len(grids) != 0 {
		t.Errorf("grids = %+v, want none (token missing)", grids)
	}
}
