// Command uuidindex reconciles the UUID: namespace — the uuid → page redirect
// index — against the uuid values annotated on wiki pages, and writes the
// plan that would bring the namespace back in step.
//
//	uuidindex          # scan, report, write the plan to the default path
//	uuidindex -diff    # same, and exit 1 if any create/retarget/delete is pending
//
// It does not write to the wiki. Applying the plan goes through the MediaWiki
// MCP server so that an agent can handle conflicts and editorial judgement.
package main

import (
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

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/mediawiki"
	"github.com/StarCitizenTools/wiki-tools/scripts/internal/uuidindex"
)

const (
	// The plan is a scan artifact, not source: it describes live wiki state at
	// one moment, so it lands in the gitignored out/ directory and is applied
	// from there via the MediaWiki MCP server.
	defaultOut   = "out/uuid-index.json"
	wikiEndpoint = "https://starcitizen.tools/api.php"
	userAgent    = "StarCitizenTools-wiki-tools/1.0 (https://github.com/StarCitizenTools/wiki-tools)"

	// Distinct exit codes: a scheduled -diff run should be able to tell "the
	// index is stale" from "a safety rail stopped the run".
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
		out       = flag.String("out", defaultOut, "path to write the plan JSON ('-' for stdout, '' to discard)")
		doDiff    = flag.Bool("diff", false, "exit 1 if the namespace needs changes")
		interval  = flag.Duration("interval", 250*time.Millisecond, "minimum spacing between API requests")
		minUUIDs  = flag.Int("min-uuids", 5000, "refuse to plan from fewer annotated uuids than this")
		minPages  = flag.Int("min-pages", 5000, "refuse to plan from fewer namespace pages than this")
		maxDelete = flag.Int("max-delete", 100, "refuse to plan more deletions than this")
		quiet     = flag.Bool("quiet", false, "suppress progress output")
	)
	flag.Parse()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	progress := func(string) {}
	if !*quiet {
		progress = func(s string) { fmt.Fprintln(os.Stderr, s) }
	}

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
	scan, err := uuidindex.Scan(ctx, uuidindex.ScanOptions{
		Client:   client,
		Progress: progress,
	})
	if err != nil {
		return err
	}
	progress(fmt.Sprintf("scan finished in %s (%d requests)", time.Since(started).Round(time.Second), scan.Requests))

	// A half-empty scan is a degraded API (an SMW rebuild, a truncated list),
	// not a real change; planning from it would schedule a mass deletion.
	// These are checked before the plan exists because a plan built on them
	// would be actively misleading to have on disk.
	if got := len(scan.Properties.Holders); got < *minUUIDs {
		return fmt.Errorf("refusing to plan: only %d annotated uuids, expected at least %d "+
			"(SMW may be degraded; override with -min-uuids)", got, *minUUIDs)
	}
	if got := len(scan.Pages); got < *minPages {
		return fmt.Errorf("refusing to plan: only %d namespace pages, expected at least %d "+
			"(the API may be degraded; override with -min-pages)", got, *minPages)
	}

	plan := uuidindex.Reconcile(scan, wikiEndpoint, time.Now())

	// The deletion cap is evaluated after writing, so that a tripped rail
	// leaves the evidence behind. Judging whether the deletions are real means
	// reading them, and re-running a multi-minute scan to find that out is how
	// a safety rail teaches people to raise it unread.
	rejected := len(plan.Delete) > *maxDelete
	dest := *out
	if rejected && dest != "" && dest != "-" {
		dest = strings.TrimSuffix(dest, ".json") + ".rejected.json"
	}
	if err := write(dest, plan, progress); err != nil {
		return err
	}

	fmt.Fprintf(os.Stderr, "\nUUID index against %s\n", wikiEndpoint)
	for _, line := range uuidindex.Report(plan) {
		fmt.Fprintf(os.Stderr, "  %s\n", line)
	}

	if rejected {
		fmt.Fprintf(os.Stderr, "\nrefusing to apply %d deletions (limit %d)\n", len(plan.Delete), *maxDelete)
		if dest != "" && dest != "-" {
			fmt.Fprintf(os.Stderr, "the rejected plan is at %s; read the deletions, then re-run "+
				"with -max-delete if they are real\n", dest)
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
func write(dest string, plan *uuidindex.Plan, progress func(string)) error {
	encoded, err := json.MarshalIndent(plan, "", "  ")
	if err != nil {
		return err
	}
	encoded = append(encoded, '\n')

	switch dest {
	case "":
		return nil // Explicitly discarded; -diff only needs the report.
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
