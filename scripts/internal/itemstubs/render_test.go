package itemstubs

import (
	"strings"
	"testing"
)

func TestRenderComponentStub(t *testing.T) {
	size := 1
	got := RenderStub(StubData{
		Name: "Dominance-1 Scattergun", UUID: "beabe016-3fb4-4e3f-b464-374076d91f04",
		MfrCode: "HRST", MfrPage: "Hurston Dynamics",
		Label: "vehicle weapon", Navplate: "Vehicle weapons",
		Sections: []string{"Description", "Ports", "Acquisition", "Crafting", "Related", "Used by"},
		LeadSize: true, Size: &size,
		Version: "4.9.0", Date: "2026-08-13",
	})
	want := `{{Entity
|uuid = beabe016-3fb4-4e3f-b464-374076d91f04
|name = Dominance-1 Scattergun
|image =
|manufacturer = HRST
}}

The '''Dominance-1 Scattergun''' is a size 1 [[vehicle weapon]] manufactured by [[Hurston Dynamics]].<ref name="ig490">{{Cite game|build=[[Star Citizen Alpha 4.9.0|Alpha 4.9.0]]|accessdate=2026-08-13|text=Datamine}}</ref>

== Description ==
{{Entity/Description}}

== Ports ==
{{Entity/Ports}}

== Acquisition ==
{{Entity/Availability}}

== Crafting ==
{{Entity/Blueprints}}

== Related ==
{{Entity/Related}}

== Used by ==
{{Entity/UsedBy}}

== References ==
<references />

{{Navplate manufacturers|HRST}}
{{Navplate Vehicle weapons}}
`
	if got != want {
		t.Errorf("component stub mismatch:\n--- got ---\n%s\n--- want ---\n%s", got, want)
	}
}

func TestRenderConsumableNoManufacturer(t *testing.T) {
	got := RenderStub(StubData{
		Name: "Big Benny's Mug", UUID: "6259d9a0-b449-4427-924a-e7713c5e15ee",
		MfrCode: "GEND", MfrPage: "", // resolved ok but omitted from lead
		Label:    "drink",
		Sections: []string{"Description", "Acquisition", "Related"},
		Version:  "4.9.0", Date: "2026-08-13",
	})
	want := `{{Entity
|uuid = 6259d9a0-b449-4427-924a-e7713c5e15ee
|name = Big Benny's Mug
|image =
|manufacturer = GEND
}}

The '''Big Benny's Mug''' is a [[drink]].<ref name="ig490">{{Cite game|build=[[Star Citizen Alpha 4.9.0|Alpha 4.9.0]]|accessdate=2026-08-13|text=Datamine}}</ref>

== Description ==
{{Entity/Description}}

== Acquisition ==
{{Entity/Availability}}

== Related ==
{{Entity/Related}}

== References ==
<references />
`
	if got != want {
		t.Errorf("consumable stub mismatch:\n--- got ---\n%s\n--- want ---\n%s", got, want)
	}
}

func TestRenderIndefiniteArticleAndLabelLink(t *testing.T) {
	got := RenderStub(StubData{
		Name: "Sledge II", UUID: "aaaaaaaa-0000-4000-8000-00000000000a",
		MfrCode: "ASAR", MfrPage: "A.S. Armaments",
		Label: "EMP generator", LabelLink: "EMP generator (component)",
		Sections: []string{"Description"},
		Version:  "4.9.0", Date: "2026-08-13",
	})
	wantLead := "The '''Sledge II''' is an [[EMP generator (component)|EMP generator]] manufactured by [[A.S. Armaments]]."
	if !strings.Contains(got, wantLead) {
		t.Errorf("lead: want %q in:\n%s", wantLead, got)
	}
}

func TestRenderNoLabelLink(t *testing.T) {
	got := RenderStub(StubData{
		Name: "FieldWorks Bunker", UUID: "aaaaaaaa-0000-4000-8000-00000000000b",
		MfrCode: "ARGO", MfrPage: "X",
		Label: "deployable", NoLabelLink: true,
		Sections: []string{"Description"},
		Version:  "4.9.0", Date: "2026-08-13",
	})
	wantLead := "is a deployable manufactured by [[X]]."
	if !strings.Contains(got, wantLead) {
		t.Errorf("lead: want %q in:\n%s", wantLead, got)
	}
	if strings.Contains(got, "[[deployable") {
		t.Errorf("noLabelLink label must not be linked, got:\n%s", got)
	}
}
