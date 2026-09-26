package commlink

import (
	"context"
	"net/url"
	"reflect"
	"testing"
)

func TestExistingIDs(t *testing.T) {
	wiki := testWiki(t, func(form url.Values) string {
		if form.Get("action") != "bucket" {
			t.Errorf("action = %q", form.Get("action"))
		}
		return `{"bucketQuery":"q","bucket":[
			{"page_name":"Comm-Link:A","rsi_id":15833},
			{"page_name":"Comm-Link:B","rsi_id":"14126"},
			{"page_name":"Comm-Link:C"}
		]}`
	})
	got, err := ExistingIDs(context.Background(), wiki)
	if err != nil {
		t.Fatal(err)
	}
	if want := map[int]string{15833: "Comm-Link:A", 14126: "Comm-Link:B"}; !reflect.DeepEqual(got, want) {
		t.Errorf("ExistingIDs = %v", got)
	}
}

func TestPagesExist(t *testing.T) {
	wiki := testWiki(t, func(form url.Values) string {
		return `{"query":{
			"normalized":[{"from":"Comm-Link:monthly Report - X","to":"Comm-Link:Monthly Report - X"}],
			"pages":[{"title":"Comm-Link:Monthly Report - X"},{"title":"Comm-Link:New","missing":true}]}}`
	})
	got, err := PagesExist(context.Background(), wiki, []string{"Comm-Link:monthly Report - X", "Comm-Link:New"})
	if err != nil {
		t.Fatal(err)
	}
	if want := map[string]bool{"Comm-Link:monthly Report - X": true, "Comm-Link:New": false}; !reflect.DeepEqual(got, want) {
		t.Errorf("PagesExist = %v", got)
	}
}

func TestCategoryMembers(t *testing.T) {
	calls := 0
	wiki := testWiki(t, func(form url.Values) string {
		calls++
		if form.Get("cmtitle") != "Category:Ships" || form.Get("cmnamespace") != "0" {
			t.Errorf("form = %v", form)
		}
		if form.Get("cmcontinue") == "" {
			return `{"continue":{"cmcontinue":"page|X","continue":"-||"},"query":{"categorymembers":[{"title":"Gladius"}]}}`
		}
		return `{"query":{"categorymembers":[{"title":"Idris-M"}]}}`
	})
	got, err := CategoryMembers(context.Background(), wiki, "Ships")
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got, []string{"Gladius", "Idris-M"}) || calls != 2 {
		t.Errorf("CategoryMembers = %v after %d calls", got, calls)
	}
}

func TestFileBySHA1(t *testing.T) {
	wiki := testWiki(t, func(form url.Values) string {
		if form.Get("aisha1") == "abc" {
			return `{"query":{"allimages":[{"name":"MrFeb2017LA.jpg","title":"File:MrFeb2017LA.jpg"}]}}`
		}
		return `{"query":{"allimages":[]}}`
	})
	if got, _ := FileBySHA1(context.Background(), wiki, "abc"); got != "MrFeb2017LA.jpg" {
		t.Errorf("FileBySHA1(abc) = %q", got)
	}
	if got, _ := FileBySHA1(context.Background(), wiki, "def"); got != "" {
		t.Errorf("FileBySHA1(def) = %q", got)
	}
}
