package commlink

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
)

func TestFetchTitleMatches(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		if q.Get("filter[title]") != "Monthly" || q.Get("page[size]") != "200" {
			t.Errorf("query = %s", r.URL.RawQuery)
		}
		switch q.Get("page[number]") {
		case "1":
			io.WriteString(w, `{"data":[
				{"id":2,"title":"Star Citizen Monthly Report: May 2021","rsi_url":"https://robertsspaceindustries.com/en/comm-link/transmission/2-X","created_at":"2021-06-02T00:00:00+00:00","translations":{"en_EN":"Body","de_DE":"Text"}},
				{"id":3,"title":"Monthly Store Bundle 2026","rsi_url":"u3","created_at":"","translations":{}}
			],"meta":{"last_page":2}}`)
		case "2":
			io.WriteString(w, `{"data":[{"id":1,"title":"Monthly Report: April 2014","rsi_url":"u1","created_at":"2014-05-01T00:00:00+00:00","translations":{"en_EN":"Old"}}],"meta":{"last_page":2}}`)
		default:
			t.Errorf("unexpected page: %s", r.URL.RawQuery)
			io.WriteString(w, `{"data":[],"meta":{"last_page":2}}`)
		}
	}))
	defer srv.Close()

	got, err := FetchTitleMatches(context.Background(), testWeb(t), Endpoints{API: srv.URL}, "Monthly", testConfig(t).MatchesTitle)
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 || got[0].ID != 2 || got[1].ID != 1 {
		t.Fatalf("got %+v", got)
	}
	if got[0].Text != "Body" || got[0].Title != "Star Citizen Monthly Report: May 2021" || !reflect.DeepEqual(got[0].FoundBy, []string{FoundByTitle}) {
		t.Errorf("candidate = %+v", got[0])
	}
}

// hubItemMarkup is one item of RSI's series listing, trimmed from the live
// markup; posted is what its "Posted:" value reads.
func hubItemMarkup(href, posted string) string {
	return `  <a class="content-block2 hub-block one_third 
    "
  href="` + href + `"  data-original_class="one_third"
>
    <div class="type post"><div class="icon"></div><span>post</span></div>
  <div class="title-holder">
    <div class="title trans-opacity trans-03s">Star Citizen Monthly Report</div>
  </div>
  <div class="text">
    <div class="comments">24</div>
    <div class="time_ago">Posted: <span class="value">` + posted + `</span></div>
    <div class="section"></div>
  </div>
  <div class="over trans-opacity trans-02s">
    <div class="scroller trans-03s">
      <div class="body">
        <p>__</p>
      </div>
    </div>
  </div>
</a>
`
}

func TestFetchSeries(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/hub/getCommlinkItems" || r.Header.Get("Content-Type") != "application/json" {
			t.Errorf("request %s %s type %q", r.Method, r.URL.Path, r.Header.Get("Content-Type"))
		}
		var body struct {
			Series string `json:"series"`
			Page   int    `json:"page"`
		}
		json.NewDecoder(r.Body).Decode(&body)
		if body.Series != "monthly-report" {
			t.Errorf("series = %q", body.Series)
		}
		data := map[int]string{
			1: hubItemMarkup("/comm-link/transmission/21307-Star-Citizen-Monthly-Report-August-2026", "3 weeks ago") +
				hubItemMarkup("/comm-link/transmission/18251-Star-Citizen-Monthly-Report-July-2021", "2021-08-04 20:17:28"),
			2: hubItemMarkup("/comm-link/transmission/15833-Monthly-Studio-Report-March-2017", "2017-04-14 17:02:11"),
		}[body.Page]
		enc, _ := json.Marshal(map[string]any{"success": 1, "data": data})
		w.Write(enc)
	}))
	defer srv.Close()

	got, err := FetchSeries(context.Background(), testWeb(t), Endpoints{RSI: srv.URL}, "monthly-report")
	if err != nil {
		t.Fatal(err)
	}
	want := []SeriesItem{
		{ID: 21307, URL: srv.URL + "/comm-link/transmission/21307-Star-Citizen-Monthly-Report-August-2026", Title: "Star Citizen Monthly Report"},
		{ID: 18251, URL: srv.URL + "/comm-link/transmission/18251-Star-Citizen-Monthly-Report-July-2021", Posted: "2021-08-04", Title: "Star Citizen Monthly Report"},
		{ID: 15833, URL: srv.URL + "/comm-link/transmission/15833-Monthly-Studio-Report-March-2017", Posted: "2017-04-14", Title: "Star Citizen Monthly Report"},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("items = %+v, want %+v", got, want)
	}
}

