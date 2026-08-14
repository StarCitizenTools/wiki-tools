package systemmap

import (
	"strings"
	"testing"
)

func TestLoadOverlayKeepsWrittenOrder(t *testing.T) {
	// Order is not decoration: it is the order systems appear in systems.json,
	// and a map would deliver it alphabetically (Nyx, Pyro, Stanton).
	overlay, err := LoadOverlay([]byte(`{
		"systems": {
			"Stanton": { "bodies": { "Aaron Halo": { "after": "Crusader" }, "ArcCorp": { "page": "ArcCorp (planet)" } } },
			"Pyro": {},
			"Nyx": {}
		}
	}`))
	if err != nil {
		t.Fatal(err)
	}
	if got := strings.Join(overlay.Order, ","); got != "Stanton,Pyro,Nyx" {
		t.Errorf("system order = %q, want Stanton,Pyro,Nyx", got)
	}
	if got := strings.Join(overlay.Systems["Stanton"].BodyOrder, ","); got != "Aaron Halo,ArcCorp" {
		t.Errorf("body order = %q, want Aaron Halo,ArcCorp", got)
	}
	if got := overlay.Systems["Stanton"].Bodies["ArcCorp"].Page; got != "ArcCorp (planet)" {
		t.Errorf("page = %q", got)
	}
}

func TestLoadOverlayRejectsMisspelledKeys(t *testing.T) {
	// encoding/json ignores unknown fields by default, which would turn a typo
	// into a correction that silently stops applying — the same failure the
	// fail-loud body lookup exists to prevent.
	// Case is the one thing encoding/json is forgiving about: it matches field
	// names case-insensitively, so "moonof" is accepted and does apply. That
	// costs nothing, because it means the same thing. A name that means nothing
	// does not get the same treatment.
	cases := map[string]string{
		"unknown top-level key": `{"exclusions": []}`,
		"unknown system key":    `{"systems": {"Pyro": {"planets": {}}}}`,
		"misspelled correction": `{"systems": {"Pyro": {"bodies": {"Pyro IV": {"moon_of": "Pyro V"}}}}}`,
		"plausible invention":   `{"systems": {"Pyro": {"bodies": {"Pyro IV": {"parent": "Pyro V"}}}}}`,
		"wrong type":            `{"systems": {"Pyro": {"bodies": {"Pyro IV": {"iconRatio": "2.1"}}}}}`,
	}
	for name, in := range cases {
		t.Run(name, func(t *testing.T) {
			if _, err := LoadOverlay([]byte(in)); err == nil {
				t.Fatal("expected an error")
			}
		})
	}
}

func TestLoadOverlayRejectsContradictions(t *testing.T) {
	if _, err := LoadOverlay([]byte(`{"systems":{"Pyro":{"bodies":{"Pyro IV":{"after":"Monox","moonOf":"Pyro V"}}}}}`)); err == nil {
		t.Error("`after` orders a body on the rail and `moonOf` takes it off; both together is a contradiction")
	}
	if _, err := LoadOverlay([]byte(`{"systems":{"Pyro":{"star":{"after":"Monox"}}}}`)); err == nil {
		t.Error("a star has no position on the rail, so `after` on one is a mistake worth reporting")
	}
}

func TestGlobMatch(t *testing.T) {
	cases := []struct {
		pattern, s string
		want       bool
	}{
		{"Protoplanetary Disk*", "Protoplanetary Disk", true},
		{"Protoplanetary Disk*", "Protoplanetary Disk 9", true},
		// Upstream's own typo, which is why there are two patterns.
		{"Protoplentary Disk*", "Protoplentary Disk 4", true},
		{"Protoplanetary Disk*", "Protoplentary Disk 4", false},
		{"Protoplanetary Disk*", "Aaron Halo", false},
		{"Aaron Halo", "Aaron Halo", true},
		{"Aaron Halo", "Aaron Halo 2", false},
		{"*Disk*", "Kallis V Accretion Disk", true},
		{"*Belt", "Keeger Belt", true},
		{"*Belt", "Belt Alpha", false},
	}
	for _, c := range cases {
		if got := globMatch(c.pattern, c.s); got != c.want {
			t.Errorf("globMatch(%q, %q) = %v, want %v", c.pattern, c.s, got, c.want)
		}
	}
}
