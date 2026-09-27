package commlink

import "testing"

func TestVocabulary(t *testing.T) {
	corpus := "The javelin was thrown. Jeffrey Pease and the Gladius team met in Los Angeles."
	v := BuildVocabulary(
		[]string{"Jeffrey Pease", "Gladius", "Javelin", "Idris (disambiguation)", "Nova", "M50", "Banned Ship"},
		map[string]string{"Los Angeles": "Cloud Imperium Games, LLC"},
		[]string{"Nova"},
		[]string{"Banned Ship"},
		nil,
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

// Each case links one vocabulary into one line.
func TestApply(t *testing.T) {
	for _, c := range []struct {
		name           string
		titles, noLink []string
		aliases        map[string]string
		corpus         string
		body, want     string
		links          int
	}{
		{
			// A hyphen keeps a term from matching a prefix of a distinct name
			// (Idris-M); an apostrophe still ends a term, so a possessive links
			// the bare name.
			name: "hyphen and apostrophe boundaries", titles: []string{"Idris"},
			body:  "The Idris-M arrived. The Idris’s hangar.",
			want:  "The Idris-M arrived. The [[Idris]]’s hangar.",
			links: 1,
		},
		{
			// The corpus tokenizer splits off a trailing possessive, so a bare
			// lower-case word is recorded and its title dropped.
			name: "lower-case word behind a possessive", titles: []string{"Reliant"},
			corpus: "the reliant's cargo bay was full",
			body:   "The Reliant flew.",
			want:   "The Reliant flew.",
		},
		{
			// A term never links inside a longer term's mention, linked or not:
			// the second "Hurston Dynamics" is not the planet.
			name: "term inside a longer term", titles: []string{"Hurston"},
			aliases: map[string]string{"Hurston Dynamics": "Hurston Dynamics"},
			body:    "The Hurston Dynamics gun. Then Hurston Dynamics again, and Hurston itself.",
			want:    "The [[Hurston Dynamics]] gun. Then Hurston Dynamics again, and [[Hurston]] itself.",
			links:   2,
		},
		{
			// A term inside a noLink phrase is not linked there; its next
			// mention is.
			name: "noLink phrase", titles: []string{"Vulcan", "Eclipse"},
			noLink: []string{"Vulcan (G12)", "Eclipse Mode"},
			body:   "The Vulcan (G12) render API and Eclipse Mode. Later the Vulcan flew.",
			want:   "The Vulcan (G12) render API and Eclipse Mode. Later the [[Vulcan]] flew.",
			links:  1,
		},
	} {
		v := BuildVocabulary(c.titles, c.aliases, nil, nil, c.noLink, c.corpus)
		got, links := v.Apply(c.body)
		if got != c.want || len(links) != c.links {
			t.Errorf("%s: Apply = %q with %d links, want %q with %d", c.name, got, len(links), c.want, c.links)
		}
	}
}
