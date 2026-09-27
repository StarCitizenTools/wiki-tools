package commlink

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
	"maps"
	"net/http"
	"net/http/httptest"
	"net/url"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

var (
	pngBytes  = []byte("\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR" + strings.Repeat("\x00", 32))
	jpegBytes = []byte("\xff\xd8\xff\xe0\x00\x10JFIF" + strings.Repeat("\x00", 32))
)

func sum(b []byte) string { s := sha1.Sum(b); return hex.EncodeToString(s[:]) }

func TestVideoLinks(t *testing.T) {
	got := VideoLinks([]Block{{Kind: Image, Src: "https://x/a.MP4"}, {Kind: Image, Src: "https://x/b.png"}})
	if got[0].Kind != Video || got[0].VideoKind != "file" || got[0].Src != "https://x/a.MP4" || got[1].Kind != Image {
		t.Errorf("VideoLinks = %+v", got)
	}
}

func TestDedupeImagesDropsAPlainRepeat(t *testing.T) {
	blocks := []Block{
		{Kind: Image, Src: "https://x/a.jpg"},
		{Kind: Paragraph, Text: "Between."},
		{Kind: Image, Src: "https://x/a-resized.jpg"}, // same resolved file as a.jpg
	}
	files := map[string]string{"https://x/a.jpg": "R - 01.jpg", "https://x/a-resized.jpg": "R - 01.jpg"}
	got := DedupeImages(blocks, func(src string) string { return files[src] })
	want := []Block{blocks[0], blocks[1]}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("DedupeImages = %+v, want %+v", got, want)
	}
}

func TestDedupeImagesMovesACaptionToTheKeptAppearance(t *testing.T) {
	blocks := []Block{
		{Kind: Image, Src: "https://x/a.jpg"},
		{Kind: Image, Src: "https://x/a-again.jpg", Caption: "Image by Someone"},
	}
	files := map[string]string{"https://x/a.jpg": "R - 01.jpg", "https://x/a-again.jpg": "R - 01.jpg"}
	got := DedupeImages(blocks, func(src string) string { return files[src] })
	want := []Block{{Kind: Image, Src: "https://x/a.jpg", Caption: "Image by Someone"}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("DedupeImages = %+v, want %+v", got, want)
	}
}

func TestDedupeImagesKeepsBothOnDifferingCaptions(t *testing.T) {
	blocks := []Block{
		{Kind: Image, Src: "https://x/a.jpg", Caption: "First caption"},
		{Kind: Image, Src: "https://x/a-again.jpg", Caption: "Second caption"},
	}
	files := map[string]string{"https://x/a.jpg": "R - 01.jpg", "https://x/a-again.jpg": "R - 01.jpg"}
	got := DedupeImages(blocks, func(src string) string { return files[src] })
	if !reflect.DeepEqual(got, blocks) {
		t.Errorf("DedupeImages = %+v, want both appearances kept: %+v", got, blocks)
	}
}

// A literal pipe in the description or author is escaped, so it cannot open a
// spurious {{Information}} parameter.
func TestFilePage(t *testing.T) {
	for _, c := range []struct{ desc, author, wantDesc, wantAuthor string }{
		{"A report, image 01", "Cloud Imperium Games", "A report, image 01", "Cloud Imperium Games"},
		{"Concept art | Squadron 42", "[https://y John | Doe]", "Concept art &#124; Squadron 42", "[https://y John &#124; Doe]"},
	} {
		got := FilePage(c.desc, "2021-06-02", "https://x/a.png", c.author, "Monthly Report images")
		want := "=={{int:filedesc}}==\n{{Information\n|description=" + c.wantDesc + "\n|date=2021-06-02\n|source=https://x/a.png\n|author=" + c.wantAuthor +
			"\n|permission=\n|other versions=\n}}\n\n=={{int:license-header}}==\n{{RSIlicense}}\n\n[[Category:Monthly Report images]]\n"
		if got != want {
			t.Errorf("FilePage(%q, %q):\n%s\nwant:\n%s", c.desc, c.author, got, want)
		}
	}
}

