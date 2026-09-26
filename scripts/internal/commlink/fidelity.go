package commlink

import (
	stdhtml "html"
	"regexp"
	"strings"
)

var (
	markup  = regexp.MustCompile(`\[\[(?:[^|\]]*\|)?([^\]]*)\]\]|\[[a-z]+://\S+ ([^\]]*)\]|\{\{[^}]*\}\}|<[^>]+>|'{2,}|={2,}`)
	nonWord = regexp.MustCompile(`[^\pL\pN]+`)
)

func normalize(s string) string {
	s = stdhtml.UnescapeString(s)
	s = markup.ReplaceAllString(s, " $1$2 ")
	s = nonWord.ReplaceAllString(strings.ToLower(s), " ")
	return " " + strings.TrimSpace(s) + " "
}

// Missing lists the lines of the API's plain text that the page does not
// contain. The check runs one way, API into page, so an API text RSI truncated
// (17080, 17105) cannot fail it.
func Missing(apiText, page string, ignored func(string) bool) []string {
	have := normalize(page)
	words := map[string]bool{}
	for _, w := range strings.Fields(have) {
		words[w] = true
	}
	var missing []string
	for _, line := range strings.Split(apiText, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || ignored(line) {
			continue
		}
		n := normalize(line)
		if strings.TrimSpace(n) == "" || strings.Contains(have, n) {
			continue
		}
		if fields := strings.Fields(n); len(fields) <= 6 && allIn(fields, words) {
			continue // a short credit the API prints in another order
		}
		missing = append(missing, line)
	}
	return missing
}

func allIn(fields []string, words map[string]bool) bool {
	for _, f := range fields {
		if !words[f] {
			return false
		}
	}
	return true
}
