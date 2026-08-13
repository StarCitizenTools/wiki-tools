package itemstubs

import (
	"fmt"
	"strings"
)

// sectionBody maps a canonical section heading to the template it transcludes.
// The set matches the migrate-category-to-entity skill's canonical layout.
var sectionBody = map[string]string{
	"Description": "{{Entity/Description}}",
	"Ports":       "{{Entity/Ports}}",
	"Acquisition": "{{Entity/Availability}}",
	"Crafting":    "{{Entity/Blueprints}}",
	"Related":     "{{Entity/Related}}",
	"Used by":     "{{Entity/UsedBy}}",
}

// StubData is everything the renderer needs for one page. MfrPage empty means
// the manufacturer clause and navplate are omitted (unknown or generic maker);
// MfrCode still fills the infobox, where empty is also acceptable.
type StubData struct {
	Name, UUID       string
	MfrCode, MfrPage string
	Label, LabelLink string
	// NoLabelLink renders Label as plain text instead of [[Label]] or
	// [[LabelLink|Label]]. Set alongside LabelLink is a config error.
	NoLabelLink bool
	Navplate    string
	Sections    []string
	LeadSize    bool
	Size        *int
	Version     string // "4.9.0"
	Date        string // accessdate, YYYY-MM-DD
}

// RenderStub renders the canonical {{Entity}} stub. Layout mirrors the
// migrate-category-to-entity skill: infobox, one-line cited lead, fixed
// section order, references, navplates. The lead is deliberately minimal —
// anything richer than name/size/label/manufacturer would be fabrication at
// stub time; the applying agent polishes where context warrants.
func RenderStub(d StubData) string {
	var b strings.Builder

	fmt.Fprintf(&b, "{{Entity\n|uuid = %s\n|name = %s\n|image =\n|manufacturer = %s\n}}\n\n", d.UUID, d.Name, d.MfrCode)

	subject := d.Label
	if d.LeadSize && d.Size != nil {
		subject = fmt.Sprintf("size %d %s", *d.Size, d.Label)
	}
	label := "[[" + d.Label + "]]"
	switch {
	case d.LabelLink != "":
		label = "[[" + d.LabelLink + "|" + d.Label + "]]"
	case d.NoLabelLink:
		label = d.Label
	}
	lead := fmt.Sprintf("The '''%s''' is %s ", d.Name, article(subject))
	if d.LeadSize && d.Size != nil {
		lead += fmt.Sprintf("size %d %s", *d.Size, label)
	} else {
		lead += label
	}
	if d.MfrPage != "" {
		lead += fmt.Sprintf(" manufactured by [[%s]]", d.MfrPage)
	}
	// text=Datamine is not optional: without it {{Cite game}} renders "In-game
	// survey", which claims someone observed the item in the game. These pages
	// come from the item dump, and nobody has looked.
	ref := fmt.Sprintf(`<ref name="ig%s">{{Cite game|build=[[Star Citizen Alpha %s|Alpha %s]]|accessdate=%s|text=Datamine}}</ref>`,
		strings.ReplaceAll(d.Version, ".", ""), d.Version, d.Version, d.Date)
	b.WriteString(lead + "." + ref + "\n")

	for _, section := range d.Sections {
		fmt.Fprintf(&b, "\n== %s ==\n%s\n", section, sectionBody[section])
	}
	b.WriteString("\n== References ==\n<references />\n")

	var navplates []string
	if d.MfrPage != "" {
		navplates = append(navplates, "{{Navplate manufacturers|"+d.MfrCode+"}}")
	}
	if d.Navplate != "" {
		navplates = append(navplates, "{{Navplate "+d.Navplate+"}}")
	}
	if len(navplates) > 0 {
		b.WriteString("\n" + strings.Join(navplates, "\n") + "\n")
	}
	return b.String()
}

// article picks the indefinite article by the first letter of what follows it
// in the sentence ("a size 1 …", "an EMP generator"). Letter-based, not
// phonetic — good enough for game-item labels, and wrong cases surface in
// review before apply.
func article(subject string) string {
	if subject == "" {
		return "a"
	}
	switch strings.ToLower(subject)[0] {
	case 'a', 'e', 'i', 'o', 'u':
		return "an"
	}
	return "a"
}
