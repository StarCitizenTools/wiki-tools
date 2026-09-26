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
// monthly-report import used. description is expected to have already passed
// through escapeText (a block's Caption does); a literal pipe survives that,
// so it is escaped here to stop it opening a spurious {{Information}} parameter.
func FilePage(description, date, source, author, category string) string {
	description = strings.ReplaceAll(description, "|", "&#124;")
	return "=={{int:filedesc}}==\n{{Information\n|description=" + description +
		"\n|date=" + date + "\n|source=" + source + "\n|author=" + author +
		"\n|permission=\n|other versions=\n}}\n\n=={{int:license-header}}==\n{{RSIlicense}}\n\n[[Category:" + category + "]]\n"
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

// PlanImages plans a page's images in body order and returns the source-to-file
// mapping the renderer needs. planned maps SHA1 to the file name already chosen
// for it this run, so a picture two reports share is uploaded once.
func PlanImages(ctx context.Context, web *httpx.Client, wiki *mediawiki.Client, cache *Cache, planned map[string]string,
	cfg *Config, rsiTitle, page, date string, blocks []Block) ([]ImagePlan, func(string) string, error) {
	captions := map[string]string{}
	for _, b := range blocks {
		if b.Kind == Image && b.Caption != "" && captions[b.Src] == "" {
			captions[b.Src] = b.Caption
		}
	}
	names := map[string]string{}
	var plans []ImagePlan
	for i, src := range ImageSources(blocks) {
		n := i + 1
		h, err := cache.Hash(ctx, web, src)
		if err != nil {
			return nil, nil, fmt.Errorf("image %d (%s): %w", n, src, err)
		}
		ext := ExtForType(h.Type)
		if ext == "" {
			return nil, nil, fmt.Errorf("image %d (%s) is %s, not an image", n, src, h.Type)
		}
		p := ImagePlan{N: n, Source: src, SHA1: h.SHA1, Size: h.Size}
		if name, ok := planned[h.SHA1]; ok {
			p.Action, p.File = "reuse", name
		} else if existing, err := FileBySHA1(ctx, wiki, h.SHA1); err != nil {
			return nil, nil, err
		} else if existing != "" {
			p.Action, p.File = "reuse", existing
		} else {
			p.Action = "upload"
			p.File = fmt.Sprintf("%s - %02d%s", page, n, ext)
			desc := captions[src]
			if desc == "" {
				desc = fmt.Sprintf("%s, image %02d", escapeText(rsiTitle), n)
			}
			p.FilePage = FilePage(desc, date, src, cfg.ImageAuthor, cfg.ImageCategory)
		}
		planned[h.SHA1] = p.File
		names[src] = p.File
		plans = append(plans, p)
	}
	return plans, func(src string) string { return names[src] }, nil
}
