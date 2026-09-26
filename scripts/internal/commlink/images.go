package commlink

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/httpx"
	"github.com/StarCitizenTools/wiki-tools/scripts/internal/mediawiki"
)

// ImagePlan is one image of a page: upload it under File, or reuse File, which
// already holds the same bytes.
type ImagePlan struct {
	N        int    `json:"n"`
	File     string `json:"file"`
	Action   string `json:"action"` // "upload" or "reuse"
	Source   string `json:"source"`
	SHA1     string `json:"sha1"`
	Size     int    `json:"size"`
	FilePage string `json:"filePage,omitempty"`
}

// RSI lists videos among a report's images, some past the wiki's 100 MB upload
// limit; a body source with one of these extensions is linked, not uploaded.
var videoExts = map[string]bool{".mp4": true, ".m4v": true, ".webm": true, ".mov": true}

func extOf(src string) string {
	p := src
	if u, err := url.Parse(src); err == nil {
		p = u.Path
	}
	return strings.ToLower(path.Ext(p))
}

// VideoLinks turns image blocks whose source is a video file into video links.
func VideoLinks(blocks []Block) []Block {
	out := make([]Block, len(blocks))
	for i, b := range blocks {
		if b.Kind == Image && videoExts[extOf(b.Src)] {
			b = Block{Kind: Video, VideoKind: "file", Src: b.Src}
		}
		out[i] = b
	}
	return out
}

// ImageSources lists a page's distinct image sources in body order.
func ImageSources(blocks []Block) []string {
	seen := map[string]bool{}
	var out []string
	for _, b := range blocks {
		if b.Kind == Image && !seen[b.Src] {
			seen[b.Src] = true
			out = append(out, b.Src)
		}
	}
	return out
}

// DedupeImages drops an image block that repeats an earlier one's resolved
// file name (RSI sometimes shows a section's header image again further
// down), keeping the first appearance. A dropped repeat's caption moves to the
// kept appearance when that one has none; two appearances whose captions both
// hold text and differ are both kept, since collapsing them would lose one.
func DedupeImages(blocks []Block, file func(src string) string) []Block {
	first := map[string]int{} // resolved file name -> its index in out
	out := make([]Block, 0, len(blocks))
	for _, b := range blocks {
		name := ""
		if b.Kind == Image {
			name = file(b.Src)
		}
		if name == "" {
			out = append(out, b)
			continue
		}
		i, seen := first[name]
		if !seen {
			first[name] = len(out)
			out = append(out, b)
			continue
		}
		kept := &out[i]
		switch {
		case b.Caption == "" || b.Caption == kept.Caption:
		case kept.Caption == "":
			kept.Caption = b.Caption
		default:
			out = append(out, b)
		}
	}
	return out
}

// ExtForType is the file extension for a sniffed image type, or "" for anything
// that is not an image the wiki accepts. MediaWiki rejects an extension that
// does not match the content, so the name follows the bytes, not the URL.
func ExtForType(contentType string) string {
	switch strings.TrimSpace(strings.Split(contentType, ";")[0]) {
	case "image/png":
		return ".png"
	case "image/jpeg":
		return ".jpg"
	case "image/gif":
		return ".gif"
	case "image/webp":
		return ".webp"
	}
	return ""
}

// FilePage is the description page of an imported image, in the form the 2021
// monthly-report import used. description and author are expected to have
// already passed through escapeText (a block's Caption does); a literal pipe
// survives that, so both are escaped here to stop it opening a spurious
// {{Information}} parameter.
func FilePage(description, date, source, author, category string) string {
	description = strings.ReplaceAll(description, "|", "&#124;")
	author = strings.ReplaceAll(author, "|", "&#124;")
	return "=={{int:filedesc}}==\n{{Information\n|description=" + description +
		"\n|date=" + date + "\n|source=" + source + "\n|author=" + author +
		"\n|permission=\n|other versions=\n}}\n\n=={{int:license-header}}==\n{{RSIlicense}}\n\n[[Category:" + category + "]]\n"
}

// creditPattern matches a caption that is wholly a community-art credit. RSI's
// own captions use only this "image by" phrasing; no other intro ("art by",
// "screenshot by", ...) appears in the data, so that is all this matches.
var creditPattern = regexp.MustCompile(`(?i)^image by (.+)$`)

// creditAuthor returns a whole-caption credit's subject, kept as wikitext (so
// a linked name stays an external link), and whether caption was one.
func creditAuthor(caption string) (string, bool) {
	m := creditPattern.FindStringSubmatch(caption)
	if m == nil {
		return "", false
	}
	return m[1], true
}

// firstCredit returns the first whole-caption credit among captions, in body
// order, and whether one was found.
func firstCredit(captions []string) (string, bool) {
	for _, c := range captions {
		if a, ok := creditAuthor(c); ok {
			return a, true
		}
	}
	return "", false
}

// Hash is what the importer keeps of a downloaded file: never the bytes.
type Hash struct {
	SHA1 string `json:"sha1"`
	Size int    `json:"size"`
	Type string `json:"type"`
}

// Cache persists image hashes and first-capture times between runs, keyed by
// URL, so a re-run downloads nothing twice.
type Cache struct {
	path     string
	Hashes   map[string]Hash   `json:"hashes"`
	Captures map[string]string `json:"captures"` // comm-link URL -> RFC 3339
}

// LoadCache reads the cache at path; a missing file is an empty cache.
func LoadCache(path string) (*Cache, error) {
	c := &Cache{path: path, Hashes: map[string]Hash{}, Captures: map[string]string{}}
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return c, nil
	}
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(data, c); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	if c.Hashes == nil {
		c.Hashes = map[string]Hash{}
	}
	if c.Captures == nil {
		c.Captures = map[string]string{}
	}
	return c, nil
}

