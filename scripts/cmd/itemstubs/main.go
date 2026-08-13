// Command itemstubs reconciles the scunpacked item dump against the wiki's
// annotated uuids and writes a plan of {{Entity}} stub pages to create.
//
//	itemstubs          # fetch dump, scan wiki, write the plan to the default path
//	itemstubs -diff    # same, and exit 1 if any creates or conflicts are pending
//	itemstubs -in items.json -build 4.9.0-LIVE.12232306   # local dump instead of fetching (wiki scan still runs)
//
// It does not write to the wiki. Applying the plan goes through the MediaWiki
// MCP server so that an agent can handle conflicts and editorial judgement.
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/httpx"
	"github.com/StarCitizenTools/wiki-tools/scripts/internal/itemstubs"
	"github.com/StarCitizenTools/wiki-tools/scripts/internal/mediawiki"
	"github.com/StarCitizenTools/wiki-tools/scripts/internal/uuidindex"
)

const (
	// The plan is a scan artifact, not source: it snapshots one dump revision
	// against live wiki state, so it lands in the gitignored out/ directory
	// and is applied from there via the MediaWiki MCP server.
	defaultOut    = "out/item-stubs.json"
	defaultConfig = "cmd/itemstubs/config.json"
	wikiEndpoint  = "https://starcitizen.tools/api.php"
	userAgent     = "StarCitizenTools-wiki-tools/1.0 (https://github.com/StarCitizenTools/wiki-tools)"

	exitDrift       = 1
	exitRailTripped = 2
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run() error {
	var (
		out        = flag.String("out", defaultOut, "path to write the plan JSON ('-' for stdout, '' to discard)")
		in         = flag.String("in", "", "read the item dump from this file instead of fetching")
		ref        = flag.String("ref", "master", "scunpacked-data git ref to fetch")
		build      = flag.String("build", "", "override the game build id (required with -in)")
		configPath = flag.String("config", defaultConfig, "path to the editorial config")
		doDiff     = flag.Bool("diff", false, "exit 1 if any creates or conflicts are pending")
		interval   = flag.Duration("interval", 250*time.Millisecond, "minimum spacing between API requests")
		minItems   = flag.Int("min-items", 15000, "refuse to plan from fewer usable dump items than this")
		minUUIDs   = flag.Int("min-uuids", 5000, "refuse to plan from fewer annotated wiki uuids than this")
		maxCreate  = flag.Int("max-create", 500, "refuse to plan more creations than this")
		quiet      = flag.Bool("quiet", false, "suppress progress output")
	)
	flag.Parse()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	progress := func(string) {}
	if !*quiet {
		progress = func(s string) { fmt.Fprintln(os.Stderr, s) }
	}

	cfg, err := itemstubs.LoadConfig(*configPath)
	if err != nil {
		return err
	}

	// --- obtain the dump and its build id -----------------------------------
	web := httpx.New(httpx.Options{
		Interval:  *interval,
		UserAgent: userAgent,
		MaxTries:  4,
		Timeout:   10 * time.Minute, // the dump is ~130 MB
	})
	defer web.Close()

	buildID := *build
	if *in != "" && buildID == "" {
		return fmt.Errorf("-in needs -build: a local dump carries no commit history to read the build from")
	}
	// Fail fast on a bad -build before spending any time on a 130 MB dump
	// read/fetch or a multi-minute live wiki scan: BuildPlan validates this
	// too, but only after all of that work has already happened.
	if buildID != "" {
		if _, ok := itemstubs.Version(buildID); !ok {
			return fmt.Errorf("itemstubs: %q is not a build id; pass -build", buildID)
		}
	}

	source := ""
	var dump []byte
	if *in != "" {
		if dump, err = os.ReadFile(*in); err != nil {
			return err
		}
		source = *in
	} else {
		progress("fetching commit history for " + *ref)
		body, err := web.Do(ctx, "GET", itemstubs.CommitsURL(*ref), "")
		if err != nil {
			return fmt.Errorf("listing scunpacked-data commits: %w", err)
		}
		var commits []itemstubs.Commit
		if err := json.Unmarshal(body, &commits); err != nil {
			return fmt.Errorf("decoding commit list: %w", err)
		}
		if len(commits) > 0 {
			source = "scunpacked-data@" + commits[0].SHA[:min(7, len(commits[0].SHA))]
		}
		if buildID == "" {
			line, ok := itemstubs.LatestBuild(commits)
			if !ok {
				return fmt.Errorf("no build-id commit in the last %d commits; pass -build", len(commits))
			}
			if _, ok := itemstubs.Version(line); !ok {
				return fmt.Errorf("itemstubs: %q is not a build id; pass -build", line)
			}
			buildID = line
		}
		progress(fmt.Sprintf("fetching items.json (%s, build %s)", source, buildID))
		if dump, err = web.Do(ctx, "GET", itemstubs.DumpURL(*ref), ""); err != nil {
			return fmt.Errorf("fetching items.json: %w", err)
		}
	}

	items, unusable, err := itemstubs.DecodeItems(bytes.NewReader(dump))
	if err != nil {
		return err
	}
	dump = nil // release the 130 MB buffer before the wiki scan
	progress(fmt.Sprintf("decoded %d usable items (%d unusable)", len(items), unusable))

	// A short dump is a truncated download or upstream breakage, not a small
	// game; planning from it would schedule pages as "missing" that the full
	// dump would have skipped differently.
	if len(items) < *minItems {
		return fmt.Errorf("refusing to plan: only %d usable items, expected at least %d "+
			"(truncated fetch? override with -min-items)", len(items), *minItems)
	}

	// --- scan the wiki ------------------------------------------------------
	client, err := mediawiki.New(mediawiki.Config{
		Endpoint:  wikiEndpoint,
		UserAgent: userAgent,
		Interval:  *interval,
	})
	if err != nil {
		return err
	}
	defer client.Close()

	started := time.Now()
	props, requests, err := uuidindex.ScanProperties(ctx, client, progress)
	if err != nil {
		return err
	}
	progress(fmt.Sprintf("wiki scan finished in %s (%d requests)", time.Since(started).Round(time.Second), requests))

	wiki := make(map[string]bool, len(props.Holders))
	for uuid := range props.Holders {
		wiki[uuid] = true
	}
	if len(wiki) < *minUUIDs {
		return fmt.Errorf("refusing to plan: only %d annotated uuids, expected at least %d "+
			"(SMW may be degraded; override with -min-uuids)", len(wiki), *minUUIDs)
	}

	// --- build the plan -----------------------------------------------------
	meta := itemstubs.Meta{Generated: time.Now(), Build: buildID, Source: source}
	plan, err := itemstubs.BuildPlan(ctx, items, wiki, cfg, meta, client.TitleStatuses)
	if err != nil {
		return err
	}
	plan.Skipped.Unusable = unusable

	// The creation cap is evaluated after writing so a tripped rail leaves
	// the evidence behind — judging whether 900 planned pages are a config
	// mistake means reading them, not re-running a multi-minute scan.
	rejected := len(plan.Create) > *maxCreate
	dest := *out
	if rejected && dest != "" && dest != "-" {
		dest = strings.TrimSuffix(dest, ".json") + ".rejected.json"
	}
	if err := write(dest, plan, progress); err != nil {
		return err
	}

	fmt.Fprintf(os.Stderr, "\nitem stubs against %s\n", wikiEndpoint)
	for _, line := range itemstubs.Report(plan) {
		fmt.Fprintf(os.Stderr, "  %s\n", line)
	}

	if rejected {
		fmt.Fprintf(os.Stderr, "\nrefusing to plan %d creations (limit %d)\n", len(plan.Create), *maxCreate)
		if dest != "" && dest != "-" {
			fmt.Fprintf(os.Stderr, "the rejected plan is at %s; read the creations, then re-run "+
				"with -max-create if they are real\n", dest)
		}
		os.Exit(exitRailTripped)
	}

	if *doDiff && plan.Drift() {
		if *out == "" || *out == "-" {
			fmt.Fprintln(os.Stderr, "\nRe-run without -out to write the plan, then apply it via the MediaWiki MCP server.")
		} else {
			fmt.Fprintf(os.Stderr, "\nTo apply, work through %s via the MediaWiki MCP server.\n", *out)
		}
		os.Exit(exitDrift)
	}
	return nil
}

// write emits the plan to a path, to stdout ("-"), or nowhere ("").
func write(dest string, plan *itemstubs.Plan, progress func(string)) error {
	encoded, err := json.MarshalIndent(plan, "", "  ")
	if err != nil {
		return err
	}
	encoded = append(encoded, '\n')

	switch dest {
	case "":
		return nil
	case "-":
		_, err := os.Stdout.Write(encoded)
		return err
	default:
		if err := os.MkdirAll(filepath.Dir(dest), 0o755); err != nil {
			return err
		}
		if err := os.WriteFile(dest, encoded, 0o644); err != nil {
			return err
		}
		progress(fmt.Sprintf("wrote %s (%d bytes)", dest, len(encoded)))
		return nil
	}
}