// An empty listing is an error, not a series with no reports.
func TestFetchSeriesEmpty(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		io.WriteString(w, `{"success":1,"data":"<div class=\"hub-blocks\"></div>"}`)
	}))
	defer srv.Close()
	if items, err := FetchSeries(context.Background(), testWeb(t), Endpoints{RSI: srv.URL}, "monthly-report"); err == nil {
		t.Errorf("FetchSeries = %+v, want an error", items)
	}
}

func TestUnion(t *testing.T) {
	titled := []Candidate{
		{ID: 2, Title: "B", FoundBy: []string{FoundByTitle}},
		{ID: 1, Title: "A", FoundBy: []string{FoundByTitle}},
	}
	fetched := 0
	fetch := func(_ context.Context, id int) (Candidate, error) {
		fetched++
		return Candidate{ID: id, Title: "E"}, nil
	}
	got, dis, review, err := Union(context.Background(), titled, []SeriesItem{{ID: 2, Posted: "2021-06-02", Title: "B, as listed"}, {ID: 5}}, FoundBySeries, fetch)
	if err != nil || len(review) != 0 {
		t.Fatal(review, err)
	}
	var ids []int
	for _, c := range got {
		ids = append(ids, c.ID)
	}
	if !reflect.DeepEqual(ids, []int{1, 2, 5}) || fetched != 1 {
		t.Fatalf("ids = %v, fetched %d", ids, fetched)
	}
	if !reflect.DeepEqual(got[1].FoundBy, []string{FoundByTitle, FoundBySeries}) {
		t.Errorf("id 2 found by %v", got[1].FoundBy)
	}
	if got[0].Posted != "" || got[1].Posted != "2021-06-02" || got[2].Posted != "" {
		t.Errorf("posted dates = %q %q %q", got[0].Posted, got[1].Posted, got[2].Posted)
	}
	if got[1].Title != "B" {
		t.Errorf("title = %q, want the API's: only a site-suffixed API title yields to the listing's", got[1].Title)
	}
	want := []Disagreement{{ID: 1, Title: "A", FoundBy: FoundByTitle}, {ID: 5, Title: "E", FoundBy: FoundBySeries}}
	if !reflect.DeepEqual(dis, want) {
		t.Errorf("disagreements = %+v", dis)
	}
}

// A report only the series lists, which the API answers with 404 for, goes to
// review and the union carries on; any other fetch error ends it.
func TestUnionAPINotFound(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/7":
			io.WriteString(w, `{"data":{"id":7,"title":"G","rsi_url":"u7","translations":{"en_EN":"Text"}}}`)
		case "/9":
			http.Error(w, "down", http.StatusForbidden)
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()
	fetch := func(ctx context.Context, id int) (Candidate, error) {
		return FetchRecord(ctx, testWeb(t), Endpoints{API: srv.URL}, id)
	}
	series := []SeriesItem{{ID: 8, URL: "https://rsi.test/comm-link/transmission/8-X"}, {ID: 7}}
	got, dis, review, err := Union(context.Background(), nil, series, FoundBySeries, fetch)
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 1 || got[0].ID != 7 {
		t.Errorf("candidates = %+v, want only 7", got)
	}
	if len(review) != 1 || review[0].ID != 8 || review[0].Reason != ReasonFetch ||
		!strings.Contains(review[0].Detail[0], "404") || !strings.Contains(review[0].Detail[0], "https://rsi.test/comm-link/transmission/8-X") {
		t.Errorf("review = %+v", review)
	}
	if want := []Disagreement{{ID: 7, Title: "G", FoundBy: FoundBySeries}, {ID: 8, FoundBy: FoundBySeries}}; !reflect.DeepEqual(dis, want) {
		t.Errorf("disagreements = %+v, want %+v", dis, want)
	}
	if _, _, _, err := Union(context.Background(), nil, []SeriesItem{{ID: 9}}, FoundBySeries, fetch); err == nil {
		t.Error("a 403 from the API did not end the union")
	}
}