// Save writes the cache atomically.
func (c *Cache) Save() error {
	data, err := json.MarshalIndent(c, "", " ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(c.path), 0o755); err != nil {
		return err
	}
	tmp := c.path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, c.path)
}

// Hash returns src's SHA1, size and sniffed type, downloading it only on a
// cache miss.
func (c *Cache) Hash(ctx context.Context, web *httpx.Client, src string) (Hash, error) {
	if h, ok := c.Hashes[src]; ok {
		return h, nil
	}
	body, err := web.Do(ctx, http.MethodGet, src, "")
	if err != nil {
		return Hash{}, err
	}
	s := sha1.Sum(body)
	h := Hash{SHA1: hex.EncodeToString(s[:]), Size: len(body), Type: http.DetectContentType(body)}
	c.Hashes[src] = h
	return h, nil
}

// PageImages is one page's image plan.
type PageImages struct {
	Plans []ImagePlan
	// Missing are body sources RSI answers with 404, left out of the page.
	Missing []string
	// Added maps the SHA1 of each image this page names to that name. The
	// caller adds it to the run's planned map only once the page is in the
	// plan, so no later page reuses an upload that never happens.
	Added map[string]string
	files map[string]string // source -> file name
}

// File is the wiki file name for an image source, or "" for a source the page
// leaves out.
func (p *PageImages) File(src string) string { return p.files[src] }

// PlanImages plans a page's images in body order. planned maps SHA1 to the
// file name chosen for it by pages already in the plan, so a picture two
// reports share is uploaded once; PlanImages only reads it. A source RSI
// answers with 404 is left out of the page; any other download failure is an
// error, and so is an upload whose name the wiki already holds (a file with
// the same bytes would have been found by SHA1 and reused).
func PlanImages(ctx context.Context, web *httpx.Client, wiki *mediawiki.Client, cache *Cache, planned map[string]string,
	cfg *Config, rsiTitle, page, date string, blocks []Block) (*PageImages, error) {
	res := &PageImages{Plans: []ImagePlan{}, Added: map[string]string{}, files: map[string]string{}}
	sources := ImageSources(blocks)

	// hashes is every source's hash, known up front so an upload decided for
	// one appearance of a picture can see a credit caption carried by another
	// appearance under a different source URL (creditCaptions below).
	hashes := make(map[string]Hash, len(sources))
	for i, src := range sources {
		h, err := cache.Hash(ctx, web, src)
		var status *httpx.StatusError
		if errors.As(err, &status) && status.Code == http.StatusNotFound {
			res.Missing = append(res.Missing, src)
			continue
		}
		if err != nil {
			return nil, fmt.Errorf("image %d (%s): %w", i+1, src, err)
		}
		hashes[src] = h
	}

	// descCaptions is a source's own first caption, for the upload it becomes
	// (unaffected by a repeat elsewhere on the page). creditCaptions groups
	// every appearance's caption by SHA1, in body order, so a credit reaches
	// the upload even when DedupeImages later merges it in from a repeat
	// under a different source URL: the two share bytes, not a source URL.
	descCaptions := map[string]string{}
	creditCaptions := map[string][]string{}
	for _, b := range blocks {
		if b.Kind != Image || b.Caption == "" {
			continue
		}
		if descCaptions[b.Src] == "" {
			descCaptions[b.Src] = b.Caption
		}
		if h, ok := hashes[b.Src]; ok {
			creditCaptions[h.SHA1] = append(creditCaptions[h.SHA1], b.Caption)
		}
	}

	var uploads []string
	for i, src := range sources {
		n := i + 1
		h, ok := hashes[src]
		if !ok {
			continue // a 404, already recorded in res.Missing
		}
		ext := ExtForType(h.Type)
		if ext == "" {
			return nil, fmt.Errorf("image %d (%s) is %s, not an image", n, src, h.Type)
		}
		p := ImagePlan{N: n, Source: src, SHA1: h.SHA1, Size: h.Size}
		if name, ok := planned[h.SHA1]; ok {
			p.Action, p.File = "reuse", name
		} else if name, ok := res.Added[h.SHA1]; ok {
			p.Action, p.File = "reuse", name
		} else if existing, err := FileBySHA1(ctx, wiki, h.SHA1); err != nil {
			return nil, err
		} else if existing != "" {
			p.Action, p.File = "reuse", existing
		} else {
			p.Action = "upload"
			p.File = fmt.Sprintf("%s - %02d%s", page, n, ext)
			desc := descCaptions[src]
			if desc == "" {
				desc = fmt.Sprintf("%s, image %02d", escapeText(rsiTitle), n)
			}
			author := cfg.ImageAuthor
			if a, ok := firstCredit(creditCaptions[h.SHA1]); ok {
				author = a
			}
			p.FilePage = FilePage(desc, date, src, author, cfg.ImageCategory)
			uploads = append(uploads, "File:"+p.File)
		}
		res.Added[h.SHA1] = p.File
		res.files[src] = p.File
		res.Plans = append(res.Plans, p)
	}
	if len(uploads) > 0 {
		exists, err := PagesExist(ctx, wiki, uploads)
		if err != nil {
			return nil, err
		}
		var taken []string
		for _, t := range uploads {
			if exists[t] {
				taken = append(taken, t)
			}
		}
		if len(taken) > 0 {
			return nil, fmt.Errorf("the wiki already has %s, not holding this report's image", strings.Join(taken, ", "))
		}
	}
	return res, nil
}
