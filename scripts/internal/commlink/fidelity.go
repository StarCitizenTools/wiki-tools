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

// extractCaptions finds all [[File:...]] blocks and extracts their captions.
// A caption is the text after the last pipe (|) in the File link.
func extractCaptions(page string) []string {
	filePattern := regexp.MustCompile(`\[\[File:([^\]]*)\]\]`)
	matches := filePattern.FindAllStringSubmatch(page, -1)
	var captions []string
	for _, match := range matches {
		if len(match) > 1 {
			content := match[1]
			lastPipe := strings.LastIndex(content, "|")
			if lastPipe >= 0 {
				caption := content[lastPipe+1:]
				captions = append(captions, caption)
			}
		}
	}
	return captions
}

// Missing lists the lines of the API's plain text that the page does not
// contain. The check runs one way, API into page, so an API text RSI truncated
// (17080, 17105) cannot fail it.
func Missing(apiText, page string, ignored func(string) bool) []string {
	have := normalize(page)

	captions := extractCaptions(page)
	captionWords := make([]map[string]bool, len(captions))
	for i, caption := range captions {
		normalizedCaption := normalize(caption)
		captionWords[i] = make(map[string]bool)
		for _, w := range strings.Fields(normalizedCaption) {
			captionWords[i][w] = true
		}
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
		if fields := strings.Fields(n); len(fields) <= 6 && isInAnyCaption(fields, captionWords) {
			continue
		}
		missing = append(missing, line)
	}
	return missing
}

func isInAnyCaption(fields []string, captionWords []map[string]bool) bool {
	for _, words := range captionWords {
		if allIn(fields, words) {
			return true
		}
	}
	return false
}

func allIn(fields []string, words map[string]bool) bool {
	for _, f := range fields {
		if !words[f] {
			return false
		}
	}
	return true
}
