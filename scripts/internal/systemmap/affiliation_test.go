package systemmap

import "testing"

// The system map's eyebrow names the system's political space, so each system
// carries its first upstream affiliation code, lower-cased (upstream mixes
// `uee` and `UNC`).
func TestSystemsCarryTheirAffiliation(t *testing.T) {
	got := buildFromCommittedOverlay(t)
	for name, want := range map[string]string{"Stanton": "uee", "Pyro": "unc", "Nyx": "unc"} {
		sys, ok := got.Systems.Get(name)
		if !ok {
			t.Fatalf("%s not built", name)
		}
		if sys.Affiliation != want {
			t.Errorf("%s affiliation = %q, want %q", name, sys.Affiliation, want)
		}
	}
}
