package commlink

import (
	"context"
	"fmt"
	"net/url"
	"strconv"
	"strings"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/bucket"
	"github.com/StarCitizenTools/wiki-tools/scripts/internal/mediawiki"
)

// ExistingIDs maps each RSI number stored in the comm_link table to its page.
func ExistingIDs(ctx context.Context, client *mediawiki.Client) (map[int]string, error) {
	rows, _, err := bucket.Rows(ctx, client, "comm_link", func(offset int) string {
		return fmt.Sprintf(`bucket("comm_link").select("page_name","rsi_id").limit(%d).offset(%d).run()`, bucket.PageSize, offset)
	})
	if err != nil {
		return nil, err
	}
	out := make(map[int]string, len(rows))
	for _, r := range rows {
		page, _ := r["page_name"].(string)
		var id int
		switch v := r["rsi_id"].(type) {
		case float64:
			id = int(v)
		case string:
			id, _ = strconv.Atoi(v)
		}
		if id > 0 && page != "" {
			out[id] = page
		}
	}
	return out, nil
}

// CategoryMembers lists the main-namespace pages in a category.
func CategoryMembers(ctx context.Context, client *mediawiki.Client, category string) ([]string, error) {
	var titles []string
	cont := url.Values{}
	for {
		form := url.Values{
			"action": {"query"}, "list": {"categorymembers"}, "cmtitle": {"Category:" + category},
			"cmnamespace": {"0"}, "cmtype": {"page"}, "cmlimit": {"max"}, "format": {"json"}, "formatversion": {"2"},
		}
		for k, v := range cont {
			form[k] = v
		}
		var res struct {
			mediawiki.Response
			Continue map[string]string `json:"continue"`
			Query    struct {
				Members []struct {
					Title string `json:"title"`
				} `json:"categorymembers"`
			} `json:"query"`
		}
		if err := client.Request(ctx, form, &res); err != nil {
			return nil, err
		}
		for _, m := range res.Query.Members {
			titles = append(titles, m.Title)
		}
		if len(res.Continue) == 0 {
			return titles, nil
		}
		cont = url.Values{}
		for k, v := range res.Continue {
			cont.Set(k, v)
		}
	}
}

// FileBySHA1 returns the title, without "File:", of a file whose content has
// this SHA1, or "" when the wiki has none.
func FileBySHA1(ctx context.Context, client *mediawiki.Client, sha1 string) (string, error) {
	form := url.Values{"action": {"query"}, "list": {"allimages"}, "aisha1": {sha1}, "ailimit": {"1"}, "format": {"json"}, "formatversion": {"2"}}
	var res struct {
		mediawiki.Response
		Query struct {
			AllImages []struct {
				Title string `json:"title"`
			} `json:"allimages"`
		} `json:"query"`
	}
	if err := client.Request(ctx, form, &res); err != nil {
		return "", err
	}
	if len(res.Query.AllImages) == 0 {
		return "", nil
	}
	return strings.TrimPrefix(res.Query.AllImages[0].Title, "File:"), nil
}
