package itemstubs

import (
	"os"
	"testing"
)

// TestConfigCommittedFileIsValid is the drift gate: it loads the real
// committed config.json together with the real registry files this repo
// already maintains, and asserts they agree. It fails if either registry
// changes in a way the config now contradicts (a code the config still
// treats specially disappearing from the registry, a label the config still
// spells out becoming redundant with a renamed registry entry, and so on).
func TestConfigCommittedFileIsValid(t *testing.T) {
	reg, err := LoadRegistry("../../../pages/module/Manufacturers/data.json", "../../../pages/module/Entity/Item/types.json")
	if err != nil {
		t.Fatalf("loading the wiki's registries: %v", err)
	}

	b, err := os.ReadFile("../../cmd/itemstubs/config.json")
	if err != nil {
		t.Fatalf("reading committed config: %v", err)
	}
	cfg, err := ParseConfig(b, reg)
	if err != nil {
		t.Fatalf("committed config invalid against the committed registries: %v", err)
	}
	for _, typ := range []string{"WeaponGun.Gun", "Cooler.UNDEFINED"} {
		rule, ok := cfg.Types[typ]
		if !ok || rule.Skip || rule.Kind == "" {
			t.Errorf("expected an active allowlist entry for %s, got %+v (ok=%v)", typ, rule, ok)
		}
	}
	if rule, ok := cfg.Types["Cargo.Cargo"]; !ok || !rule.Skip {
		t.Errorf("Cargo.Cargo should be a known skip, got %+v (ok=%v)", rule, ok)
	}
}

func TestConfigValidation(t *testing.T) {
	emptyReg := &Registry{}
	cases := map[string]string{
		"unknown kind":       `{"kinds":{},"types":{"A.B":{"kind":"nope","label":"x"}}}`,
		"missing label":      `{"kinds":{"item":{"sections":["Description"]}},"types":{"A.B":{"kind":"item"}}}`,
		"unknown section":    `{"kinds":{"item":{"sections":["Bogus"]}},"types":{}}`,
		"duplicate rule id":  `{"kinds":{},"types":{},"blocklist":[{"id":"x"},{"id":"x"}]}`,
		"unknown json field": `{"kinds":{},"types":{},"surprise":1}`,
		"labelLink and noLabelLink both set": `{"kinds":{"item":{"sections":["Description"]}},
			"types":{"A.B":{"kind":"item","label":"x","labelLink":"X","noLabelLink":true}}}`,
		"renames value not in registry or synthetic": `{"kinds":{},"types":{},
			"manufacturers":{"renames":{"OLD":"NEW"}}}`,
		"byPrefix value not in registry or synthetic": `{"kinds":{},"types":{},
			"manufacturers":{"byPrefix":{"foo_":"FOO"}}}`,
		"byName value not in registry or synthetic": `{"kinds":{},"types":{},
			"manufacturers":{"byName":{"Foo Inc":"FOO"}}}`,
		"aliases value not in registry or synthetic": `{"kinds":{},"types":{},
			"manufacturers":{"aliases":{"FOO":"BAR"}}}`,
		"omitInLead code not in registry or synthetic": `{"kinds":{},"types":{},
			"manufacturers":{"omitInLead":["FOO"]}}`,
	}
	for name, raw := range cases {
		if _, err := ParseConfig([]byte(raw), emptyReg); err == nil {
			t.Errorf("%s: want validation error, got nil", name)
		}
	}
}

func TestConfigValidationManufacturerRefsOK(t *testing.T) {
	reg := &Registry{Manufacturers: map[string]ManufacturerRecord{
		"NEW": {Name: "New Co."},
		"FOO": {Name: "Foo Co."},
	}}
	raw := `{"kinds":{},"types":{},
		"manufacturers":{
			"renames":{"OLD":"NEW"},
			"byPrefix":{"foo_":"FOO"},
			"byName":{"Foo Inc":"FOO"},
			"aliases":{"FOO":"BAR"},
			"omitInLead":["BAR"],
			"synthetic":["BAR"]
		}}`
	if _, err := ParseConfig([]byte(raw), reg); err != nil {
		t.Errorf("want no error when every referenced code is in the registry or synthetic, got: %v", err)
	}
}

func TestConfigValidationRedundantLabelRejected(t *testing.T) {
	reg := &Registry{Types: map[string]TypeRecord{"Cooler": {Name: "Cooler", Category: "Coolers"}}}
	// An exact copy of what LabelFor would derive is redundant and rejected.
	raw := `{"kinds":{"item":{"sections":["Description"]}},
		"types":{"Cooler.UNDEFINED":{"kind":"item","label":"cooler"}}}`
	if _, err := ParseConfig([]byte(raw), reg); err == nil {
		t.Fatal("want error: an explicit label that only restates the registry's name must be rejected")
	}
}

