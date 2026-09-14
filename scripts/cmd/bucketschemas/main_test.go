package main

import (
	"os"
	"path/filepath"
	"testing"
)

const oneBucketManifest = `{
	"%doc": "fixture",
	"Uuid": {
		"type": "TEXT", "bucket": "entity", "field": "uuid",
		"index": true, "modules": ["Base"], "desc": "x"
	}
}`

func writeManifest(t *testing.T, dir, contents string) string {
	t.Helper()
	path := filepath.Join(dir, "properties.json")
	if err := os.WriteFile(path, []byte(contents), 0o600); err != nil {
		t.Fatalf("writing manifest fixture: %v", err)
	}
	return path
}

func TestRunCheckPassesWhenSchemasCurrent(t *testing.T) {
	dir := t.TempDir()
	manifest := writeManifest(t, dir, oneBucketManifest)
	outDir := filepath.Join(dir, "out")
	if err := os.Mkdir(outDir, 0o700); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := run([]string{manifest}, outDir, false); err != nil {
		t.Fatalf("generate: %v", err)
	}
	if err := run([]string{manifest}, outDir, true); err != nil {
		t.Fatalf("check on freshly generated schemas: %v", err)
	}
}

// A stray pages/bucket/<Name>.json with no generating bucket (a renamed or
// retired bucket) must fail -check even though every schema the manifest DOES
// produce is up to date: nothing above already reports it, so without this
// check the deploy skill's pages/bucket/*.json -> Bucket:<Name> rule would
// recreate a table that was meant to be gone.
func TestRunCheckFlagsOrphanSchemaFile(t *testing.T) {
	dir := t.TempDir()
	manifest := writeManifest(t, dir, oneBucketManifest)
	outDir := filepath.Join(dir, "out")
	if err := os.Mkdir(outDir, 0o700); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	if err := run([]string{manifest}, outDir, false); err != nil {
		t.Fatalf("generate: %v", err)
	}
	orphan := filepath.Join(outDir, "Old bucket.json")
	if err := os.WriteFile(orphan, []byte("{}\n"), 0o600); err != nil {
		t.Fatalf("writing orphan fixture: %v", err)
	}
	if err := run([]string{manifest}, outDir, true); err == nil {
		t.Fatal("check with an orphan schema file: got nil error, want a failure")
	}
}

func TestRunCheckFlagsStaleSchemaFile(t *testing.T) {
	dir := t.TempDir()
	manifest := writeManifest(t, dir, oneBucketManifest)
	outDir := filepath.Join(dir, "out")
	if err := os.Mkdir(outDir, 0o700); err != nil {
		t.Fatalf("mkdir: %v", err)
	}
	// No generated files at all: every schema the manifest produces is missing.
	if err := run([]string{manifest}, outDir, true); err == nil {
		t.Fatal("check against an empty out dir: got nil error, want a failure")
	}
}
