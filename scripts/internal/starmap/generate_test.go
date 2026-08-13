package starmap

import "testing"

// observedSystemKeys and observedObjectKeys are the field names actually seen in
// the live payload (union across all systems and objects, including the optional
// model/texture/thumbnail extras that only some objects carry).
//
// They exist to keep the drift detector honest. A key missing from the known
// sets produces a false "unrecognised upstream field" warning on every run,
// which trains the reader to ignore the warning — exactly the failure this
// feature is meant to prevent. That happened once already: `affiliation` was
// omitted from knownObjectKeys.
var observedSystemKeys = []string{
	"affiliation", "aggregated_danger", "aggregated_economy",
	"aggregated_population", "aggregated_size", "celestial_objects", "code",
	"description", "frost_line", "habitable_zone_inner", "habitable_zone_outer",
	"id", "info_url", "name", "position_x", "position_y", "position_z",
	"shader_data", "status", "thumbnail", "time_modified", "type",
}

var observedObjectKeys = []string{
	"affiliation", "age", "appearance", "axial_tilt", "code", "description",
	"designation", "distance", "fairchanceact", "habitable", "id", "info_url",
	"latitude", "longitude", "model", "name", "orbit_period", "parent_id",
	"population", "sensor_danger", "sensor_economy", "sensor_population",
	"shader_data", "show_label", "show_orbitlines", "size", "subtype",
	"subtype_id", "texture", "thumbnail", "time_modified", "type",
}

func TestKnownKeysCoverObservedPayload(t *testing.T) {
	for _, k := range observedSystemKeys {
		if _, ok := knownSystemKeys[k]; !ok {
			t.Errorf("knownSystemKeys is missing %q, which the API does return", k)
		}
	}
	for _, k := range observedObjectKeys {
		if _, ok := knownObjectKeys[k]; !ok {
			t.Errorf("knownObjectKeys is missing %q, which the API does return", k)
		}
	}
}

// TestKnownKeysHaveNoInventions catches the opposite error: a key in the known
// set that upstream never sends. Those are harmless at runtime but mean the set
// has drifted from reality and would mask a genuine rename.
func TestKnownKeysHaveNoInventions(t *testing.T) {
	sys := make(map[string]struct{}, len(observedSystemKeys))
	for _, k := range observedSystemKeys {
		sys[k] = struct{}{}
	}
	for k := range knownSystemKeys {
		if _, ok := sys[k]; !ok {
			t.Errorf("knownSystemKeys contains %q, which was never observed upstream", k)
		}
	}

	obj := make(map[string]struct{}, len(observedObjectKeys))
	for _, k := range observedObjectKeys {
		obj[k] = struct{}{}
	}
	// children and media appear only on the per-object endpoint, not in the
	// system payload the observed list was taken from.
	obj["children"] = struct{}{}
	obj["media"] = struct{}{}
	for k := range knownObjectKeys {
		if _, ok := obj[k]; !ok {
			t.Errorf("knownObjectKeys contains %q, which was never observed upstream", k)
		}
	}
}

func TestBuildObjectCopiesSubtype(t *testing.T) {
	// The moon re-label mutates the subtype in place, so buildObject must copy
	// it. Sharing a pointer with the upstream struct would let one object's
	// re-label leak into another that happens to reference the same subtype.
	name := "Planetary Moon"
	src := &apiObject{ID: 1, Code: "X", Subtype: &Subtype{ID: intPtr(7), Name: name, Type: "SATELLITE"}}
	obj := buildObject(src, SystemRef{}, nil, nil)

	obj.Subtype.Type = "MOON"
	obj.Subtype.ID = nil

	if src.Subtype.Type != "SATELLITE" {
		t.Error("re-labelling the output subtype mutated the upstream struct")
	}
	if src.Subtype.ID == nil {
		t.Error("clearing the output subtype id mutated the upstream struct")
	}
}

func TestOrEmpty(t *testing.T) {
	if got := orEmpty(nil); got == nil || len(got) != 0 {
		t.Errorf("orEmpty(nil) must be an empty non-nil slice so it encodes as [], got %#v", got)
	}
	in := []Affiliation{{ID: 1}}
	if got := orEmpty(in); len(got) != 1 {
		t.Errorf("orEmpty must pass a populated slice through, got %#v", got)
	}
}

func intPtr(i int) *int { return &i }
