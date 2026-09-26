package commlink

import (
	"fmt"
	"strings"
	"testing"
)

func TestVocabulary(t *testing.T) {
	corpus := "The javelin was thrown. Jeffrey Pease and the Gladius team met in Los Angeles."
	v := BuildVocabulary(
		[]string{"Jeffrey Pease", "Gladius", "Javelin", "Idris (disambiguation)", "Nova", "M50", "Banned Ship"},
		map[string]string{"Los Angeles": "Cloud Imperium Games, LLC"},
		[]string{"Nova"},
		[]string{"Banned Ship"},
		corpus)
	body := "Intro about Gladius and Jeffrey Pease, and Nova and Banned Ship.\n\n" +
		"== Team ==\n\n" +
		"The Gladius flew. The Gladius again. Javelin news. Jeffrey Pease in Los Angeles.\n\n" +
		"[[File:X.jpg|thumb|center|Gladius photo]]\n\n" +
		"[https://x Gladius link] {{#ev:youtube|Gladius}}\n\n" +
		"== Gladius work ==\n\n" +
		"'''Gladius''' text."
	got, links := v.Apply(body)
	want := "Intro about [[Gladius]] and [[Jeffrey Pease]], and Nova and Banned Ship.\n\n" +
		"== Team ==\n\n" +
		"The [[Gladius]] flew. The Gladius again. Javelin news. [[Jeffrey Pease]] in [[Cloud Imperium Games, LLC|Los Angeles]].\n\n" +
		"[[File:X.jpg|thumb|center|Gladius photo]]\n\n" +
		"[https://x Gladius link] {{#ev:youtube|Gladius}}\n\n" +
		"== Gladius work ==\n\n" +
		"'''[[Gladius]]''' text."
	if got != want {
		t.Errorf("Apply:\n%s\nwant:\n%s", got, want)
	}
	if len(links) != 6 || links[0].Section != "" || links[2].Section != "Team" || links[5].Section != "Gladius work" {
		t.Errorf("links = %+v", links)
	}
}

// A hyphen keeps a term from matching a prefix of a distinct name ("Idris-M");
// an apostrophe still ends a term, so a possessive links the bare name.
func TestTermBoundaryHyphenApostrophe(t *testing.T) {
	v := BuildVocabulary([]string{"Idris"}, nil, nil, nil, "")
	body := "The Idris-M arrived. The Idris’s hangar."
	got, links := v.Apply(body)
	want := "The Idris-M arrived. The [[Idris]]’s hangar."
	if got != want {
		t.Errorf("Apply:\n%s\nwant:\n%s", got, want)
	}
	if len(links) != 1 {
		t.Errorf("links = %+v", links)
	}
}

// The corpus tokenizer must split off a trailing possessive so a bare
// lower-case word ("reliant") is recorded and its title dropped.
func TestLowerCaseWordExclusionHandlesPossessive(t *testing.T) {
	v := BuildVocabulary([]string{"Reliant"}, nil, nil, nil, "the reliant's cargo bay was full")
	got, links := v.Apply("The Reliant flew.")
	want := "The Reliant flew."
	if got != want {
		t.Errorf("Apply:\n%s\nwant:\n%s", got, want)
	}
	if len(links) != 0 {
		t.Errorf("links = %+v", links)
	}
}

// benchmarkData builds 1,000 synthetic terms and a ~30KB, 10-section body:
// most terms never appear in a given section (exercising the Contains
// short-circuit), and a handful do (exercising an actual replacement).
func benchmarkData() (*Vocabulary, string) {
	titles := make([]string, 1000)
	for i := range titles {
		titles[i] = fmt.Sprintf("Synthetic Term %04d", i)
	}
	v := BuildVocabulary(titles, nil, nil, nil, "")

	const filler = "The quick brown fox jumps over the lazy dog near the old station platform, and the crew filed a routine report. "
	var body strings.Builder
	fmt.Fprintf(&body, "Intro mentioning %s near the start.\n\n", titles[1])
	for section := 1; section <= 9; section++ {
		fmt.Fprintf(&body, "== Section %d ==\n\n", section)
		start := body.Len()
		for body.Len()-start < 3000 {
			body.WriteString(filler)
		}
		fmt.Fprintf(&body, "%s makes another appearance here.\n\n", titles[section*100])
	}
	return v, body.String()
}

func BenchmarkApply(b *testing.B) {
	v, body := benchmarkData()
	b.SetBytes(int64(len(body)))
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		v.Apply(body)
	}
}

// A term never links inside a longer term's mention, linked or not: the
// section's second "Hurston Dynamics" is not the planet.
func TestTermInsideLongerTerm(t *testing.T) {
	v := BuildVocabulary([]string{"Hurston"}, map[string]string{"Hurston Dynamics": "Hurston Dynamics"}, nil, nil, "")
	got, links := v.Apply("The Hurston Dynamics gun. Then Hurston Dynamics again, and Hurston itself.")
	want := "The [[Hurston Dynamics]] gun. Then Hurston Dynamics again, and [[Hurston]] itself."
	if got != want {
		t.Errorf("Apply:\n%s\nwant:\n%s", got, want)
	}
	if len(links) != 2 {
		t.Errorf("links = %+v", links)
	}
}
