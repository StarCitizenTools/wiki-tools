package uuidindex

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/mediawiki"
)

// stubAPI serves canned action-API responses. Each request is dispatched on
// its action and parameters, so a test only has to describe the shapes it
// cares about; anything unasked-for fails the test rather than defaulting to
// something plausible.
type stubAPI struct {
	t *testing.T
	// handler returns the JSON body for a decoded request form.
	handler func(form map[string]string) string
	// requests counts calls, so tests can assert on batching.
	requests int
}

func newStub(t *testing.T, handler func(map[string]string) string) (*stubAPI, *mediawiki.Client) {
	t.Helper()
	stub := &stubAPI{t: t, handler: handler}
	srv := httptest.NewServer(stub)
	t.Cleanup(srv.Close)

	client, err := mediawiki.New(mediawiki.Config{
		Endpoint:  srv.URL,
		UserAgent: "uuidindex-test",
		// Tests must not pay the production rate limit.
		Interval: time.Millisecond,
	})
	if err != nil {
		t.Fatalf("building client: %v", err)
	}
	t.Cleanup(client.Close)
	return stub, client
}

func (s *stubAPI) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil {
		s.t.Errorf("parsing request form: %v", err)
		http.Error(w, "bad form", http.StatusBadRequest)
		return
	}
	form := map[string]string{}
	for k := range r.PostForm {
		form[k] = r.PostForm.Get(k)
	}
	s.requests++
	w.Header().Set("Content-Type", "application/json")
	if _, err := w.Write([]byte(s.handler(form))); err != nil {
		s.t.Errorf("writing response: %v", err)
	}
}

// namespaceOK is the siteinfo response every scan begins with.
const namespaceOK = `{"query":{"namespaces":{"69420":{"id":69420,"case":"first-letter"}}}}`

const emptyAsk = `{"query":{"results":[]}}`

func emptyAllPages() string { return `{"query":{"allpages":[]}}` }

// route dispatches on the parameters that distinguish the scan's four calls.
func route(t *testing.T, ask func(prop string, offset string) string, allpages func(filter, cont string) string, resolve func(titles string) string) func(map[string]string) string {
	t.Helper()
	return func(form map[string]string) string {
		switch {
		case form["meta"] == "siteinfo":
			return namespaceOK
		case form["action"] == "ask":
			prop := "Uuid"
			if strings.Contains(form["query"], "[[UUID::") {
				prop = "UUID"
			}
			return ask(prop, form["query"])
		case form["list"] == "allpages":
			return allpages(form["apfilterredir"], form["apcontinue"])
		case form["titles"] != "":
			return resolve(form["titles"])
		}
		t.Errorf("unexpected request: %v", form)
		return `{}`
	}
}

func TestScanRejectsCaseSensitiveNamespace(t *testing.T) {
	// TitleFor's normalisation would silently target the wrong titles, and the
	// apply step would duplicate the whole index rather than fail.
	_, client := newStub(t, func(map[string]string) string {
		return `{"query":{"namespaces":{"69420":{"id":69420,"case":"case-sensitive"}}}}`
	})
	_, err := Scan(context.Background(), ScanOptions{Client: client})
	if err == nil || !strings.Contains(err.Error(), "first-letter") {
		t.Fatalf("err = %v, want a refusal naming the case setting", err)
	}
}

func TestScanCollectsAnnotationsAndRedirectTargets(t *testing.T) {
	stub, client := newStub(t, route(t,
		func(prop, _ string) string {
			if prop != "Uuid" {
				return emptyAsk
			}
			return `{"query":{"results":{
				"Page A":{"fulltext":"Page A","namespace":0,"printouts":{"Uuid":["` + uuidA + `"]}},
				"Page B#_abc":{"fulltext":"Page B#_abc","namespace":0,"printouts":{"Uuid":["` + uuidB + `"]}}
			}}}`
		},
		func(filter, _ string) string {
			if filter == "redirects" {
				return `{"query":{"allpages":[{"title":"` + TitleFor(uuidA) + `"}]}}`
			}
			return `{"query":{"allpages":[{"title":"UUID:` + PlaceholderUUID + `"}]}}`
		},
		func(string) string {
			return `{"query":{"redirects":[{"from":"` + TitleFor(uuidA) + `","to":"Page A"}]}}`
		},
	))

	scan, err := Scan(context.Background(), ScanOptions{Client: client})
	if err != nil {
		t.Fatalf("Scan: %v", err)
	}
	if got := scan.Properties.Holders[uuidA]; len(got) != 1 || got[0].Page != "Page A" {
		t.Errorf("holders[uuidA] = %v", got)
	}
	// A subobject subject folds onto its page.
	if got := scan.Properties.Holders[uuidB]; len(got) != 1 || got[0].Page != "Page B" {
		t.Errorf("holders[uuidB] = %v, want the fragment stripped", got)
	}
	if len(scan.Pages) != 2 {
		t.Fatalf("pages = %v, want the redirect and the non-redirect", scan.Pages)
	}
	// Pages are sorted, so the placeholder (digits) sorts before UUID:A…
	if p := scan.Pages[0]; p.Redirect || p.Title != "UUID:"+PlaceholderUUID {
		t.Errorf("pages[0] = %+v, want the non-redirect", p)
	}
	if p := scan.Pages[1]; !p.Redirect || p.Target != "Page A" {
		t.Errorf("pages[1] = %+v, want the resolved redirect", p)
	}
	if scan.Requests != stub.requests {
		t.Errorf("Requests = %d, but the server saw %d", scan.Requests, stub.requests)
	}
}