// An upload's author= is the first caption, over every appearance of its bytes
// in body order, that is wholly an "image by" credit, else cfg.ImageAuthor. A
// page can show one picture under two source URLs, and DedupeImages merges
// them only after PlanImages has chosen the author, so the credit is found by
// SHA1. The description stays the upload source's own caption.
func TestPlanImagesCredits(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/other") {
			w.Write(pngBytes)
			return
		}
		w.Write(jpegBytes)
	}))
	defer srv.Close()
	wiki := testWiki(t, func(url.Values) string { return `{"query":{"allimages":[]}}` })
	cache, _ := LoadCache(filepath.Join(t.TempDir(), "cache.json"))
	img := func(path, caption string) Block { return Block{Kind: Image, Src: srv.URL + path, Caption: caption} }
	const cig = "Cloud Imperium Games"
	for _, c := range []struct {
		name    string
		blocks  []Block
		authors []string // per plan; "" for a reuse
		desc    string   // the first plan's
	}{
		{"whole-caption credit", []Block{img("/a.jpg", "Image by Barao")}, []string{"Barao"}, "Image by Barao"},
		{"linked name stays a link", []Block{img("/a.jpg", "image by [https://y Name]")}, []string{"[https://y Name]"}, "image by [https://y Name]"},
		{"pipe in a credited name", []Block{img("/a.jpg", "Image by [https://y John | Doe]")}, []string{"[https://y John &#124; Doe]"}, "Image by [https://y John &#124; Doe]"},
		{"caption that is not a credit", []Block{img("/a.jpg", "Bar Citizen Beijing")}, []string{cig}, "Bar Citizen Beijing"},
		{"another caption that is not", []Block{img("/a.jpg", "Winners of Show Us Your Colors 2024")}, []string{cig}, "Winners of Show Us Your Colors 2024"},
		{"image by not at the start", []Block{img("/a.jpg", "A crowd credits image by Barao")}, []string{cig}, "A crowd credits image by Barao"},
		{"credit stays with its own image", []Block{img("/a.jpg", "Image by Barao"), img("/other.png", "Bar Citizen Beijing")}, []string{"Barao", cig}, "Image by Barao"},
		{"credit on a repeat under another URL", []Block{img("/a.jpg", ""), img("/a-repeat.jpg", "Image by Someone")}, []string{"Someone", ""}, "R, image 01"},
		{"credit among differing captions", []Block{img("/a.jpg", "A studio photo"), img("/a-repeat.jpg", "Image by Someone")}, []string{"Someone", ""}, "A studio photo"},
		{"first of two credits", []Block{img("/a.jpg", "Image by First"), img("/a-repeat.jpg", "Image by Second")}, []string{"First", ""}, "Image by First"},
	} {
		res, err := PlanImages(context.Background(), testWeb(t), wiki, cache, map[string]string{}, testConfig(t), "R", "A page", "2021-06-02", c.blocks)
		if err != nil {
			t.Fatalf("%s: %v", c.name, err)
		}
		if len(res.Plans) != len(c.authors) {
			t.Fatalf("%s: plans = %+v, want %d", c.name, res.Plans, len(c.authors))
		}
		for i, p := range res.Plans {
			if c.authors[i] == "" {
				if p.Action != "reuse" || p.FilePage != "" {
					t.Errorf("%s: image %d = %+v, want a reuse of image 1's upload", c.name, i+1, p)
				}
			} else if !strings.Contains(p.FilePage, "|author="+c.authors[i]+"\n") {
				t.Errorf("%s: image %d FilePage, want author %q:\n%s", c.name, i+1, c.authors[i], p.FilePage)
			}
		}
		if !strings.Contains(res.Plans[0].FilePage, "|description="+c.desc+"\n") {
			t.Errorf("%s: image 1 FilePage, want description %q:\n%s", c.name, c.desc, res.Plans[0].FilePage)
		}
	}
}

func TestCache(t *testing.T) {
	hits := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { hits++; w.Write(pngBytes) }))
	defer srv.Close()
	path := filepath.Join(t.TempDir(), "cache.json")
	c, err := LoadCache(path)
	if err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 2; i++ {
		h, err := c.Hash(context.Background(), testWeb(t), srv.URL+"/a.png")
		if err != nil || h.SHA1 != sum(pngBytes) || h.Type != "image/png" || h.Size != len(pngBytes) {
			t.Fatalf("Hash = %+v, %v", h, err)
		}
	}
	if hits != 1 {
		t.Errorf("downloaded %d times, want 1", hits)
	}
	c.Captures["u"] = "2021-06-09T17:32:41Z"
	if err := c.Save(); err != nil {
		t.Fatal(err)
	}
	again, err := LoadCache(path)
	if err != nil || again.Hashes[srv.URL+"/a.png"].SHA1 != sum(pngBytes) || again.Captures["u"] == "" {
		t.Errorf("reloaded cache = %+v, %v", again, err)
	}
}

