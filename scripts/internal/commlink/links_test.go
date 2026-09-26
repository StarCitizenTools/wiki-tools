package commlink

import "testing"

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
