// Package itemstubs plans {{Entity}} stub pages for datamined items that are
// missing from the wiki. It is read-only: the output is a plan JSON that an
// agent applies through the MediaWiki MCP server.
package itemstubs

import (
	"encoding/json"
	"fmt"
	"io"
	"regexp"
	"strings"
)

// Manufacturer is an item's maker as recorded in the dump. Some entries carry
// a bare uuid string (or null) instead of an object; those decode to the zero
// value and are resolved later from config rules or flagged as conflicts.
type Manufacturer struct {
	Name string `json:"Name"`
	Code string `json:"Code"`
	UUID string `json:"UUID"`
}

// Item is the slice of a dump entry this tool needs. Everything else in the
// ~6 KB stdItem blob is deliberately not decoded.
type Item struct {
	UUID      string
	ClassName string
	Name      string
	Type      string // "WeaponGun.Gun"
	Size      *int
	// Description is never rendered — {{Entity/Description}} pulls the live
	// text. It is decoded because it is where the dump says an item is built
	// into one ship, which no other field reliably reports.
	Description  string
	Manufacturer Manufacturer
}

var uuidRe = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`)

// DecodeItems walks the dump's top-level array with a streaming decoder, so
// the 128 MB document is never held as one parse tree. Entries without a
// usable stdItem or well-formed uuid are counted in unusable rather than
// failing the run: the dump has always contained a handful of them.
func DecodeItems(r io.Reader) (items []Item, unusable int, err error) {
	dec := json.NewDecoder(r)
	tok, err := dec.Token()
	if err != nil {
		return nil, 0, fmt.Errorf("itemstubs: reading dump: %w", err)
	}
	if delim, ok := tok.(json.Delim); !ok || delim != '[' {
		return nil, 0, fmt.Errorf("itemstubs: dump is not a JSON array (got %v)", tok)
	}

	for dec.More() {
		var raw struct {
			StdItem *struct {
				UUID         string          `json:"UUID"`
				ClassName    string          `json:"ClassName"`
				Name         string          `json:"Name"`
				Type         string          `json:"Type"`
				Size         *float64        `json:"Size"`
				Description  string          `json:"Description"`
				Manufacturer json.RawMessage `json:"Manufacturer"`
			} `json:"stdItem"`
		}
		if err := dec.Decode(&raw); err != nil {
			return nil, 0, fmt.Errorf("itemstubs: decoding entry %d: %w", len(items)+unusable, err)
		}
		std := raw.StdItem
		if std == nil {
			unusable++
			continue
		}
		uuid := strings.ToLower(strings.TrimSpace(std.UUID))
		if !uuidRe.MatchString(uuid) {
			unusable++
			continue
		}
		item := Item{
			UUID:        uuid,
			ClassName:   std.ClassName,
			Name:        strings.TrimSpace(std.Name),
			Type:        std.Type,
			Description: std.Description,
		}
		if std.Size != nil {
			size := int(*std.Size)
			item.Size = &size
		}
		// Manufacturer is an object on most entries, a bare uuid string on
		// some; only the object shape carries anything usable.
		if len(std.Manufacturer) > 0 && std.Manufacturer[0] == '{' {
			if err := json.Unmarshal(std.Manufacturer, &item.Manufacturer); err != nil {
				return nil, 0, fmt.Errorf("itemstubs: manufacturer of %s: %w", uuid, err)
			}
		}
		items = append(items, item)
	}
	return items, unusable, nil
}

// items.json is an ordinary file, so raw.githubusercontent serves it. It was
// declared LFS-tracked in .gitattributes until 2026-08-20 (commit 7d622b5),
// which is why this used to point at media.githubusercontent — but upstream
// only committed the file after untracking it, so no reachable ref serves a
// pointer here and the media host now 404s.
const (
	dumpURLFormat    = "https://raw.githubusercontent.com/StarCitizenWiki/scunpacked-data/%s/items.json"
	commitsURLFormat = "https://api.github.com/repos/StarCitizenWiki/scunpacked-data/commits?per_page=30&sha=%s"
)

// DumpURL is where ref's items.json content is served.
func DumpURL(ref string) string { return fmt.Sprintf(dumpURLFormat, ref) }

// CommitsURL lists ref's recent commits, newest first.
func CommitsURL(ref string) string { return fmt.Sprintf(commitsURLFormat, ref) }

// buildRe matches the first line of scunpacked-data's extraction commits,
// e.g. "4.9.0-LIVE.12232306". Maintenance commits ("fix: …") do not match.
var buildRe = regexp.MustCompile(`^(\d+\.\d+\.\d+)-`)

// Version extracts the game version from a build line: "4.9.0-LIVE.12232306"
// -> "4.9.0". ok is false for lines that are not build ids.
func Version(build string) (string, bool) {
	m := buildRe.FindStringSubmatch(build)
	if m == nil {
		return "", false
	}
	return m[1], true
}

// Commit is one entry of the GitHub commits listing.
type Commit struct {
	SHA    string `json:"sha"`
	Commit struct {
		Message string `json:"message"`
	} `json:"commit"`
}

// LatestBuild finds the newest commit whose message is a build id, returning
// the build line. Maintenance commits are skipped, so the build reflects the
// extraction the data actually came from.
func LatestBuild(commits []Commit) (build string, ok bool) {
	for _, c := range commits {
		line, _, _ := strings.Cut(c.Commit.Message, "\n")
		line = strings.TrimSpace(line)
		if _, isBuild := Version(line); isBuild {
			return line, true
		}
	}
	return "", false
}
