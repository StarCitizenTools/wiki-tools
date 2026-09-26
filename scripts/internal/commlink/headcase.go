package commlink

import (
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"
)

var headWord = regexp.MustCompile(`\pL[\pL\pN'’]*(?:&\pL[\pL\pN'’]*)*`)

// HeadCaser recases headings RSI wrote in capitals (classic studio and
// department titles are upper case in the HTML itself, not through CSS).
type HeadCaser struct {
	labels   map[string]string // lower-case label -> the casing the corpus uses
	proper   map[string]string // lower-case word -> its capitalised mid-sentence form
	acronyms map[string]bool   // upper-case words the corpus writes in capitals mid-sentence
}

// NewHeadCaser learns labels from the non-shouted headings and word casing from
// the reports' text.
func NewHeadCaser(headings []string, corpus string) *HeadCaser {
	h := &HeadCaser{labels: map[string]string{}, proper: map[string]string{}, acronyms: map[string]bool{}}
	forms := map[string]map[string]int{}
	for _, t := range headings {
		if shouted(t) {
			continue
		}
		l := strings.ToLower(t)
		if forms[l] == nil {
			forms[l] = map[string]int{}
		}
		forms[l][t]++
	}
	for l, f := range forms {
		best, n := "", 0
		for form, c := range f {
			if c > n || (c == n && form < best) {
				best, n = form, c
			}
		}
		h.labels[l] = best
	}

	stats := map[string]*wordCounts{}
	for _, line := range strings.Split(corpus, "\n") {
		// A line in capitals is a heading; its capitals say nothing about
		// how the text writes a word.
		if !shouted(line) {
			learnLine(line, stats)
		}
	}
	for l, c := range stats {
		if (c.upper > 0 && c.upper >= c.capital+c.lower) || (c.isolated >= minIsolated && c.isolated > c.capital) {
			h.acronyms[strings.ToUpper(l)] = true
		}
		if c.capital > 0 && c.capital > c.lower && c.capital >= c.upper {
			h.proper[l] = c.capForm
		}
	}
	return h
}

// wordCounts tallies how the text writes one word away from a sentence start.
// isolated counts the upper-case uses between words that are not upper case.
type wordCounts struct {
	lower, capital, upper, isolated int
	capForm                         string
}

// minIsolated is how often a word must stand alone in capitals to count as an
// acronym when the same letters are also a lower-case word (IT beside it); a
// word capitalised for emphasis (AND) stays below it.
const minIsolated = 5

func learnLine(line string, stats map[string]*wordCounts) {
	spans := headWord.FindAllStringIndex(line, -1)
	upperAt := func(i int) bool {
		if i < 0 || i >= len(spans) {
			return false
		}
		w := line[spans[i][0]:spans[i][1]]
		return w == strings.ToUpper(w) && w != strings.ToLower(w) && utf8.RuneCountInString(w) > 1
	}
	for i, m := range spans {
		if sentenceStart(line, m[0]) {
			continue
		}
		w := line[m[0]:m[1]]
		key := foldWord(w)
		c := stats[key]
		if c == nil {
			c = &wordCounts{}
			stats[key] = c
		}
		switch {
		case w == strings.ToLower(w):
			c.lower++
		case upperAt(i):
			// A lone upper-case letter reads the same regardless of the
			// corpus's sentence case, so it is not evidence of an acronym.
			c.upper++
			if !upperAt(i-1) && !upperAt(i+1) {
				c.isolated++
			}
		default:
			r, _ := utf8.DecodeRuneInString(w)
			if unicode.IsUpper(r) {
				c.capital++
				c.capForm = w
			}
		}
	}
}

// Case returns heading unchanged unless it is shouted (letters, none lower
// case); a shouted heading takes the corpus's casing for that label, else stays
// as it is when every word is an acronym, else becomes sentence case with
// acronyms and proper nouns restored.
func (h *HeadCaser) Case(heading string) string {
	if !shouted(heading) {
		return heading
	}
	if l, ok := h.labels[strings.ToLower(heading)]; ok {
		return l
	}
	words := headWord.FindAllString(heading, -1)
	all := len(words) > 0
	for _, w := range words {
		if !h.acronyms[dequoteWord(w)] {
			all = false
			break
		}
	}
	if all {
		return heading
	}
	first := true
	return headWord.ReplaceAllStringFunc(heading, func(w string) string {
		l := foldWord(w)
		out := l
		switch {
		case strings.Contains(w, "&"):
			// A letter joined by & (Q&A, R&D) is an abbreviation, not a
			// sentence-case word; keep it exactly as RSI wrote it.
			out = w
		case h.acronyms[dequoteWord(w)]:
			out = w
		case h.proper[l] != "":
			out = h.proper[l]
		}
		if first {
			first = false
			r, size := utf8.DecodeRuneInString(out)
			out = string(unicode.ToUpper(r)) + out[size:]
		}
		return out
	})
}

// dequoteWord maps a typographic apostrophe to the straight form, so a word
// learned under one spelling matches a heading spelled with the other.
func dequoteWord(w string) string {
	return strings.ReplaceAll(w, "’", "'")
}

// foldWord is dequoteWord lower-cased, used as the map key for a learned word
// (case varies; the apostrophe glyph is incidental to which word it is).
func foldWord(w string) string {
	return strings.ToLower(dequoteWord(w))
}

func shouted(s string) bool {
	letters := 0
	for _, r := range s {
		if unicode.IsLetter(r) {
			if unicode.IsLower(r) {
				return false
			}
			letters++
		}
	}
	return letters >= 2
}

// sentenceStart reports whether the word starting at byte offset i begins a
// sentence: nothing but spaces, quote or bracket marks, and dashes lie between
// it and the text's start or a sentence-ending mark. It decodes runes, not
// bytes, so a multi-byte typographic quote next to the boundary is not
// mistaken for ordinary text.
func sentenceStart(s string, i int) bool {
	for i > 0 {
		r, size := utf8.DecodeLastRuneInString(s[:i])
		switch r {
		case ' ', '\t', '"', '\'', '“', '”', '‘', '’', '«', '»', '(', ')', '[', ']', '–', '—':
			i -= size
		case '.', '!', '?', ':', '…', '\n':
			return true
		default:
			return false
		}
	}
	return true
}
