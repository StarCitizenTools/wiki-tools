package commlink

import (
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"
)

var headWord = regexp.MustCompile(`\pL[\pL\pN'’]*`)

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

	type counts struct {
		lower, capital, upper int
		capForm               string
	}
	stats := map[string]*counts{}
	for _, m := range headWord.FindAllStringIndex(corpus, -1) {
		if sentenceStart(corpus, m[0]) {
			continue
		}
		w := corpus[m[0]:m[1]]
		l := strings.ToLower(w)
		c := stats[l]
		if c == nil {
			c = &counts{}
			stats[l] = c
		}
		switch {
		case w == l:
			c.lower++
		case w == strings.ToUpper(w) && utf8.RuneCountInString(w) > 1:
			c.upper++
		default:
			r, _ := utf8.DecodeRuneInString(w)
			if unicode.IsUpper(r) {
				c.capital++
				c.capForm = w
			}
		}
	}
	for l, c := range stats {
		if c.upper > 0 && c.upper >= c.capital+c.lower {
			h.acronyms[strings.ToUpper(l)] = true
		}
		if c.capital > 0 && c.capital > c.lower && c.capital >= c.upper {
			h.proper[l] = c.capForm
		}
	}
	return h
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
		if !h.acronyms[w] {
			all = false
			break
		}
	}
	if all {
		return heading
	}
	first := true
	return headWord.ReplaceAllStringFunc(heading, func(w string) string {
		l := strings.ToLower(w)
		out := l
		switch {
		case h.acronyms[w]:
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

// sentenceStart reports whether the word at i begins a sentence: nothing but
// spaces and quotes lie between it and the text's start or a . ! ? : or newline.
func sentenceStart(s string, i int) bool {
	for j := i - 1; j >= 0; j-- {
		switch s[j] {
		case ' ', '\t', '"', '\'':
			continue
		case '.', '!', '?', ':', '\n':
			return true
		default:
			return false
		}
	}
	return true
}
