package commlink

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"reflect"
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
	want := []SeriesItem{{ID: 21307}, {ID: 18251, Posted: "2021-08-04"}, {ID: 15833, Posted: "2017-04-14"}}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("items = %+v, want %+v", got, want)
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
	got, dis, err := Union(context.Background(), titled, []SeriesItem{{ID: 2, Posted: "2021-06-02"}, {ID: 5}}, fetch)
	if err != nil {
		t.Fatal(err)
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
	want := []Disagreement{{ID: 1, Title: "A", FoundBy: FoundByTitle}, {ID: 5, Title: "E", FoundBy: FoundBySeries}}
	if !reflect.DeepEqual(dis, want) {
		t.Errorf("disagreements = %+v", dis)
	}
}
