// Command systemmap regenerates Module:SystemMap/systems.json — the data behind
// {{System map}} — from the ARK Starmap plus the hand-owned corrections in
// pages/module/SystemMap/overlay.json.
//
//	systemmap                       # fetch the starmap, regenerate the committed file
//	systemmap -from out/starmap.json # regenerate from an existing mirror, no network
//	systemmap -diff                 # regenerate, compare against the live page, exit 1 on drift
//
// Unlike the other tools here, its output is committed source rather than a
// gitignored artifact: it is small, it is reviewed as a diff, and the overlay it
// is built from is only meaningful next to the file it produces.
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
	"github.com/StarCitizenTools/wiki-tools/scripts/internal/systemmap"
)

const (
	defaultOut     = "../pages/module/SystemMap/systems.json"
	defaultOverlay = "../pages/module/SystemMap/overlay.json"
	// A fetch is expensive (about 417 requests), so it is mirrored to the same
	// path cmd/starmap uses. A later run can then pass -from and stay offline.
	defaultMirror = "out/starmap.json"

	wikiPage     = "Module:SystemMap/systems.json"
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
		out         = flag.String("out", defaultOut, "path to write systems.json ('-' for stdout, '' to discard)")
		overlayPath = flag.String("overlay", defaultOverlay, "path to the hand-owned corrections")
		from        = flag.String("from", "", "read the starmap from this file instead of fetching")
		mirror      = flag.String("mirror", defaultMirror, "where a freshly fetched starmap is kept ('' to discard)")
		doDiff      = flag.Bool("diff", false, "compare against the live wiki page; exit 1 if they differ")
		concurrency = flag.Int("concurrency", 4, "systems fetched in parallel")
		interval    = flag.Duration("interval", 300*time.Millisecond, "minimum spacing between API requests")
		minSystems  = flag.Int("min-systems", 80, "refuse to build from fewer upstream systems than this")
		quiet       = flag.Bool("quiet", false, "suppress progress output")
	)
	flag.Parse()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	progress := func(string) {}
	if !*quiet {
		progress = func(s string) { fmt.Fprintln(os.Stderr, s) }
	}

	overlayBytes, err := os.ReadFile(*overlayPath)
	if err != nil {
		return err
	}
	overlay, err := systemmap.LoadOverlay(overlayBytes)
	if err != nil {
		return err
	}
	progress(fmt.Sprintf("overlay: %d systems (%s)", len(overlay.Order), strings.Join(overlay.Order, ", ")))

	source, err := loadStarmap(ctx, *from, *mirror, *concurrency, *interval, progress)
	if err != nil {
		return err
	}

	// A half-empty starmap is a degraded API, not a real change. Building from
	// one would quietly drop bodies from a live page.
	if got := len(source.Systems); got < *minSystems {
		return fmt.Errorf("refusing to build: the starmap has only %d systems, expected at least %d "+
			"(upstream may be degraded; override with -min-systems)", got, *minSystems)
	}

	res, err := systemmap.Build(systemmap.Options{Starmap: source, Overlay: overlay})
	if err != nil {
		return err
	}
	progress(fmt.Sprintf("built %d systems, %d bodies", res.Document.Systems.Len(), res.Bodies))
	for _, note := range res.Notes {
		progress("  " + note)
	}

	encoded, err := systemmap.Encode(res.Document)
	if err != nil {
		return err
	}

	switch *out {
	case "-":
		if _, err := os.Stdout.Write(encoded); err != nil {
			return err
		}
	case "":
		// Explicitly discarded: useful with -diff, which only needs the bytes.
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
	return diff(ctx, encoded, *out)
}

// loadStarmap reads the upstream mirror from disk, or fetches it.
func loadStarmap(
	ctx context.Context,
	from, mirror string,
	concurrency int,
	interval time.Duration,
	progress func(string),
) (*starmap.Document, error) {
	if from != "" {
		b, err := os.ReadFile(from)
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("%s does not exist: run `mise run starmap` to mirror it, "+
				"or run this without -from to fetch it here", from)
		}
		if err != nil {
			return nil, err
		}
		doc, err := starmap.Decode(b)
		if err != nil {
			return nil, fmt.Errorf("reading %s: %w", from, err)
		}
		progress(fmt.Sprintf("loaded %s (%d systems, %d objects)", from, len(doc.Systems), len(doc.Objects)))
		return doc, nil
	}

	client := httpx.New(httpx.Options{
		Interval:  interval,
		UserAgent: userAgent,
		MaxTries:  4,
		Timeout:   90 * time.Second,
	})
	defer client.Close()

	started := time.Now()
	res, err := starmap.Generate(ctx, starmap.Options{
		Concurrency: concurrency,
		Client:      client,
		Progress:    progress,
	})
	if err != nil {
		return nil, err
	}
	progress(fmt.Sprintf("fetched %d systems, %d objects in %d requests (%s)",
		len(res.Document.Systems), len(res.Document.Objects), res.Requests, time.Since(started).Round(time.Second)))
	if len(res.Drift) > 0 {
		fmt.Fprintf(os.Stderr, "\nWARNING: %d unrecognised upstream field(s):\n", len(res.Drift))
		for _, d := range res.Drift {
			fmt.Fprintf(os.Stderr, "  %s\n", d)
		}
	}

	if mirror != "" {
		encoded, err := starmap.Encode(res.Document)
		if err != nil {
			return nil, err
		}
		if err := os.MkdirAll(filepath.Dir(mirror), 0o755); err != nil {
			return nil, err
		}
		if err := os.WriteFile(mirror, encoded, 0o644); err != nil {
			return nil, err
		}
		progress(fmt.Sprintf("mirrored the starmap to %s", mirror))
	}
	return res.Document, nil
}

// diff compares the generated bytes against the live page, read-only.
func diff(ctx context.Context, encoded []byte, out string) error {
	wiki, err := mediawiki.New(mediawiki.Config{Endpoint: wikiEndpoint, UserAgent: userAgent})
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

	fmt.Fprintf(os.Stderr, "\nDRIFT against %s (rev %d)\n", wikiPage, page.RevisionID)
	fmt.Fprintf(os.Stderr, "  live      %d bytes\n  generated %d bytes\n", len(live), len(next))

	liveDoc, errA := systemmap.Decode([]byte(live))
	nextDoc, errB := systemmap.Decode([]byte(next))
	if errA != nil || errB != nil {
		fmt.Fprintln(os.Stderr, "  (content differs; could not decode both sides for a field summary)")
	} else {
		for _, line := range systemmap.Compare(liveDoc, nextDoc) {
			fmt.Fprintf(os.Stderr, "  %s\n", line)
		}
	}
	if out != "" && out != "-" {
		fmt.Fprintf(os.Stderr, "\nTo publish, deploy %s via the MediaWiki MCP server.\n", out)
	}
	os.Exit(1)
	return nil
}
