package commlink

import (
	"regexp"
	"sort"
	"strings"
	"unicode/utf8"
)

// LinkEntry records one link the importer added.
type LinkEntry struct {
	Section string `json:"section"`
	Term    string `json:"term"`
	Target  string `json:"target"`
}

type term struct {
	text, target string
	re           *regexp.Regexp
}

// Vocabulary is the set of names the importer may link.
type Vocabulary struct{ terms []term }

var corpusWord = regexp.MustCompile(`\pL[\pL\pN'’-]*`)

// BuildVocabulary turns page titles and curated aliases into link terms. A title
// is dropped when it is a disambiguation page, is stoplisted, carries a
// parenthetical, is under four characters, or is a single word the reports also
// use in lower case (so "reliant" or "javelin" is read as a word, not a ship).
// Aliases are curated and skip those checks.
func BuildVocabulary(titles []string, aliases map[string]string, disambiguation, stoplist []string, corpus string) *Vocabulary {
	skip := map[string]bool{}
	for _, t := range append(append([]string{}, disambiguation...), stoplist...) {
		skip[t] = true
	}
	lowerWords := map[string]bool{}
	for _, w := range corpusWord.FindAllString(corpus, -1) {
		if w == strings.ToLower(w) {
			lowerWords[w] = true
		}
	}
	v := &Vocabulary{}
	seen := map[string]bool{}
	add := func(text, target string) {
		seen[text] = true
		v.terms = append(v.terms, term{text: text, target: target,
			re: regexp.MustCompile(`(?:^|[^\pL\pN])(` + regexp.QuoteMeta(text) + `)(?:$|[^\pL\pN])`)})
	}
	for _, t := range titles {
		if seen[t] || skip[t] || strings.ContainsAny(t, "()") || utf8.RuneCountInString(t) < 4 {
			continue
		}
		if !strings.Contains(t, " ") && lowerWords[strings.ToLower(t)] {
			continue
		}
		add(t, t)
	}
	keys := make([]string, 0, len(aliases))
	for k := range aliases {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		if !seen[k] {
			add(k, aliases[k])
		}
	}
	sort.SliceStable(v.terms, func(i, j int) bool {
		if len(v.terms[i].text) != len(v.terms[j].text) {
			return len(v.terms[i].text) > len(v.terms[j].text)
		}
		return v.terms[i].text < v.terms[j].text
	})
	return v
}

var (
	sectionLine = regexp.MustCompile(`(?m)^==[^=].*==[ \t]*$`)
	// protected spans: a file line, a heading line, internal and external links,
	// templates and tags.
	protected = regexp.MustCompile(`(?m)^\[\[File:.*$|^=.*=[ \t]*$|\[\[[^\]]*\]\]|\[[a-z]+://[^\]]*\]|\{\{[^}]*\}\}|<[^>]*>`)
)

// Apply links the first mention of each term in every == section of body (the
// lead counts as one).
func (v *Vocabulary) Apply(body string) (string, []LinkEntry) {
	starts := []int{0}
	for _, m := range sectionLine.FindAllStringIndex(body, -1) {
		if m[0] > 0 {
			starts = append(starts, m[0])
		}
	}
	var out strings.Builder
	var links []LinkEntry
	for i, s := range starts {
		e := len(body)
		if i+1 < len(starts) {
			e = starts[i+1]
		}
		chunk := body[s:e]
		name := ""
		if h := sectionLine.FindString(chunk); h != "" && strings.HasPrefix(chunk, h) {
			name = strings.Trim(strings.TrimSpace(h), "= ")
		}
		chunk, added := v.linkSection(chunk)
		for _, a := range added {
			a.Section = name
			links = append(links, a)
		}
		out.WriteString(chunk)
	}
	return out.String(), links
}

func (v *Vocabulary) linkSection(s string) (string, []LinkEntry) {
	var added []LinkEntry
	for _, t := range v.terms {
		spans := protected.FindAllStringIndex(s, -1)
		for _, m := range t.re.FindAllStringSubmatchIndex(s, -1) {
			start, end := m[2], m[3]
			if inSpan(spans, start, end) {
				continue
			}
			link := "[[" + t.target + "|" + s[start:end] + "]]"
			if t.target == s[start:end] {
				link = "[[" + t.target + "]]"
			}
			s = s[:start] + link + s[end:]
			added = append(added, LinkEntry{Term: t.text, Target: t.target})
			break
		}
	}
	return s, added
}

func inSpan(spans [][]int, start, end int) bool {
	for _, sp := range spans {
		if start < sp[1] && end > sp[0] {
			return true
		}
	}
	return false
}
