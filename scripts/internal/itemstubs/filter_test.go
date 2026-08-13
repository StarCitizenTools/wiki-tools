package itemstubs

import "testing"

func testConfig() *Config {
	return &Config{
		Kinds: map[string]Kind{
			"component":  {Sections: []string{"Description", "Ports", "Acquisition", "Crafting", "Related", "Used by"}, LeadSize: true},
			"consumable": {Sections: []string{"Description", "Acquisition", "Related"}},
		},
		Types: map[string]TypeRule{
			"WeaponGun.Gun":   {Kind: "component", Label: "vehicle weapon", Navplate: "Vehicle weapons"},
			"Drink.UNDEFINED": {Kind: "consumable", Label: "drink"},
			"Cargo.Cargo":     {Skip: true},
		},
		Blocklist: []PatternRule{{ID: "isPlaceholder", NameContains: []string{"placeholder"}}},
		Review:    []PatternRule{{ID: "bespoke", ClassContains: []string{"_Bespoke"}}},
		Manufacturers: Manufacturers{
			Renames:    map[string]string{"BEH": "BEHR"},
			ByPrefix:   map[string]string{"volt_": "VOLT"},
			ByName:     map[string]string{"Quirinus Tech": "QRT"},
			Names:      map[string]string{"BEHR": "Behring", "HRST": "Hurston Dynamics", "GEND": "Consumable", "CDS": "Clark Defense Systems", "AEGS": "Aegis Dynamics", "ANVL": "Anvil Aerospace", "MISC": "Musashi Industrial and Starflight Concern", "MRAI": "Mirai", "KEGR": "Kel-To"},
			OmitInLead: []string{"GEND", "UNKN"},
			Aliases:    map[string]string{"MISC": "MRAI"},
		},
	}
}

func item(name, class, typ, uuid string) Item {
	return Item{UUID: uuid, Name: name, ClassName: class, Type: typ,
		Manufacturer: Manufacturer{Name: "Hurston Dynamics", Code: "HRST"}}
}

func TestClassify(t *testing.T) {
	cfg := testConfig()
	wiki := map[string]bool{"onwiki00-0000-4000-8000-000000000001": true}

	cases := []struct {
		name string
		item Item
		want string
		rule string
	}{
		{"exists", item("Gun", "x", "WeaponGun.Gun", "onwiki00-0000-4000-8000-000000000001"), DispExists, ""},
		{"placeholderUuid", item("Ghost", "x", "WeaponGun.Gun", "00000000-0000-0000-0000-000000000000"), DispBlocked, "placeholder-uuid"},
		{"unnamed", item("", "x", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000002"), DispBlocked, "unnamed"},
		{"nameEqualsClass", item("same_class", "same_class", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000003"), DispBlocked, "unnamed"},
		{"blocklist", item("<= PLACEHOLDER =>", "x", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000004"), DispBlocked, "isPlaceholder"},
		{"unmapped", item("Odd Thing", "x", "Misc.Harvestable", "aaaaaaaa-0000-4000-8000-000000000005"), DispUnmapped, ""},
		{"excluded", item("Grid", "x", "Cargo.Cargo", "aaaaaaaa-0000-4000-8000-000000000006"), DispExcluded, ""},
		{"review", item("TMSB-5 Gatling", "BEHR_BallisticGatling_Hornet_Bespoke", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000007"), DispReview, "bespoke"},
		{"create", item("Dominance-1 Scattergun", "HRST_LaserScatterGun_S1", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000008"), DispCreate, ""},
	}
	for _, tc := range cases {
		got := Classify(tc.item, wiki, cfg)
		if got.Disposition != tc.want || got.RuleID != tc.rule {
			t.Errorf("%s: got (%s, %q), want (%s, %q)", tc.name, got.Disposition, got.RuleID, tc.want, tc.rule)
		}
	}
}

func TestClassManufacturer(t *testing.T) {
	known := map[string]bool{"CDS": true, "AEGS": true, "ANVL": true}

	if got := ClassManufacturer("cds_combat_superheavy_suit_01_01_01", known); got != "CDS" {
		t.Errorf("cds class: got %q, want CDS", got)
	}
	// A code after a component-type prefix names the ship the part fits, not
	// its maker: Behring builds racks for Aegis hulls, so the two legitimately
	// differ and reading it as a maker claim floods the report.
	if got := ClassManufacturer("BMBRCK_S03_AEGS_Eclipse", known); got != "" {
		t.Errorf("ship code inside a part class is not a maker claim: got %q, want \"\"", got)
	}
	if got := ClassManufacturer("Controller_Flight_ANVL_Hornet_F7C", known); got != "" {
		t.Errorf("flight blade class: got %q, want \"\"", got)
	}
	if got := ClassManufacturer("hdtc_shirt_01_01_01", known); got != "" {
		t.Errorf("HDTC not in known set: got %q, want \"\"", got)
	}
	if got := ClassManufacturer("Cds_combat_suit_01", known); got != "CDS" {
		t.Errorf("case-insensitive: mixed-case prefix %q must still match CDS", "Cds")
	}
	if got := ClassManufacturer("", known); got != "" {
		t.Errorf("empty class name: got %q, want \"\"", got)
	}
}

func TestResolveManufacturer(t *testing.T) {
	m := testConfig().Manufacturers

	if code, page, ok := ResolveManufacturer(item("x", "VOLT_Gun_S1", "T.S", "u"), m); !ok || code != "VOLT" {
		t.Errorf("prefix inference (case-insensitive): got %q %q %v", code, page, ok)
	}
	it := item("x", "BEHR_Class", "T.S", "u")
	it.Manufacturer = Manufacturer{Name: "Behring", Code: "BEH"}
	if code, page, ok := ResolveManufacturer(it, m); !ok || code != "BEHR" || page != "Behring" {
		t.Errorf("rename: got %q %q %v", code, page, ok)
	}
	it.Manufacturer = Manufacturer{Name: "Quirinus Tech", Code: "QT"}
	if code, _, ok := ResolveManufacturer(it, m); !ok || code != "QRT" {
		t.Errorf("byName override: got %q %v", code, ok)
	}
	it.Manufacturer = Manufacturer{Name: "Consumable", Code: "GEND"}
	if code, page, ok := ResolveManufacturer(it, m); !ok || code != "GEND" || page != "" {
		t.Errorf("omitInLead must resolve ok with empty page: got %q %q %v", code, page, ok)
	}
	it.Manufacturer = Manufacturer{}
	if _, _, ok := ResolveManufacturer(it, m); ok {
		t.Error("no code, no prefix: must not resolve")
	}
	it.Manufacturer = Manufacturer{Code: "ZZZZ", Name: "Zed Industries"}
	if code, page, ok := ResolveManufacturer(it, m); !ok || code != "ZZZZ" || page != "Zed Industries" {
		t.Errorf("unknown code falls back to dump name: got %q %q %v", code, page, ok)
	}
}
