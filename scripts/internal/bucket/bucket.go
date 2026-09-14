// Package bucket reads rows from the Bucket extension through action=bucket.
//
// It is its own package because the API has two behaviours every caller would
// otherwise have to rediscover: it reports errors as a bare string rather than
// the action API's {code, info} object, and its per-user rate limiter answers
// with an empty envelope that a paging loop reads as the end of the bucket.
package bucket

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/url"
	"os"
	"time"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/mediawiki"
)

// PageSize is the largest number of rows one Bucket query returns, and so the
// step a full walk of a bucket has to take.
const PageSize = 5000

// apiError is the error the Bucket API reports in its response body. Unlike
// the rest of the action API, which sends `{"code", "info"}`, Bucket sends
// `error` as a bare string; this decodes either shape so the message shown is
// always the server's own text rather than a JSON-decode complaint.
type apiError struct {
	text string
}

func (e *apiError) Error() string { return e.text }

func (e *apiError) UnmarshalJSON(data []byte) error {
	var s string
	if err := json.Unmarshal(data, &s); err == nil {
		e.text = s
		return nil
	}
	var obj struct {
		Code string `json:"code"`
		Info string `json:"info"`
	}
	if err := json.Unmarshal(data, &obj); err != nil {
		return fmt.Errorf("bucket error: unrecognised shape %s", string(data))
	}
	if obj.Info != "" {
		e.text = obj.Info
	} else {
		e.text = obj.Code
	}
	return nil
}

type response struct {
	mediawiki.Response
	// Shadows the embedded Response.Error (see apiError); encoding/json
	// resolves the JSON name conflict in favour of the shallower field, so this
	// one is populated and mediawiki.Response's own Error stays nil.
	Error *apiError `json:"error"`
	// BucketQuery echoes the query back; the rate limiter's envelope carries
	// neither it nor a bucket array. A page that legitimately matched nothing
	// still carries "bucket": [], which leaves Bucket non-nil.
	BucketQuery string           `json:"bucketQuery"`
	Bucket      []map[string]any `json:"bucket"`
}

// served reports whether a response came from the query rather than from the
// rate limiter. Either marker is enough: `{}` has neither.
func (r *response) served() bool { return r.BucketQuery != "" || r.Bucket != nil }

// backoff is the wait before each retry of one throttled page. The Bucket
// API's per-user limiter (BucketApi.php, pingLimiter('bucketapi', 1) then a
// bare return) answers with `{}`: HTTP 200, no error, no query echo, no rows,
// which the paging loop would otherwise read as the end of the bucket.
var backoff = []time.Duration{
	5 * time.Second,
	10 * time.Second,
	20 * time.Second,
	40 * time.Second,
	60 * time.Second,
	60 * time.Second,
}

// sleep is a variable so tests do not wait out backoff.
var sleep = time.Sleep

// warn is a variable so tests can capture the rate-limit notice instead of
// writing to the process's real stderr. A run against the whole corpus that
// hits the limiter would otherwise look like a silent multi-minute hang.
var warn io.Writer = os.Stderr

// fetchPage reads one page of a bucket, retrying the same query while the API
// answers with the rate limiter's empty envelope. The second return counts API
// requests, retries included.
func fetchPage(ctx context.Context, c *mediawiki.Client, name, query string, offset int) ([]map[string]any, int, error) {
	// formatversion=2 so a BOOLEAN column arrives as a JSON boolean rather than
	// as "" for true and nothing at all for false.
	form := url.Values{"action": {"bucket"}, "format": {"json"}, "formatversion": {"2"}, "query": {query}}
	for try := 0; ; try++ {
		var res response
		if err := c.Request(ctx, form, &res); err != nil {
			return nil, try + 1, err
		}
		if res.Error != nil {
			return nil, try + 1, fmt.Errorf("bucket %q offset %d: %w", name, offset, res.Error)
		}
		if res.served() {
			return res.Bucket, try + 1, nil
		}
		if try >= len(backoff) {
			return nil, try + 1, fmt.Errorf("bucket %q offset %d: rate limited, no query echo in %d attempts", name, offset, try+1)
		}
		d := backoff[try]
		fmt.Fprintf(warn, "bucket: rate limited, retrying in %s\n", d)
		sleep(d)
	}
}

// Rows reads every row a query selects, walking in PageSize-row pages until a
// short page ends the walk. query composes the query text for one offset; name
// labels the bucket in error messages. The second return counts API requests,
// retries included.
func Rows(ctx context.Context, c *mediawiki.Client, name string, query func(offset int) string) ([]map[string]any, int, error) {
	var out []map[string]any
	requests := 0
	for offset := 0; ; offset += PageSize {
		rows, n, err := fetchPage(ctx, c, name, query(offset), offset)
		requests += n
		if err != nil {
			return nil, requests, err
		}
		out = append(out, rows...)
		if len(rows) < PageSize {
			return out, requests, nil
		}
	}
}
