package itemstubs

import (
	"strings"
	"testing"
)

func TestManufacturerPagePrefersPageOverName(t *testing.T) {
	reg := &Registry{Manufacturers: map[string]ManufacturerRecord{
		// ARCC's real shape: the article is the planet, so Page overrides Name.
		"ARCC": {Name: "ArcCorp", Page: "ArcCorp (company)"},
		"ANVL": {Name: "Anvil Aerospace", Short: "Anvil"},
	}}
	if got := reg.ManufacturerPage("ARCC"); got != "ArcCorp (company)" {
		t.Errorf("ManufacturerPage(ARCC) = %q, want %q", got, "ArcCorp (company)")
	}
	if got := reg.ManufacturerPage("ANVL"); got != "Anvil Aerospace" {
		t.Errorf("ManufacturerPage(ANVL) = %q, want %q (falls back to Name)", got, "Anvil Aerospace")
	}
	if got := reg.ManufacturerPage("ZZZZ"); got != "" {
		t.Errorf("ManufacturerPage(unknown) = %q, want \"\"", got)
	}
}

func TestTypeNameLookup(t *testing.T) {
	reg := &Registry{Types: map[string]TypeRecord{
		"Cooler": {Name: "Cooler", Category: "Coolers"},
	}}
	if got := reg.TypeName("Cooler"); got != "Cooler" {
		t.Errorf("TypeName(Cooler) = %q, want %q", got, "Cooler")
	}
	if got := reg.TypeName("Bogus"); got != "" {
		t.Errorf("TypeName(unknown) = %q, want \"\"", got)
	}
}

func TestLoadRegistryMissingPath(t *testing.T) {
	_, err := LoadRegistry("testdata/does-not-exist-manufacturers.json", "testdata/does-not-exist-types.json")
	if err == nil {
		t.Fatal("want error for a missing manufacturers path, got nil")
	}
	if !strings.Contains(err.Error(), "does-not-exist-manufacturers.json") {
		t.Errorf("error should name the failing path, got: %v", err)
	}
}
