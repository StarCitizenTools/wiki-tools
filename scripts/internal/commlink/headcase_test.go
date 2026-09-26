package commlink

import (
	"strings"
	"testing"
)

func TestHeadCaser(t *testing.T) {
	corpus := "The AI team in Los Angeles met. Then VFX and the QA group worked with CIG staff in Los Angeles."
	h := NewHeadCaser([]string{"AI (Content)"}, corpus)
	for in, want := range map[string]string{
		"ENGINEERING":     "Engineering",
		"CIG LOS ANGELES": "CIG Los Angeles",
		"AI (CONTENT)":    "AI (Content)",
		"VFX":             "VFX",
		"TECH CONTENT":    "Tech content",
		"Tech Content":    "Tech Content",
		"THEN":            "Then",
		"Q&A":             "Q&A",
		"R&D UPDATE":      "R&D update",
	} {
		if got := h.Case(in); got != want {
			t.Errorf("Case(%q) = %q, want %q", in, got, want)
		}
	}
}

// TestHeadCaserApostrophe covers a proper noun learned from a corpus that
// spells its possessive with a typographic apostrophe, looked up from a
// heading that spells the same word with a straight one.
func TestHeadCaserApostrophe(t *testing.T) {
	corpus := "The CIG’s plan held."
	h := NewHeadCaser(nil, corpus)
	if got, want := h.Case("CIG'S PLAN"), "CIG’s plan"; got != want {
		t.Errorf("Case(%q) = %q, want %q", "CIG'S PLAN", got, want)
	}
}

// TestSentenceStart covers the rune-boundary case: a multi-byte typographic
// quote sits between a sentence-ending period and the next word.
func TestSentenceStart(t *testing.T) {
	corpus := `He said “We shipped it.” CIG announced more. The CIG team met.`
	quoted := strings.Index(corpus, "CIG")
	if !sentenceStart(corpus, quoted) {
		t.Errorf("sentenceStart at %d (after closing curly quote) = false, want true", quoted)
	}
	midSentence := strings.LastIndex(corpus, "CIG")
	if sentenceStart(corpus, midSentence) {
		t.Errorf("sentenceStart at %d (mid-sentence) = true, want false", midSentence)
	}

	h := NewHeadCaser(nil, corpus)
	if got, want := h.Case("CIG"), "CIG"; got != want {
		t.Errorf("Case(%q) = %q, want %q", "CIG", got, want)
	}
}

// A line in capitals is a heading, not evidence of how the text writes its
// words: the API text carries every shouted studio and team title.
func TestHeadCaserIgnoresShoutedLines(t *testing.T) {
	corpus := "CIG COMMUNICATIONS\nThe CIG communications team met.\nCIG COMMUNICATIONS\n"
	h := NewHeadCaser(nil, corpus)
	if got, want := h.Case("CIG COMMUNICATIONS"), "CIG communications"; got != want {
		t.Errorf("Case(%q) = %q, want %q", "CIG COMMUNICATIONS", got, want)
	}
}

// IT is an acronym the text writes in capitals on its own, though the same
// letters as a lower-case word far outnumber it; a word capitalised only for
// emphasis a few times is not.
func TestHeadCaserAcronymAmongLowerCase(t *testing.T) {
	corpus := strings.Repeat("It said it was done, and it was. ", 20) +
		"The IT team met. We asked IT for help. Then IT staff left. The DevOps and IT teams met. Ask IT now. " +
		"A demo AND a release. Maps AND more. Ships AND more."
	h := NewHeadCaser(nil, corpus)
	for in, want := range map[string]string{
		"DEVOPS & IT":    "DevOps & IT",
		"SHIPS AND MAPS": "Ships and maps",
	} {
		if got := h.Case(in); got != want {
			t.Errorf("Case(%q) = %q, want %q", in, got, want)
		}
	}
}
