package systemmap

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// The committed pair this package exists to produce. They are read from the repo
// rather than copied into testdata: a golden file that is a copy of the real one
// only proves the copy is up to date.
var (
	committedSystems = filepath.Join("..", "..", "..", "pages", "module", "SystemMap", "systems.json")
	committedOverlay = filepath.Join("..", "..", "..", "pages", "module", "SystemMap", "overlay.json")
	// The page as it stood before this package took ownership of it: three
	// systems, typed by hand and edited on the wiki. See the note on
	// TestEncodeRoundTripsTheHandWrittenFile for why it is frozen here.
	handWrittenSystems = filepath.Join("testdata", "systems.hand-written.json")
	// What the wiki is serving, captured verbatim. This is the acceptance gate's
	// baseline; see TestReproducesTheLivePage for why it is not the repo copy.
	liveSystems = filepath.Join("testdata", "systems.live.json")
)

// TestEncodeRoundTripsTheHandWrittenFile checks the encoder against bytes nobody
// generated. Tab indentation, key order, the trailing newline, and float
// formatting (165.4 must not become 165.40000000000001, and 700 must not become
// 7e+02) all have to survive a decode and re-encode before the generator can be
// trusted to rewrite a page that 42 articles render.
//
// It reads the frozen pre-generator copy on purpose. Pointing it at the live
// systems.json was the obvious thing to do and was silently useless: that file
// IS this encoder's output now, so decode-then-encode is idempotent by
// construction and the assertion cannot fail. Changing Encode to two-space
// indent and re-running `mise run systemmap` rewrote the committed page in the
// wrong format with the whole suite green. The frozen copy is the only bytes
// left that the encoder did not author, and it still carries the 165.4, 700 and
// 835608 cases the float assertion is about.
func TestEncodeRoundTripsTheHandWrittenFile(t *testing.T) {
	want, err := os.ReadFile(handWrittenSystems)
	if err != nil {
		t.Fatal(err)
	}
	doc, err := Decode(want)
	if err != nil {
		t.Fatal(err)
	}
	got, err := Encode(doc)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != string(want) {
		t.Errorf("re-encoding %s changed it:\n%s", handWrittenSystems,
			firstDifference(string(want), string(got)))
	}
}

// TestEncodeWritesTabIndentedJSON pins the format directly, on bytes built in
// this test, so that it holds for output the frozen fixture has no example of.
// The round-trip above proves Encode preserves a format; this proves which one.
func TestEncodeWritesTabIndentedJSON(t *testing.T) {
	doc := &Document{Doc: "doc"}
	doc.Systems.Set("Vector", &System{
		Page:   "Vector system",
		Star:   Body{Page: "Vector (star)", Label: "Vector"},
		Bodies: []Body{{Page: "Vector I", Label: "Vector I"}},
	})
	b, err := Encode(doc)
	if err != nil {
		t.Fatal(err)
	}
	out := string(b)

	if !strings.HasSuffix(out, "}\n") || strings.HasSuffix(out, "}\n\n") {
		t.Errorf("want exactly one trailing newline, got %q", out[max(0, len(out)-4):])
	}
	for i, l := range strings.Split(strings.TrimSuffix(out, "\n"), "\n") {
		indent := len(l) - len(strings.TrimLeft(l, "\t"))
		if rest := l[indent:]; strings.HasPrefix(rest, " ") {
			t.Fatalf("line %d is space-indented, want tabs: %q", i+1, l)
		}
	}
	if !strings.Contains(out, "\n\t\"systems\": {\n\t\t\"Vector\": {\n\t\t\t\"page\": ") {
		t.Errorf("want tab-indented nesting, got:\n%s", out)
	}
}

// buildFromCommittedOverlay runs the generator the way the command does: the
// real overlay, against the seven-system fixture.
func buildFromCommittedOverlay(t *testing.T) *Document {
	t.Helper()
	overlayBytes, err := os.ReadFile(committedOverlay)
	if err != nil {
		t.Fatal(err)
	}
	overlay, err := LoadOverlay(overlayBytes)
	if err != nil {
		t.Fatal(err)
	}
	res, err := Build(Options{Starmap: loadFixture(t), Overlay: overlay})
	if err != nil {
		t.Fatal(err)
	}
	return res.Document
}

