package commlink

import (
	"context"
	"crypto/sha1"
	"encoding/hex"
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

func TestImageSources(t *testing.T) {
	got := ImageSources([]Block{{Kind: Image, Src: "a"}, {Kind: Paragraph}, {Kind: Image, Src: "b"}, {Kind: Image, Src: "a"}})
	if !reflect.DeepEqual(got, []string{"a", "b"}) {
		t.Errorf("ImageSources = %v", got)
	}
}

func TestFilePage(t *testing.T) {
	got := FilePage("A report, image 01", "2021-06-02", "https://x/a.png", "Cloud Imperium Games", "Monthly Report images")
	want := "=={{int:filedesc}}==\n{{Information\n|description=A report, image 01\n|date=2021-06-02\n|source=https://x/a.png\n|author=Cloud Imperium Games\n|permission=\n|other versions=\n}}\n\n=={{int:license-header}}==\n{{RSIlicense}}\n\n[[Category:Monthly Report images]]\n"
	if got != want {
		t.Errorf("FilePage:\n%s", got)
	}
}

func TestFilePageEscapesPipe(t *testing.T) {
	got := FilePage("Concept art | Squadron 42", "2021-06-02", "https://x/a.png", "Cloud Imperium Games", "Monthly Report images")
	if !strings.Contains(got, "|description=Concept art &#124; Squadron 42\n") {
		t.Errorf("FilePage did not escape a literal pipe in the description:\n%s", got)
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
	}
	planned := map[string]string{}
	plans, fileFor, err := PlanImages(context.Background(), testWeb(t), wiki, cache, planned, testConfig(t), "A report", "A page", "2021-06-02", blocks)
	if err != nil {
		t.Fatal(err)
	}
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
	if fileFor(srv.URL+"/copy.jpg") != "A page - 02.jpg" || planned[sum(jpegBytes)] != "A page - 02.jpg" {
		t.Errorf("fileFor / planned not updated")
	}
	if _, _, err := PlanImages(context.Background(), testWeb(t), wiki, cache, planned, testConfig(t), "A report", "A page", "2021-06-02",
		[]Block{{Kind: Image, Src: srv.URL + "/page.html"}}); err == nil {
		t.Error("a non-image source was accepted")
	}
}
