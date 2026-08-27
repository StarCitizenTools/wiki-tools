package itemstubs

import (
	"strings"
	"testing"
)

const sampleDump = `[
  {"stdItem": {"UUID": "BEABE016-3FB4-4E3F-B464-374076D91F04", "ClassName": "HRST_LaserScatterGun_S1",
    "Name": "Dominance-1 Scattergun", "Type": "WeaponGun.Gun", "Size": 1,
    "Manufacturer": {"Name": "Hurston Dynamics", "Code": "HRST", "UUID": "5cd8f7a1-0000-0000-0000-000000000001"}}},
  {"stdItem": {"UUID": "6259d9a0-b449-4427-924a-e7713c5e15ee", "ClassName": "Drink_mug_big_bennys_1_a",
    "Name": "Big Benny's Mug", "Type": "Drink.UNDEFINED", "Size": 1,
    "Manufacturer": "00000000-0000-0000-0000-000000000000"}},
  {"className": "no_std_item_here"},
  {"stdItem": {"UUID": "not-a-uuid", "ClassName": "broken", "Name": "Broken", "Type": "Misc.UNDEFINED"}}
]`

func TestDecodeItems(t *testing.T) {
	items, unusable, err := DecodeItems(strings.NewReader(sampleDump))
	if err != nil {
		t.Fatalf("DecodeItems: %v", err)
	}
	if len(items) != 2 {
		t.Fatalf("items = %d, want 2", len(items))
	}
	if unusable != 2 {
		t.Errorf("unusable = %d, want 2 (missing stdItem + bad uuid)", unusable)
	}
	gun := items[0]
	if gun.UUID != "beabe016-3fb4-4e3f-b464-374076d91f04" {
		t.Errorf("uuid not lowercased: %q", gun.UUID)
	}
	if gun.Manufacturer.Code != "HRST" || gun.Size == nil || *gun.Size != 1 {
		t.Errorf("gun decoded wrong: %+v", gun)
	}
	if mug := items[1]; mug.Manufacturer != (Manufacturer{}) {
		t.Errorf("string manufacturer should decode to zero value, got %+v", mug.Manufacturer)
	}
}

func TestDecodeItemsRejectsNonArray(t *testing.T) {
	if _, _, err := DecodeItems(strings.NewReader(`{"oops": true}`)); err == nil {
		t.Fatal("want error for non-array document")
	}
}

func TestVersion(t *testing.T) {
	if v, ok := Version("4.9.0-LIVE.12232306"); !ok || v != "4.9.0" {
		t.Errorf("Version = %q, %v", v, ok)
	}
	if _, ok := Version("fix: correctly classify ejection seats"); ok {
		t.Error("non-build commit line must not parse as a version")
	}
}

func TestLatestBuild(t *testing.T) {
	commits := []Commit{{SHA: "aaa111"}, {SHA: "bbb222"}}
	commits[0].Commit.Message = "fix: correctly classify ejection seats"
	commits[1].Commit.Message = "4.9.0-LIVE.12232306\n\nextraction notes"
	build, ok := LatestBuild(commits)
	if !ok || build != "4.9.0-LIVE.12232306" {
		t.Errorf("LatestBuild = %q, %v", build, ok)
	}
	if _, ok := LatestBuild(commits[:1]); ok {
		t.Error("maintenance-only history must not yield a build")
	}
}

func TestDumpURL(t *testing.T) {
	if got, want := DumpURL("master"), "https://raw.githubusercontent.com/StarCitizenWiki/scunpacked-data/master/items.json"; got != want {
		t.Errorf("DumpURL = %q, want %q", got, want)
	}
}