func TestScanErrorsOnNonAdvancingAskContinuation(t *testing.T) {
	// SMW silently resets an offset past $smwgQMaxOffset to zero. Following
	// that continuation loops forever, so it has to be an error.
	_, client := newStub(t, route(t,
		func(prop, _ string) string {
			if prop != "Uuid" {
				return emptyAsk
			}
			return `{"query-continue-offset":0,"query":{"results":{
				"Page A":{"fulltext":"Page A","namespace":0,"printouts":{"Uuid":["` + uuidA + `"]}}
			}}}`
		},
		func(string, string) string { return emptyAllPages() },
		func(string) string { return `{"query":{}}` },
	))

	_, err := Scan(context.Background(), ScanOptions{Client: client})
	if err == nil || !strings.Contains(err.Error(), "did not advance") {
		t.Fatalf("err = %v, want a non-advancing-continuation error", err)
	}
}

func TestScanFollowsAskContinuation(t *testing.T) {
	_, client := newStub(t, route(t,
		func(prop, query string) string {
			if prop != "Uuid" {
				return emptyAsk
			}
			if strings.Contains(query, "offset=0") {
				return `{"query-continue-offset":1,"query":{"results":{
					"Page A":{"fulltext":"Page A","namespace":0,"printouts":{"Uuid":["` + uuidA + `"]}}
				}}}`
			}
			return `{"query":{"results":{
				"Page B":{"fulltext":"Page B","namespace":0,"printouts":{"Uuid":["` + uuidB + `"]}}
			}}}`
		},
		func(string, string) string { return emptyAllPages() },
		func(string) string { return `{"query":{}}` },
	))

	scan, err := Scan(context.Background(), ScanOptions{Client: client})
	if err != nil {
		t.Fatalf("Scan: %v", err)
	}
	if len(scan.Properties.Holders) != 2 {
		t.Errorf("holders = %v, want both pages across the continuation", scan.Properties.Holders)
	}
}

func TestScanErrorsOnUnexpectedAskShape(t *testing.T) {
	// An unparsable body must not read as "nothing is annotated" — that is the
	// input that makes the reconciler plan a mass deletion.
	_, client := newStub(t, route(t,
		func(string, string) string { return `{"query":{"warnings":"something else"}}` },
		func(string, string) string { return emptyAllPages() },
		func(string) string { return `{"query":{}}` },
	))

	_, err := Scan(context.Background(), ScanOptions{Client: client})
	if err == nil || !strings.Contains(err.Error(), "unexpected ask results") {
		t.Fatalf("err = %v, want a refusal to treat an unknown shape as empty", err)
	}
}

func TestScanSurfacesAPIError(t *testing.T) {
	// Action-API errors arrive with HTTP 200.
	_, client := newStub(t, func(form map[string]string) string {
		if form["meta"] == "siteinfo" {
			return namespaceOK
		}
		return `{"error":{"code":"readapidenied","info":"You need read permission"}}`
	})

	_, err := Scan(context.Background(), ScanOptions{Client: client})
	if err == nil || !strings.Contains(err.Error(), "readapidenied") {
		t.Fatalf("err = %v, want the API error surfaced", err)
	}
}

func TestScanFollowsAllPagesContinuation(t *testing.T) {
	_, client := newStub(t, route(t,
		func(string, string) string { return emptyAsk },
		func(filter, cont string) string {
			if filter != "redirects" {
				return emptyAllPages()
			}
			if cont == "" {
				return `{"continue":{"apcontinue":"UUID:B"},"query":{"allpages":[{"title":"UUID:A"}]}}`
			}
			return `{"query":{"allpages":[{"title":"UUID:B"}]}}`
		},
		func(string) string { return `{"query":{}}` },
	))

	scan, err := Scan(context.Background(), ScanOptions{Client: client})
	if err != nil {
		t.Fatalf("Scan: %v", err)
	}
	if len(scan.Pages) != 2 {
		t.Errorf("pages = %v, want both continuation pages", scan.Pages)
	}
}

