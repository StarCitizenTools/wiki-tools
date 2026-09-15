// Command bucketschemas generates the Bucket schema pages under pages/bucket/
// from the property manifests listed in Module:BucketQuery/manifests.json, the
// same registry Module:BucketQuery reads at render time.
//
//	bucketschemas          # write pages/bucket/<Name>.json
//	bucketschemas -check   # exit 1 if any generated file is stale or missing
package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/bucketschemas"
)

// The registry Module:BucketQuery reads at render time. Read here rather than
// duplicated as a list, so registering a domain is one data edit and the
// generator can never disagree with the module about which manifests exist.
const registryPath = "../pages/module/BucketQuery/manifests.json"

// manifestPaths reads the registry and maps each wiki page title to its path in
// this repo's mirror.
func manifestPaths(registry string) ([]string, error) {
	data, err := os.ReadFile(registry)
	if err != nil {
		return nil, err
	}
	var reg struct {
		Manifests []string `json:"manifests"`
	}
	if err := json.Unmarshal(data, &reg); err != nil {
		return nil, fmt.Errorf("%s: %w", registry, err)
	}
	if len(reg.Manifests) == 0 {
		return nil, fmt.Errorf("%s: no manifests listed", registry)
	}
	paths := make([]string, 0, len(reg.Manifests))
	for _, title := range reg.Manifests {
		trimmed := strings.TrimPrefix(title, "Module:")
		if trimmed == title {
			return nil, fmt.Errorf("%s: %q is not a Module: page", registry, title)
		}
		paths = append(paths, filepath.Join("../pages/module", trimmed))
	}
	return paths, nil
}

func main() {
	out := flag.String("out", "../pages/bucket", "directory the schema pages are written to")
	check := flag.Bool("check", false, "report drift instead of writing; exit 1 when a schema is stale")
	flag.Parse()
	manifests, err := manifestPaths(registryPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, "bucketschemas:", err)
		os.Exit(1)
	}
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
