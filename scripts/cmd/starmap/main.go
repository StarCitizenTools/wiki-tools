// Command starmap regenerates Module:Starmap/starmap.json from the ARK Starmap
// API and reports how it differs from the live page.
//
//	starmap                       # generate to the default path
//	starmap -diff                 # generate, compare against the live page, exit 1 on drift
//	starmap -from file.json -diff # compare an existing file without refetching
//
// It does not write to the wiki. Deployment goes through the MediaWiki MCP
// server so that an agent can handle conflicts and editorial judgement.
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"strings"
	"syscall"
	"time"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/httpx"
	"github.com/StarCitizenTools/wiki-tools/scripts/internal/mediawiki"
	"github.com/StarCitizenTools/wiki-tools/scripts/internal/starmap"
)

const (
	// The generated JSON is a build artifact, not source: it is a megabyte of
	// data mirrored from an upstream API, so committing it would add churn
	// without adding anything reviewable. It lands in a gitignored directory and
	// is published from there via the MediaWiki MCP server.
	defaultOut   = "out/starmap.json"
	wikiPage     = "Module:Starmap/starmap.json"
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
		out         = flag.String("out", defaultOut, "path to write the generated JSON ('-' for stdout)")
		from        = flag.String("from", "", "read JSON from this file instead of fetching")
		doDiff      = flag.Bool("diff", false, "compare against the live wiki page; exit 1 if they differ")
		concurrency = flag.Int("concurrency", 4, "systems fetched in parallel")
		interval    = flag.Duration("interval", 300*time.Millisecond, "minimum spacing between API requests")
		minSystems  = flag.Int("min-systems", 80, "refuse to write fewer systems than this")
		minObjects  = flag.Int("min-objects", 800, "refuse to write fewer objects than this")
		quiet       = flag.Bool("quiet", false, "suppress progress output")
	)
	flag.Parse()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	progress := func(string) {}
	if !*quiet {
		progress = func(s string) { fmt.Fprintln(os.Stderr, s) }
	}

	// --- obtain the document ------------------------------------------------
	var encoded []byte
	if *from != "" {
		b, err := os.ReadFile(*from)
		if err != nil {
			return err
		}
		// Re-encode so the bytes are canonical regardless of how the file was
		// written; this is what makes a byte comparison meaningful.
		doc, err := starmap.Decode(b)
		if err != nil {
			return fmt.Errorf("reading %s: %w", *from, err)
		}
		if encoded, err = starmap.Encode(doc); err != nil {
			return err
		}
		progress(fmt.Sprintf("loaded %s (%d systems, %d objects)", *from, len(doc.Systems), len(doc.Objects)))
	} else {
		client := httpx.New(httpx.Options{
			Interval:  *interval,
			UserAgent: userAgent,
			MaxTries:  4,
			Timeout:   90 * time.Second,
		})
		defer client.Close()

		started := time.Now()
		res, err := starmap.Generate(ctx, starmap.Options{
			Concurrency: *concurrency,
			Client:      client,
			Progress:    progress,
		})
		if err != nil {
			return err
		}
		doc := res.Document
		progress(fmt.Sprintf("generated %d systems, %d objects in %d requests (%s)",
			len(doc.Systems), len(doc.Objects), res.Requests, time.Since(started).Round(time.Second)))

		// Schema drift is a warning, not a failure: the output is still valid,
		// but somebody should look at what upstream added.
		if len(res.Drift) > 0 {
			fmt.Fprintf(os.Stderr, "\nWARNING: %d unrecognised upstream field(s):\n", len(res.Drift))
			for _, d := range res.Drift {
				fmt.Fprintf(os.Stderr, "  %s\n", d)
			}
			fmt.Fprintln(os.Stderr, "These are not in the output. Update knownObjectKeys/knownSystemKeys once reviewed.")
		}

		if len(doc.Systems) < *minSystems || len(doc.Objects) < *minObjects {
			return fmt.Errorf("refusing to continue: got %d systems and %d objects, expected at least %d/%d "+
				"(upstream may be degraded; override with -min-systems/-min-objects)",
				len(doc.Systems), len(doc.Objects), *minSystems, *minObjects)
		}

		if encoded, err = starmap.Encode(doc); err != nil {
			return err
		}
	}

	// --- write to disk ------------------------------------------------------
	switch *out {
	case "-":
		if _, err := os.Stdout.Write(encoded); err != nil {
			return err
		}
	case "":
		// Explicitly discarded: useful with -diff, which only needs the bytes
		// in memory to compare.
	default:
		if err := os.MkdirAll(filepath.Dir(*out), 0o755); err != nil {
			return err
		}
		if err := os.WriteFile(*out, encoded, 0o644); err != nil {
			return err
		}
		progress(fmt.Sprintf("wrote %s (%d bytes)", *out, len(encoded)))
	}

	if !*doDiff {
		return nil
	}

	// --- compare against the live page (read-only) --------------------------
	wiki, err := mediawiki.New(mediawiki.Config{
		Endpoint:  wikiEndpoint,
		UserAgent: userAgent,
	})
	if err != nil {
		return err
	}
	defer wiki.Close()

	page, err := wiki.Fetch(ctx, wikiPage)
	if err != nil {
		return err
	}

	live := strings.TrimRight(page.Content, "\n")
	next := strings.TrimRight(string(encoded), "\n")

	if live == next {
		fmt.Fprintf(os.Stderr, "no drift: %s matches the generated output (rev %d)\n", wikiPage, page.RevisionID)
		return nil
	}

	report(live, next, page.RevisionID)
	fmt.Fprintf(os.Stderr, "\nTo publish, deploy %s via the MediaWiki MCP server.\n", *out)
	os.Exit(1)
	return nil
}

// report summarises how the generated output differs from the live page.
func report(live, next string, rev int64) {
	fmt.Fprintf(os.Stderr, "\nDRIFT against %s (rev %d)\n", wikiPage, rev)
	fmt.Fprintf(os.Stderr, "  live      %d bytes\n  generated %d bytes\n", len(live), len(next))

	liveDoc, errA := starmap.Decode([]byte(live))
	nextDoc, errB := starmap.Decode([]byte(next))
	if errA != nil || errB != nil {
		fmt.Fprintln(os.Stderr, "  (content differs; could not decode both sides for a field summary)")
		return
	}
	for _, line := range starmap.Compare(liveDoc, nextDoc) {
		fmt.Fprintf(os.Stderr, "  %s\n", line)
	}
}
