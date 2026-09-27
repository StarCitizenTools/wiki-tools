package commlink

import (
	"strings"
	"testing"
)

func TestTitleProblem(t *testing.T) {
	for _, name := range []string{
		"Q&A - Aegis Sabre Raven EX and Argo ATLS IKTI Akuma",
		"Round Table - Art – Part 1",
		"Orion Vault - A Loan in the 'Verse",
		"Test Drive the Origin Jumpworks 300 Series! - 2015-02-13",
		"Letter from the Chairman - $23 Million!",
		"100% Fun",
		"Q&A - AT&T",
		"Scene 1/2",
		"Ng.at’ak Syulen",
	} {
		if p := TitleProblem(name); p != "" {
			t.Errorf("TitleProblem(%q) = %q, want none", name, p)
		}
	}
	for name, want := range map[string]string{
		"": "empty",
		"DefenseCon 2956 Ship Q&A | Star Citizen": `"|"`,
		"Issue #3":               `"#"`,
		"A <b>bold</b> name":     `"<"`,
		"[Redacted]":             `"["`,
		"{Name}":                 `"{"`,
		"Tab\there":              "U+0009",
		"Mark‏here":              "U+200F",
		"50%25 off":              `"%25"`,
		"Fish &amp; Chips":       `"&amp;"`,
		"Sign ~~~":               "tildes",
		"../Up":                  "relative path",
		"A/./B":                  "relative path",
		":Leading":               "colon",
		strings.Repeat("x", 256): "256 bytes",
		"Bad \xff byte":          "UTF-8",
	} {
		if p := TitleProblem(name); !strings.Contains(p, want) {
			t.Errorf("TitleProblem(%q) = %q, want one naming %s", name, p, want)
		}
	}
}