// A channel listing sends the slug as the channel, with no series.
func TestFetchChannel(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Channel string `json:"channel"`
			Series  string `json:"series"`
			Page    int    `json:"page"`
		}
		json.NewDecoder(r.Body).Decode(&body)
		if body.Channel != "serialized-fiction" || body.Series != "" {
			t.Errorf("channel = %q, series = %q", body.Channel, body.Series)
		}
		data := ""
		if body.Page == 1 {
			data = hubItemMarkup("/comm-link/serialized-fiction/18080-A-Gift-For-Baba-Part-1", "2021-04-14 00:00:21")
		}
		enc, _ := json.Marshal(map[string]any{"success": 1, "data": data})
		w.Write(enc)
	}))
	defer srv.Close()
	got, err := FetchChannel(context.Background(), testWeb(t), Endpoints{RSI: srv.URL}, "serialized-fiction")
	if err != nil {
		t.Fatal(err)
	}
	want := []SeriesItem{{ID: 18080, URL: srv.URL + "/comm-link/serialized-fiction/18080-A-Gift-For-Baba-Part-1", Posted: "2021-04-14", Title: "Star Citizen Monthly Report"}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("items = %+v, want %+v", got, want)
	}
}

// The API's channel filter keeps every title, and each record's series label.
func TestFetchChannelMatches(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		if q.Get("filter[channel]") != "Serialized Fiction" || q.Get("filter[title]") != "" || q.Get("page[size]") != "200" {
			t.Errorf("query = %s", r.URL.RawQuery)
		}
		io.WriteString(w, `{"data":[
			{"id":18261,"title":"The Payout","series":"News Update","rsi_url":"u1","translations":{"en_EN":"Text"}},
			{"id":16435,"title":"The Cup: Part One","series":" The Cup ","rsi_url":"u2","translations":{}}
		],"meta":{"last_page":1}}`)
	}))
	defer srv.Close()
	got, err := FetchChannelMatches(context.Background(), testWeb(t), Endpoints{API: srv.URL}, "Serialized Fiction")
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 || got[0].Series != "News Update" || got[1].Series != "The Cup" ||
		!reflect.DeepEqual(got[0].FoundBy, []string{FoundByAPIChannel}) {
		t.Errorf("candidates = %+v", got)
	}
}

// A report only the channel listing names is found by it alone.
func TestUnionChannel(t *testing.T) {
	found := []Candidate{{ID: 1, Title: "A", FoundBy: []string{FoundByAPIChannel}}}
	fetch := func(_ context.Context, id int) (Candidate, error) { return Candidate{ID: id, Title: "Baba"}, nil }
	got, dis, _, err := Union(context.Background(), found, []SeriesItem{{ID: 1}, {ID: 2}}, FoundByChannel, fetch)
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got[0].FoundBy, []string{FoundByAPIChannel, FoundByChannel}) || !reflect.DeepEqual(got[1].FoundBy, []string{FoundByChannel}) {
		t.Errorf("found by %v and %v", got[0].FoundBy, got[1].FoundBy)
	}
	if want := []Disagreement{{ID: 2, Title: "Baba", FoundBy: FoundByChannel}}; !reflect.DeepEqual(dis, want) {
		t.Errorf("disagreements = %+v, want %+v", dis, want)
	}
}

// An API title that is the page's og:title, with RSI's site suffix, yields to
// the listing's title, for a report either source found.
func TestUnionListedTitle(t *testing.T) {
	found := []Candidate{{ID: 21086, Title: "DefenseCon 2956 Ship Q&A | Star Citizen", FoundBy: []string{FoundByAPIChannel}}}
	fetch := func(_ context.Context, id int) (Candidate, error) {
		return Candidate{ID: id, Title: "Other | Star Citizen"}, nil
	}
	got, _, _, err := Union(context.Background(), found, []SeriesItem{
		{ID: 21086, Title: "Q&A: DefenseCon 2956 New Ships"},
		{ID: 21090, Title: "Q&A: Other"},
		{ID: 21091},
	}, FoundByChannel, fetch)
	if err != nil {
		t.Fatal(err)
	}
	var titles []string
	for _, c := range got {
		titles = append(titles, c.Title)
	}
	if want := []string{"Q&A: DefenseCon 2956 New Ships", "Q&A: Other", "Other | Star Citizen"}; !reflect.DeepEqual(titles, want) {
		t.Errorf("titles = %q, want %q", titles, want)
	}
}
