package commlink

import (
	stdhtml "html"
	"regexp"
	"strings"
)

// links leaves a template call's text in place for nonWord to fold: the
// infobox title is the page's only copy of the report title, which the API
// repeats as lines of its own (a fragment introduction's title and subtitle).
// Tags go first, since a link's text can hold one (<u>).
var (
	tags    = regexp.MustCompile(`<[^>]+>|'{2,}|={2,}`)
	links   = regexp.MustCompile(`\[\[(?:[^|\]]*\|)?([^\]]*)\]\]|\[[a-z]+://\S+ ([^\]]*)\]`)
	nonWord = regexp.MustCompile(`[^\pL\pN]+`)
)

// normalize folds text to its lower-case words, each followed by one space and
// the first preceded by one.
func normalize(s string) string {
	s = stdhtml.UnescapeString(s)
	s = tags.ReplaceAllString(s, " ")
	s = links.ReplaceAllString(s, " $1$2 ")
	s = nonWord.ReplaceAllString(strings.ToLower(s), " ")
	return " " + strings.TrimSpace(s) + " "
}

// thumbCaption matches a captioned image line; the caption may hold one
// external link.
var thumbCaption = regexp.MustCompile(`(?m)^\[\[File:[^|\]]*\|thumb\|center\|((?:[^\[\]]|\[[^\[\]]*\])*)\]\]$`)

// creditParts lists, spaces removed, every word-boundary prefix and suffix of
// each image caption: the pieces of an intro-and-name credit the API glues
// together in its own order.
func creditParts(page string) []string {
	var parts []string
	for _, m := range thumbCaption.FindAllStringSubmatch(page, -1) {
		words := strings.Fields(normalize(m[1]))
		for i := 1; i <= len(words); i++ {
			parts = append(parts, strings.Join(words[:i], ""), strings.Join(words[len(words)-i:], ""))
		}
	}
	return parts
}

// tiles reports whether s is a concatenation of parts.
func tiles(s string, parts []string) bool {
	if s == "" || len(parts) == 0 {
		return false
	}
	reach := make([]bool, len(s)+1)
	reach[0] = true
	for i := 0; i < len(s); i++ {
		if !reach[i] {
			continue
		}
		for _, p := range parts {
			if p != "" && strings.HasPrefix(s[i:], p) {
				reach[i+len(p)] = true
			}
		}
	}
	return reach[len(s)]
}

// minGlueHead is the fewest words the opening piece of a glued line may have,
// so a dropped short heading cannot pass on one-word block edges.
const minGlueHead = 2

// spansBlocks reports whether a normalized line runs across the page's blocks
// in page order: it opens with the end of one block (at least minGlueHead
// words), may pass through whole later blocks, and closes with the start of a
// later one. Each piece is on the page, aligned to a block edge, so only the
// blocks' adjacency goes unchecked.
func spansBlocks(n string, blocks []string) bool {
	// n is " w1 w2 ... wk "; cut[i] is the space after word i, so n[:cut[i]+1]
	// holds words 1..i and n[cut[i]:] the rest, each with its outer spaces.
	var cut []int
	at := map[int]int{}
	for i := 0; i < len(n); i++ {
		if n[i] == ' ' {
			at[i] = len(cut)
			cut = append(cut, i)
		}
	}
	words := len(cut) - 1
	// from[i] is the earliest block the pieces covering words 1..i can end in.
	from := make([]int, words+1)
	for i := range from {
		from[i] = -1
		if i < minGlueHead || i == words {
			continue
		}
		for bi, b := range blocks {
			if strings.HasSuffix(b, n[:cut[i]+1]) {
				from[i] = bi
				break
			}
		}
	}
	for i := 1; i < words; i++ {
		if from[i] < 0 {
			continue
		}
		rest := n[cut[i]:]
		for bi := from[i] + 1; bi < len(blocks); bi++ {
			b := blocks[bi]
			if strings.HasPrefix(b, rest) {
				return true
			}
			if strings.HasPrefix(rest, b) {
				if j := at[cut[i]+len(b)-1]; from[j] < 0 || bi < from[j] {
					from[j] = bi
				}
			}
		}
	}
	return false
}

// mediaLine is a file line or a template call (a video embed): no body words.
var mediaLine = regexp.MustCompile(`(?m)^(?:\[\[File:|\{\{).*$`)

// APITextWords counts the words of the API text and of the page body, leaving
// out the body's media lines. short is true when the API text has fewer than
// half as many: the API has not finished scraping the report, so its lines
// check only part of the page. Empty API text is the limiting case.
func APITextWords(apiText, body string) (api, page int, short bool) {
	api = len(strings.Fields(normalize(apiText)))
	page = len(strings.Fields(normalize(mediaLine.ReplaceAllString(body, ""))))
	return api, page, 2*api < page
}

// Missing lists the lines of the API's plain text that the page does not
// contain. The check runs one way, API into page, so an API text that stops
// short of RSI's body cannot fail it. Two API artefacts pass: a line glued
// across page blocks, and illustration credits glued together.
func Missing(apiText, page string, ignored func(string) bool) []string {
	have := normalize(page)
	var blocks []string
	for _, b := range strings.Split(page, "\n\n") {
		if nb := normalize(b); strings.TrimSpace(nb) != "" {
			blocks = append(blocks, nb)
		}
	}
	credits := creditParts(page)

	var missing []string
	for _, line := range strings.Split(apiText, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || ignored(line) {
			continue
		}
		n := normalize(line)
		if strings.TrimSpace(n) == "" || strings.Contains(have, n) || spansBlocks(n, blocks) ||
			tiles(strings.ReplaceAll(n, " ", ""), credits) {
			continue
		}
		missing = append(missing, line)
	}
	return missing
}