// TestReproducesTheLivePage is the acceptance gate.
//
// The generator's whole claim is that systems.json is derivable: upstream data
// plus written-down judgement, with nothing left in the file that only exists
// because somebody typed it there once. This test is what makes that claim
// checkable, and it is what a future refetch has to get past — if a correction
// stops applying, this fails, rather than the map quietly losing an icon.
//
// The baseline is the LIVE PAGE, not the repo copy, because the two had drifted.
// Revision 374302 ("Fix casing", 2026-08-13) lower-cased four belt designations
// on the wiki and was never mirrored back to git, so the committed file was
// stale — and a generator validated against a stale baseline would have quietly
// reverted a real editorial decision on 42 published pages the next time it ran.
// The casing is a derivation rule now (beltCase), which is what makes the live
// bytes reproducible rather than a correction to be transcribed.
//
// Only the three live systems are compared, and only their `systems` entries.
// Terra and Castra are not on the wiki yet; %doc and extents are this package's
// own output and are pinned by their own tests.
func TestReproducesTheLivePage(t *testing.T) {
	live := decodeFile(t, liveSystems)
	got := buildFromCommittedOverlay(t)

	if len(live.Systems.Keys()) == 0 {
		t.Fatalf("%s holds no systems", liveSystems)
	}
	for _, name := range live.Systems.Keys() {
		want, _ := live.Systems.Get(name)
		have, ok := got.Systems.Get(name)
		if !ok {
			t.Errorf("%s is live on the wiki but the generator no longer builds it", name)
			continue
		}
		wantJSON, haveJSON := encodeSystem(t, want), encodeSystem(t, have)
		if wantJSON == haveJSON {
			continue
		}
		t.Errorf("the generator no longer reproduces %s as the wiki serves it:\n%s\n\n"+
			"If upstream genuinely changed, refresh testdata/starmap.json (see testdata/README.md). "+
			"If a correction stopped applying, fix the overlay. If somebody edited the page by hand, "+
			"decide whether that edit is a derivation rule or an overlay entry, then re-capture "+
			"testdata/systems.live.json — never just delete the difference.",
			name, firstDifference(wantJSON, haveJSON))
	}
}

// TestReproducesTheCommittedFile keeps the repo copy honest about being the
// generator's output, which is what makes `mise run systemmap` a no-op on a
// clean tree and a reviewable diff otherwise.
//
// It covers Terra and Castra, which the live page does not have yet, and it is
// per-system for one reason: the committed file's `extents` are anchored to all
// 90 upstream systems, while this test builds from a seven-system fixture, so
// the two blocks legitimately differ. TestCommittedExtentsContainTheFixture
// checks the relation that must hold between them instead.
func TestReproducesTheCommittedFile(t *testing.T) {
	committed := decodeFile(t, committedSystems)
	got := buildFromCommittedOverlay(t)

	if committed.Doc != got.Doc {
		t.Errorf("%s carries a stale %%doc; re-run `mise run systemmap`", committedSystems)
	}
	if strings.Join(committed.Systems.Keys(), ", ") != strings.Join(got.Systems.Keys(), ", ") {
		t.Fatalf("system roster differs: committed %v, generated %v",
			committed.Systems.Keys(), got.Systems.Keys())
	}
	for _, name := range committed.Systems.Keys() {
		want, _ := committed.Systems.Get(name)
		have, _ := got.Systems.Get(name)
		wantJSON, haveJSON := encodeSystem(t, want), encodeSystem(t, have)
		if wantJSON == haveJSON {
			continue
		}
		t.Errorf("the generator no longer reproduces %s in %s:\n%s\n\n"+
			"If upstream genuinely changed, refresh testdata/starmap.json (see testdata/README.md) "+
			"and re-run `mise run systemmap`. If a correction stopped applying, fix the overlay.",
			name, committedSystems, firstDifference(wantJSON, haveJSON))
	}
}

func decodeFile(t *testing.T, path string) *Document {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	doc, err := Decode(b)
	if err != nil {
		t.Fatalf("%s: %v", path, err)
	}
	return doc
}

// encodeSystem renders one system the way Encode renders the whole file, so a
// per-system comparison still pins key order, tab indentation and float
// formatting.
func encodeSystem(t *testing.T, sys *System) string {
	t.Helper()
	b, err := json.MarshalIndent(sys, "", "\t")
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

// firstDifference reports the first line that differs, with its neighbours. A
// full diff of a 7 KB pretty-printed JSON file buries the one line that matters.
func firstDifference(want, got string) string {
	wantLines := strings.Split(want, "\n")
	gotLines := strings.Split(got, "\n")
	for i := 0; i < len(wantLines) || i < len(gotLines); i++ {
		w, g := line(wantLines, i), line(gotLines, i)
		if w == g {
			continue
		}
		var b strings.Builder
		for j := max(0, i-2); j < i; j++ {
			b.WriteString("  " + line(wantLines, j) + "\n")
		}
		b.WriteString("- baseline:  " + w + "\n")
		b.WriteString("+ generated: " + g + "\n")
		return b.String()
	}
	return "(the files differ only in length)"
}

func line(lines []string, i int) string {
	if i < 0 || i >= len(lines) {
		return "(end of file)"
	}
	return lines[i]
}