func TestConfigValidationCaseCorrectingLabelAllowed(t *testing.T) {
	// LabelFor lowercases, which is right for "Arm armor" and wrong for a brand:
	// mobiGlas' article is not "Mobiglas", so the label must be able to restore
	// the casing without tripping the redundancy gate.
	reg := &Registry{Types: map[string]TypeRecord{"MobiGlas": {Name: "mobiGlas", Category: "mobiGlas"}}}
	raw := `{"kinds":{"item":{"sections":["Description"]}},
		"types":{"MobiGlas.Personal":{"kind":"item","label":"mobiGlas"}}}`
	if _, err := ParseConfig([]byte(raw), reg); err != nil {
		t.Fatalf("a case-correcting label must be allowed, got: %v", err)
	}
}

func TestConfigValidationManufacturerCodeNeitherRegistryNorSynthetic(t *testing.T) {
	reg := &Registry{}
	raw := `{"kinds":{},"types":{},"manufacturers":{"omitInLead":["GHOST"]}}`
	if _, err := ParseConfig([]byte(raw), reg); err == nil {
		t.Fatal("want error: a code that is neither in the registry nor declared synthetic must be rejected")
	}
}

func TestLabelFor(t *testing.T) {
	cfg := &Config{Types: map[string]TypeRule{
		"WeaponGun.Gun":    {Label: "vehicle weapon"},
		"Cooler.UNDEFINED": {},
		"Bogus.UNDEFINED":  {},
	}}
	reg := &Registry{Types: map[string]TypeRecord{
		"Cooler": {Name: "Cooler", Category: "Coolers"},
	}}
	if got := cfg.LabelFor("WeaponGun.Gun", reg); got != "vehicle weapon" {
		t.Errorf("explicit label should win: got %q", got)
	}
	if got := cfg.LabelFor("Cooler.UNDEFINED", reg); got != "cooler" {
		t.Errorf("derived label should be the lowercased registry name: got %q", got)
	}
	if got := cfg.LabelFor("Bogus.UNDEFINED", reg); got != "" {
		t.Errorf("neither an explicit label nor a registry entry: got %q, want \"\"", got)
	}
}

func TestPatternRuleMatches(t *testing.T) {
	rule := PatternRule{ID: "bespoke", ClassContains: []string{"_Bespoke"}, ClassPrefixes: []string{"RSI_Constellation_"}}
	if !rule.Matches("TMSB-5 Gatling", "BEHR_BallisticGatling_Hornet_Bespoke", "") {
		t.Error("classContains should match")
	}
	if !rule.Matches("SureGrip TH2", "RSI_Constellation_Taurus_Tractor_Beam", "") {
		t.Error("classPrefixes should match")
	}
	if rule.Matches("Plain", "HRST_LaserScatterGun_S1", "") {
		t.Error("unrelated class must not match")
	}
	name := PatternRule{ID: "ph", NameContains: []string{"placeholder"}, NamePrefixes: []string{"PH - "}}
	if !name.Matches("<= PLACEHOLDER =>", "x", "") || !name.Matches("PH - Gun", "x", "") {
		t.Error("name patterns should match case-insensitively for nameContains")
	}
}

func TestPatternRuleMatchesDescription(t *testing.T) {
	rule := PatternRule{ID: "bespoke", DescContains: []string{"bespoke", "designed specifically for"}}
	if !rule.Matches("890 Jump Module", "JDRV_ORIG_S04_890J_SCItem",
		"This capital-class jump module was designed specifically for the 890 Jump.") {
		t.Error("descContains should match built-in hardware by its description")
	}
	if !rule.Matches("Hull B Missile Rack", "MRCK_S06_MISC_Hull_B", "Bespoke missile rack for the MISC Hull B.") {
		t.Error("descContains should be case-insensitive")
	}
	if rule.Matches("Dominance-1 Scattergun", "HRST_LaserScatterGun_S1", "A scattergun for vehicles.") {
		t.Error("an ordinary description must not match")
	}
}

func TestPatternRuleNameExact(t *testing.T) {
	rule := PatternRule{ID: "isPlaceholder", NameExact: []string{"PH"}}
	if !rule.Matches("PH", "rrs_specialist_light_helmet_01_05_01", "") {
		t.Error("nameExact should match the whole placeholder name")
	}
	if rule.Matches("PHX Rifle", "x", "") {
		t.Error("nameExact must not match a real name that merely starts with it")
	}
}

func TestPatternRuleMatchesDescriptionEnds(t *testing.T) {
	rule := PatternRule{ID: "isPlaceholder", DescPrefixes: []string{"(PH)", "PH "}, DescSuffixes: []string{" Description"}}
	// CIG's own stub markers, taken verbatim from the dump.
	if !rule.Matches("Jukebox", "Flair_Jukebox", "(PH) Jukebox Description") {
		t.Error("a (PH)-prefixed description is a stub")
	}
	if !rule.Matches("Origin 85X Schematic", "Flair_Schematic_Orig_85X", "PH Schematic: Get to know every inch of the 85X.") {
		t.Error("a PH-marked description is provisional even when it carries prose")
	}
	if !rule.Matches("Aegis Hammerhead Schematic", "x", "Schematic: Aegis Hammerhead Description") {
		t.Error("a description ending in \" Description\" is an unwritten loc string")
	}
	if rule.Matches("Pickle", "Food_Pickle_01", "A pickled cucumber fermented in a brine flavored with dill.") {
		t.Error("real prose must not match")
	}
}
