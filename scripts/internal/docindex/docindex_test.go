package docindex

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeFile(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func fixture(t *testing.T) string {
	t.Helper()
	root := t.TempDir()
	writeFile(t, filepath.Join(root, "module", "Entity", "README.md"),
		"# Module:Entity\n\nRenders the [SMW](https://example.org/x) infobox. Second sentence.\n")
	writeFile(t, filepath.Join(root, "module", "Entity", "Location", "README.md"),
		"# Module:Entity/Location\n\n**Kind** for systems, e.g. Stanton, with a `|` pipe. More.\n")
	writeFile(t, filepath.Join(root, "module", "Entity", "Facet", "Armor.lua"), "return {}\n")
	writeFile(t, filepath.Join(root, "template", "Data table", "README.md"),
		"# Template:Data table\n\n<!-- a comment -->\n\nBrowse table for a category.\n")
	return root
}

func TestScanCollectsSortedEntries(t *testing.T) {
	entries, err := Scan(fixture(t))
	if err != nil {
		t.Fatal(err)
	}
	got := make([]string, 0, len(entries))
	for _, e := range entries {
		got = append(got, e.Title+" | "+e.Dir+" | "+e.Summary)
	}
	want := []string{
		"Module:Entity | pages/module/Entity | Renders the SMW infobox.",
		"Module:Entity/Location | pages/module/Entity/Location | Kind for systems, e.g. Stanton, with a `|` pipe.",
		"Template:Data table | pages/template/Data table | Browse table for a category.",
	}
	if strings.Join(got, "\n") != strings.Join(want, "\n") {
		t.Errorf("entries:\n%s\nwant:\n%s", strings.Join(got, "\n"), strings.Join(want, "\n"))
	}
}

func TestScanRequiresTopLevelReadme(t *testing.T) {
	root := fixture(t)
	writeFile(t, filepath.Join(root, "module", "Orphan", "Orphan.lua"), "return {}\n")
	_, err := Scan(root)
	if err == nil || !strings.Contains(err.Error(), "pages/module/Orphan") {
		t.Fatalf("expected a missing-README error naming pages/module/Orphan, got %v", err)
	}
}

func TestScanRejectsWrongH1(t *testing.T) {
	root := fixture(t)
	writeFile(t, filepath.Join(root, "module", "Entity", "README.md"), "# Module:Entities\n\nLead.\n")
	_, err := Scan(root)
	if err == nil || !strings.Contains(err.Error(), `"# Module:Entity"`) {
		t.Fatalf("expected an H1 mismatch error, got %v", err)
	}
}

func TestFirstSentence(t *testing.T) {
	cases := map[string]string{
		"One. Two.":                           "One.",
		"Uses `a.b` values, e.g. x. Next.":    "Uses `a.b` values, e.g. x.",
		"No terminator at all":                "No terminator at all",
		"Ends with a question? Then more.":    "Ends with a question?",
		"A [link](https://x) and **bold**. Z": "A link and bold.",
	}
	for in, want := range cases {
		if got := FirstSentence(in); got != want {
			t.Errorf("FirstSentence(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestRenderAndSplice(t *testing.T) {
	entries, err := Scan(fixture(t))
	if err != nil {
		t.Fatal(err)
	}
	catalog := Render(entries)
	for _, want := range []string{
		"### Module pages",
		"### Template pages",
		"| [Module:Entity](pages/module/Entity) ([doc](https://starcitizen.tools/Module:Entity/doc)) | Renders the SMW infobox. |",
		"([doc](https://starcitizen.tools/Template:Data_table/doc))",
		"with a `\\|` pipe.",
	} {
		if !strings.Contains(catalog, want) {
			t.Errorf("catalog missing %q:\n%s", want, catalog)
		}
	}
	readme := "# Repo\n\nintro\n\n" + StartMarker + "\nstale\n" + EndMarker + "\n\n## After\n"
	out, err := Splice(readme, catalog)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(out, "stale") || !strings.HasPrefix(out, "# Repo\n\nintro\n\n"+StartMarker) || !strings.HasSuffix(out, EndMarker+"\n\n## After\n") {
		t.Errorf("splice result:\n%s", out)
	}
	if _, err := Splice("no markers", catalog); err == nil {
		t.Error("expected an error when the markers are absent")
	}
}
