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
	"syscall"
	"time"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/httpx"
	"github.com/StarCitizenTools/wiki-tools/scripts/internal/uuidindex"
)

const (
	// The plan is a scan artifact, not source: it describes live wiki state at
	// one moment, so it lands in the gitignored out/ directory and is applied
	// from there via the MediaWiki MCP server.
	defaultOut   = "out/uuid-index.json"
	wikiEndpoint = "https://starcitizen.tools/api.php"
	userAgent    = "StarCitizenTools-wiki-tools/1.0 (https://github.com/StarCitizenTools/wiki-tools)"
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

	client := httpx.New(httpx.Options{
		Interval:  *interval,
		UserAgent: userAgent,
		MaxTries:  4,
		Timeout:   90 * time.Second,
	})
	defer client.Close()

	started := time.Now()
	scan, err := uuidindex.Scan(ctx, uuidindex.ScanOptions{
		Client:   client,
		Endpoint: wikiEndpoint,
		Progress: progress,
	})
	if err != nil {
		return err
	}
	progress(fmt.Sprintf("scan finished in %s", time.Since(started).Round(time.Second)))

	// A half-empty scan is a degraded API (an SMW rebuild, a truncated list),
	// not a real change; planning from it would schedule a mass deletion.
	if got := len(scan.Properties.Holders); got < *minUUIDs {
		return fmt.Errorf("refusing to plan: only %d annotated uuids, expected at least %d "+
			"(SMW may be degraded; override with -min-uuids)", got, *minUUIDs)
	}
	if got := len(scan.Pages); got < *minPages {
		return fmt.Errorf("refusing to plan: only %d namespace pages, expected at least %d "+
			"(the API may be degraded; override with -min-pages)", got, *minPages)
	}

	plan := uuidindex.Reconcile(scan, wikiEndpoint)

	if len(plan.Delete) > *maxDelete {
		return fmt.Errorf("refusing to plan %d deletions (limit %d); inspect the wiki, "+
			"then override with -max-delete if they are real", len(plan.Delete), *maxDelete)
	}

	encoded, err := json.MarshalIndent(plan, "", "  ")
	if err != nil {
		return err
	}
	encoded = append(encoded, '\n')

	switch *out {
	case "-":
		if _, err := os.Stdout.Write(encoded); err != nil {
			return err
		}
	case "":
		// Explicitly discarded: useful with -diff, which only needs the report.
	default:
		if err := os.MkdirAll(filepath.Dir(*out), 0o755); err != nil {
			return err
		}
		if err := os.WriteFile(*out, encoded, 0o644); err != nil {
			return err
		}
		progress(fmt.Sprintf("wrote %s (%d bytes)", *out, len(encoded)))
	}

	fmt.Fprintf(os.Stderr, "\nUUID index against %s\n", wikiEndpoint)
	for _, line := range uuidindex.Report(plan) {
		fmt.Fprintf(os.Stderr, "  %s\n", line)
	}

	if *doDiff && plan.Drift() {
		fmt.Fprintf(os.Stderr, "\nTo apply, work through %s via the MediaWiki MCP server.\n", *out)
		os.Exit(1)
	}
	return nil
}