func TestPlanImages(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/old.png":
			w.Write(pngBytes)
		case "/new.jpg", "/copy.jpg":
			w.Write(jpegBytes)
		case "/page.html":
			w.Write([]byte("<html>not an image</html>"))
		}
	}))
	defer srv.Close()
	wiki := testWiki(t, func(form url.Values) string {
		if form.Get("aisha1") == sum(pngBytes) {
			return `{"query":{"allimages":[{"title":"File:Old.png"}]}}`
		}
		return `{"query":{"allimages":[]}}`
	})
	cache, _ := LoadCache(filepath.Join(t.TempDir(), "cache.json"))
	blocks := []Block{
		{Kind: Image, Src: srv.URL + "/old.png"},
		{Kind: Image, Src: srv.URL + "/new.jpg", Caption: "image by Someone"},
		{Kind: Image, Src: srv.URL + "/copy.jpg"},
		{Kind: Image, Src: srv.URL + "/old.png"}, // a repeated source is planned once
	}
	planned := map[string]string{}
	res, err := PlanImages(context.Background(), testWeb(t), wiki, cache, planned, testConfig(t), "A report", "A page", "2021-06-02", blocks)
	if err != nil {
		t.Fatal(err)
	}
	plans := res.Plans
	if len(plans) != 3 {
		t.Fatalf("plans = %+v", plans)
	}
	if plans[0].Action != "reuse" || plans[0].File != "Old.png" {
		t.Errorf("image 1 = %+v", plans[0])
	}
	if plans[1].Action != "upload" || plans[1].File != "A page - 02.jpg" || !strings.Contains(plans[1].FilePage, "|description=image by Someone\n") || !strings.Contains(plans[1].FilePage, "|source="+srv.URL+"/new.jpg\n") {
		t.Errorf("image 2 = %+v", plans[1])
	}
	if plans[2].Action != "reuse" || plans[2].File != "A page - 02.jpg" {
		t.Errorf("image 3 (same bytes as 2) = %+v", plans[2])
	}
	if res.File(srv.URL+"/copy.jpg") != "A page - 02.jpg" || res.Added[sum(jpegBytes)] != "A page - 02.jpg" {
		t.Errorf("File / Added not updated")
	}
	if len(planned) != 0 {
		t.Errorf("PlanImages wrote to planned: %v", planned)
	}
	if _, err := PlanImages(context.Background(), testWeb(t), wiki, cache, planned, testConfig(t), "A report", "A page", "2021-06-02",
		[]Block{{Kind: Image, Src: srv.URL + "/page.html"}}); err == nil {
		t.Error("a non-image source was accepted")
	}
}

func TestPlanImagesLeavesOutA404(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/a.png":
			w.Write(pngBytes)
		case "/forbidden.png":
			http.Error(w, "no", http.StatusForbidden)
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()
	wiki := testWiki(t, func(url.Values) string { return `{"query":{"allimages":[]}}` })
	cache, _ := LoadCache(filepath.Join(t.TempDir(), "cache.json"))
	gone := srv.URL + "/gone.jpg"
	blocks := []Block{{Kind: Image, Src: gone}, {Kind: Image, Src: srv.URL + "/a.png"}}
	res, err := PlanImages(context.Background(), testWeb(t), wiki, cache, map[string]string{}, testConfig(t), "A report", "A page", "2021-06-02", blocks)
	if err != nil {
		t.Fatal(err)
	}
	if len(res.Plans) != 1 || res.Plans[0].N != 2 || res.Plans[0].File != "A page - 02.png" {
		t.Errorf("plans = %+v, want only image 2", res.Plans)
	}
	if !reflect.DeepEqual(res.Missing, []string{gone}) {
		t.Errorf("missing = %q, want %q", res.Missing, gone)
	}
	if res.File(gone) != "" {
		t.Errorf("File(404 source) = %q, want none", res.File(gone))
	}
	if _, ok := cache.Hashes[gone]; ok {
		t.Error("a 404 was cached")
	}
	if _, err := PlanImages(context.Background(), testWeb(t), wiki, cache, map[string]string{}, testConfig(t), "A report", "A page", "2021-06-02",
		[]Block{{Kind: Image, Src: srv.URL + "/forbidden.png"}}); err == nil {
		t.Error("a 403 was left out instead of sent to review")
	}
}

