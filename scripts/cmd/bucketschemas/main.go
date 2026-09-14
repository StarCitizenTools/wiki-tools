// Command bucketschemas generates the Bucket schema pages under pages/bucket/
// from the Entity, Company and WearableSet property manifests.
//
//	bucketschemas          # write pages/bucket/<Name>.json
//	bucketschemas -check   # exit 1 if any generated file is stale or missing
package main

import (
	"bytes"
	"flag"
	"fmt"
	"os"
	"path/filepath"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/bucketschemas"
)

var manifests = []string{
	"../pages/module/Entity/properties.json",
	"../pages/module/Company/properties.json",
	"../pages/module/WearableSet/properties.json",
}

func main() {
	out := flag.String("out", "../pages/bucket", "directory the schema pages are written to")
	check := flag.Bool("check", false, "report drift instead of writing; exit 1 when a schema is stale")
	flag.Parse()
	if err := run(manifests, *out, *check); err != nil {
		fmt.Fprintln(os.Stderr, "bucketschemas:", err)
		os.Exit(1)
	}
}

func run(manifests []string, outDir string, check bool) error {
	all := map[string]bucketschemas.Schema{}
	for _, path := range manifests {
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		schemas, err := bucketschemas.Build(data)
		if err != nil {
			return fmt.Errorf("%s: %w", path, err)
		}
		for name, s := range schemas {
			if existing, dup := all[name]; dup {
				if err := bucketschemas.Merge(name, existing, s); err != nil {
					return err
				}
				continue
			}
			all[name] = s
		}
	}
	stale := false
	known := map[string]bool{}
	for name, s := range all {
		rendered, err := bucketschemas.Render(s)
		if err != nil {
			return err
		}
		fileName := bucketschemas.PageTitle(name) + ".json"
		known[fileName] = true
		path := filepath.Join(outDir, fileName)
		if check {
			existing, err := os.ReadFile(path)
			if err != nil || !bytes.Equal(existing, rendered) {
				fmt.Fprintln(os.Stderr, "bucketschemas: stale:", path)
				stale = true
			}
			continue
		}
		if err := os.WriteFile(path, rendered, 0o644); err != nil {
			return err
		}
	}
	// A bucket renamed or retired leaves its old pages/bucket/<Name>.json behind:
	// it passes every check above (nothing generates it, so nothing compares
	// against it) and the deploy skill's pages/bucket/*.json -> Bucket:<Name>
	// rule would recreate a table that was meant to be gone.
	if check {
		entries, err := os.ReadDir(outDir)
		if err != nil {
			return err
		}
		for _, entry := range entries {
			if entry.IsDir() || filepath.Ext(entry.Name()) != ".json" {
				continue
			}
			if !known[entry.Name()] {
				fmt.Fprintln(os.Stderr, "bucketschemas: stale: orphan", filepath.Join(outDir, entry.Name()))
				stale = true
			}
		}
	}
	if stale {
		return fmt.Errorf("run `mise run bucket:schemas` and commit the result")
	}
	return nil
}
