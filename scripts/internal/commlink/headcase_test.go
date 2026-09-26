package commlink

import "testing"

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
	} {
		if got := h.Case(in); got != want {
			t.Errorf("Case(%q) = %q, want %q", in, got, want)
		}
	}
}