func TestScanErrorsOnNonAdvancingAllPagesContinuation(t *testing.T) {
	_, client := newStub(t, route(t,
		func(string, string) string { return emptyAsk },
		func(filter, _ string) string {
			if filter != "redirects" {
				return emptyAllPages()
			}
			return `{"continue":{"apcontinue":"UUID:A"},"query":{"allpages":[{"title":"UUID:A"}]}}`
		},
		func(string) string { return `{"query":{}}` },
	))

	_, err := Scan(context.Background(), ScanOptions{Client: client})
	if err == nil || !strings.Contains(err.Error(), "did not advance") {
		t.Fatalf("err = %v, want a stalled-continuation error", err)
	}
}

func TestResolveBatchesEveryTitleExactlyOnce(t *testing.T) {
	// 51 redirects must span two batches with nothing dropped or duplicated.
	const total = 51
	titles := make([]string, total)
	for i := range titles {
		titles[i] = "UUID:" + string(rune('a'+i%26)) + strings.Repeat("0", i/26+1)
	}

	stub, client := newStub(t, route(t,
		func(string, string) string { return emptyAsk },
		func(filter, _ string) string {
			if filter != "redirects" {
				return emptyAllPages()
			}
			var b strings.Builder
			b.WriteString(`{"query":{"allpages":[`)
			for i, tl := range titles {
				if i > 0 {
					b.WriteString(",")
				}
				b.WriteString(`{"title":"` + tl + `"}`)
			}
			b.WriteString(`]}}`)
			return b.String()
		},
		func(batch string) string {
			var b strings.Builder
			b.WriteString(`{"query":{"redirects":[`)
			for i, tl := range strings.Split(batch, "|") {
				if i > 0 {
					b.WriteString(",")
				}
				b.WriteString(`{"from":"` + tl + `","to":"Target of ` + tl + `"}`)
			}
			b.WriteString(`]}}`)
			return b.String()
		},
	))

	scan, err := Scan(context.Background(), ScanOptions{Client: client})
	if err != nil {
		t.Fatalf("Scan: %v", err)
	}
	if len(scan.Pages) != total {
		t.Fatalf("pages = %d, want %d", len(scan.Pages), total)
	}
	seen := map[string]int{}
	for _, p := range scan.Pages {
		seen[p.Title]++
		if want := "Target of " + p.Title; p.Target != want {
			t.Errorf("%s target = %q, want %q", p.Title, p.Target, want)
		}
	}
	for _, tl := range titles {
		if seen[tl] != 1 {
			t.Errorf("%s appeared %d times, want exactly once", tl, seen[tl])
		}
	}
	// 1 siteinfo + 2 ask (one per property) + 2 allpages (one per filter) +
	// 2 resolve batches (50 then 1).
	if want := 7; stub.requests != want {
		t.Errorf("requests = %d, want %d", stub.requests, want)
	}
}

func TestResolveTakesOnlyTheFirstHopOfAChain(t *testing.T) {
	// MediaWiki does not follow double redirects, so neither do we: the plan
	// should see UUID:A pointing at UUID:B and retarget it, not quietly
	// resolve through to the far end.
	first, second := TitleFor(uuidA), TitleFor(uuidB)
	_, client := newStub(t, route(t,
		func(string, string) string { return emptyAsk },
		func(filter, _ string) string {
			if filter != "redirects" {
				return emptyAllPages()
			}
			return `{"query":{"allpages":[{"title":"` + first + `"},{"title":"` + second + `"}]}}`
		},
		func(string) string {
			return `{"query":{"redirects":[
				{"from":"` + first + `","to":"` + second + `"},
				{"from":"` + second + `","to":"Real Page"}
			]}}`
		},
	))

	scan, err := Scan(context.Background(), ScanOptions{Client: client})
	if err != nil {
		t.Fatalf("Scan: %v", err)
	}
	targets := map[string]string{}
	for _, p := range scan.Pages {
		targets[p.Title] = p.Target
	}
	if targets[first] != second {
		t.Errorf("%s target = %q, want the next hop %q", first, targets[first], second)
	}
	if targets[second] != "Real Page" {
		t.Errorf("%s target = %q, want %q", second, targets[second], "Real Page")
	}
}
