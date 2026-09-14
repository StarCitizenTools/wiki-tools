package bucketschemas

import (
	"testing"
)

const entityManifest = `{
 "%doc": "x",
 "%kinds": {"Item": ["entity","item_weapon"], "Vehicle": ["entity","vehicle_stats"]},
 "Modifier resistance": {"type": "DOUBLE", "bucket": "item_tool", "field": "modifier_resistance", "modules": ["Facet/Mining"], "desc": "d"},
 "Uuid": {"type": "TEXT", "bucket": "entity", "field": "uuid", "index": true, "modules": ["Base"], "desc": "d"},
 "Effects": {"type": "TEXT", "bucket": "entity", "field": "effects", "index": true, "repeated": true, "modules": ["Consumable"], "desc": "d"},
 "Scm speed": {"type": "DOUBLE", "bucket": {"Item": "item_weapon", "Vehicle": "vehicle_stats"}, "field": "scm_speed", "modules": ["Vehicle"], "desc": "d"}
}`

func TestBuildSchemas(t *testing.T) {
	schemas, err := Build([]byte(entityManifest))
	if err != nil {
		t.Fatal(err)
	}
	if got := len(schemas); got != 4 {
		t.Fatalf("want 4 buckets (entity, item_weapon, vehicle_stats, item_tool), got %d", got)
	}
	e := schemas["entity"]
	if e["uuid"] != (Field{Type: "TEXT", Index: true}) {
		t.Errorf("uuid: %+v", e["uuid"])
	}
	if e["effects"] != (Field{Type: "TEXT", Index: true, Repeated: true}) {
		t.Errorf("effects: %+v", e["effects"])
	}
	if schemas["item_weapon"]["scm_speed"].Type != "DOUBLE" || schemas["vehicle_stats"]["scm_speed"].Type != "DOUBLE" {
		t.Errorf("cross-kind property must land in both buckets: %+v", schemas)
	}
	if schemas["item_tool"]["modifier_resistance"].Type != "DOUBLE" {
		t.Errorf("mining modifier missing: %+v", schemas["item_tool"])
	}
}

func TestRenderIsSortedAndStable(t *testing.T) {
	schemas, _ := Build([]byte(entityManifest))
	out, err := Render(schemas["entity"])
	if err != nil {
		t.Fatal(err)
	}
	want := "{\n\t\"effects\": {\n\t\t\"type\": \"TEXT\",\n\t\t\"index\": true,\n\t\t\"repeated\": true\n\t},\n\t\"uuid\": {\n\t\t\"type\": \"TEXT\",\n\t\t\"index\": true,\n\t\t\"repeated\": false\n\t}\n}\n"
	if string(out) != want {
		t.Errorf("render mismatch:\n%s", out)
	}
}

func TestPageTitle(t *testing.T) {
	if got := PageTitle("vehicle_stats"); got != "Vehicle stats" {
		t.Errorf("got %q", got)
	}
}

func TestMergeIdenticalFields(t *testing.T) {
	dst := Schema{"name": {Type: "TEXT"}}
	src := Schema{"name": {Type: "TEXT"}, "image": {Type: "TEXT"}}
	if err := Merge("entity", dst, src); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(dst) != 2 || dst["image"] != (Field{Type: "TEXT"}) {
		t.Errorf("dst after merge: %+v", dst)
	}
}

func TestMergeThreeSourcesAccumulates(t *testing.T) {
	// Mirrors bucketschemas/main.go's fold-over-manifests loop: Entity defines
	// `entity`, Company adds a field to it, WearableSet adds another.
	entity := Schema{"name": {Type: "TEXT"}, "manufacturer": {Type: "PAGE", Index: true}}
	company := Schema{"name": {Type: "TEXT"}, "subject_type": {Type: "TEXT", Index: true}}
	wearableSet := Schema{"name": {Type: "TEXT"}, "manufacturer": {Type: "PAGE", Index: true}, "image": {Type: "TEXT"}}

	merged := Schema{}
	if err := Merge("entity", merged, entity); err != nil {
		t.Fatalf("merging entity: %v", err)
	}
	if err := Merge("entity", merged, company); err != nil {
		t.Fatalf("merging company: %v", err)
	}
	if err := Merge("entity", merged, wearableSet); err != nil {
		t.Fatalf("merging wearableSet: %v", err)
	}
	if len(merged) != 4 {
		t.Fatalf("merged has %d fields, want 4 (name, manufacturer, subject_type, image): %+v", len(merged), merged)
	}
	if merged["subject_type"] != (Field{Type: "TEXT", Index: true}) {
		t.Errorf("subject_type: %+v", merged["subject_type"])
	}
	if merged["image"] != (Field{Type: "TEXT"}) {
		t.Errorf("image: %+v", merged["image"])
	}
}

func TestMergeThreeSourcesFailsOnThirdMismatch(t *testing.T) {
	merged := Schema{}
	_ = Merge("entity", merged, Schema{"name": {Type: "TEXT", Index: false}})
	_ = Merge("entity", merged, Schema{"image": {Type: "TEXT"}})
	err := Merge("entity", merged, Schema{"name": {Type: "TEXT", Index: true}})
	if err == nil {
		t.Fatal("expected an error when the third source disagrees on an already-merged field")
	}
	if want := "bucket entity field name differs between manifests"; err.Error() != want {
		t.Errorf("got %q, want %q", err.Error(), want)
	}
}

func TestMergeDifferingShapeFails(t *testing.T) {
	dst := Schema{"name": {Type: "TEXT", Index: true}}
	src := Schema{"name": {Type: "TEXT", Index: false}}
	err := Merge("entity", dst, src)
	if err == nil {
		t.Fatal("expected an error")
	}
	if want := "bucket entity field name differs between manifests"; err.Error() != want {
		t.Errorf("got %q, want %q", err.Error(), want)
	}
}