// A page's images join the run's planned map only once the caller writes the
// page: a page held back must not leave a later page reusing an upload that
// never happens.
func TestPlanImagesCrossPageReuse(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.Write(pngBytes) }))
	defer srv.Close()
	wiki := testWiki(t, func(url.Values) string { return `{"query":{"allimages":[],"pages":[]}}` })
	cache, _ := LoadCache(filepath.Join(t.TempDir(), "cache.json"))
	planned := map[string]string{}
	plan := func(page string) *PageImages {
		t.Helper()
		res, err := PlanImages(context.Background(), testWeb(t), wiki, cache, planned, testConfig(t), "R", page, "2021-06-02",
			[]Block{{Kind: Image, Src: srv.URL + "/" + page + ".png"}})
		if err != nil || len(res.Plans) != 1 {
			t.Fatalf("PlanImages(%s) = %+v, %v", page, res, err)
		}
		return res
	}

	a := plan("A")
	if got := plan("B").Plans[0]; got.Action != "upload" || got.File != "B - 01.png" {
		t.Errorf("with page A held back, page B's image = %+v, want its own upload", got)
	}
	maps.Copy(planned, a.Added)
	if got := plan("B").Plans[0]; got.Action != "reuse" || got.File != "A - 01.png" {
		t.Errorf("with page A written, page B's image = %+v, want a reuse of A - 01.png", got)
	}
}

// An upload whose name the wiki already holds sends the page to review: the
// file there has other bytes, or the SHA1 lookup would have reused it.
func TestPlanImagesNameTaken(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.Write(pngBytes) }))
	defer srv.Close()
	var asked []string
	wiki := testWiki(t, func(form url.Values) string {
		if form.Get("titles") != "" {
			asked = append(asked, form.Get("titles"))
			return `{"query":{"pages":[{"title":"File:A page - 01.png"}]}}`
		}
		return `{"query":{"allimages":[]}}`
	})
	cache, _ := LoadCache(filepath.Join(t.TempDir(), "cache.json"))
	_, err := PlanImages(context.Background(), testWeb(t), wiki, cache, map[string]string{}, testConfig(t), "R", "A page", "2021-06-02",
		[]Block{{Kind: Image, Src: srv.URL + "/a.png"}})
	if err == nil || !strings.Contains(err.Error(), "File:A page - 01.png") {
		t.Errorf("err = %v, want one naming File:A page - 01.png", err)
	}
	if !reflect.DeepEqual(asked, []string{"File:A page - 01.png"}) {
		t.Errorf("existence queries = %q", asked)
	}
}

// An upload name built from a page title carries no character MediaWiki
// forbids in a file name; each maps to a lookalike, as in PageFileName.
func TestPlanImagesSafeUploadName(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.Write(pngBytes) }))
	defer srv.Close()
	wiki := testWiki(t, func(url.Values) string { return `{"query":{"allimages":[]}}` })
	cache, _ := LoadCache(filepath.Join(t.TempDir(), "cache.json"))
	const page = `A/B: C\D #1 <x> [y] {z} |w|`
	res, err := PlanImages(context.Background(), testWeb(t), wiki, cache, map[string]string{}, testConfig(t), "R", page, "2021-06-02",
		[]Block{{Kind: Image, Src: srv.URL + "/a.png"}})
	if err != nil {
		t.Fatal(err)
	}
	const want = `A∕B∶ C∖D ＃1 ＜x＞ ［y］ ｛z｝ ｜w｜`
	if got := res.Plans[0].File; got != want+" - 01.png" {
		t.Errorf("upload name = %q, want %q", got, want+" - 01.png")
	}
	if got := PageFileName(page); got != want+".wikitext" {
		t.Errorf("PageFileName = %q, want %q", got, want+".wikitext")
	}
}
