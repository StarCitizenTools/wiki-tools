package itemstubs

import (
	"os"
	"testing"
)

func TestConfigCommittedFileIsValid(t *testing.T) {
	b, err := os.ReadFile("../../cmd/itemstubs/config.json")
	if err != nil {
		t.Fatalf("reading committed config: %v", err)
	}
	cfg, err := ParseConfig(b)
	if err != nil {
		t.Fatalf("committed config invalid: %v", err)
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
	cases := map[string]string{
		"unknown kind":       `{"kinds":{},"types":{"A.B":{"kind":"nope","label":"x"}}}`,
		"missing label":      `{"kinds":{"item":{"sections":["Description"]}},"types":{"A.B":{"kind":"item"}}}`,
		"unknown section":    `{"kinds":{"item":{"sections":["Bogus"]}},"types":{}}`,
		"duplicate rule id":  `{"kinds":{},"types":{},"blocklist":[{"id":"x"},{"id":"x"}]}`,
		"unknown json field": `{"kinds":{},"types":{},"surprise":1}`,
	}
	for name, raw := range cases {
		if _, err := ParseConfig([]byte(raw)); err == nil {
			t.Errorf("%s: want validation error, got nil", name)
		}
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
