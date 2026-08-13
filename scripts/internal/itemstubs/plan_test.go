package itemstubs

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/mediawiki"
)

func TestBuildPlan(t *testing.T) {
	cfg := testConfig() // from filter_test.go
	wiki := map[string]bool{"onwiki00-0000-4000-8000-000000000001": true}

	gun := item("Dominance-1 Scattergun", "HRST_LaserScatterGun_S1", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000010")
	taken := item("Cutlass Black", "x", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000011")
	cupA := item("Cup", "Drink_cup_a", "Drink.UNDEFINED", "aaaaaaaa-0000-4000-8000-000000000012")
	cupB := item("Cup", "Drink_cup_b", "Drink.UNDEFINED", "aaaaaaaa-0000-4000-8000-000000000013")
	badTitle := item("Weird#Name", "x", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000014")
	bespoke := item("TMSB-5 Gatling", "BEHR_BallisticGatling_Hornet_Bespoke", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000015")
	noMfr := item("Ghost Gun", "unknown_class", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000016")
	noMfr.Manufacturer = Manufacturer{}
	exists := item("Old Gun", "x", "WeaponGun.Gun", "onwiki00-0000-4000-8000-000000000001")
	blocked := item("<= PLACEHOLDER =>", "x", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000018")
	unmapped := item("Stone Fruit", "x", "Misc.Harvestable", "aaaaaaaa-0000-4000-8000-000000000017")

	items := []Item{gun, taken, cupA, cupB, badTitle, bespoke, noMfr, exists, blocked, unmapped}

	statuses := func(_ context.Context, titles []string) (map[string]mediawiki.TitleStatus, error) {
		out := map[string]mediawiki.TitleStatus{}
		for _, title := range titles {
			if title == "Cutlass Black" {
				out[title] = mediawiki.TitleExists
			} else {
				out[title] = mediawiki.TitleMissing
			}
		}
		return out, nil
	}

	plan, err := BuildPlan(context.Background(), items, wiki, nil, cfg, testRegistry(), Meta{
		Build: "4.9.0-LIVE.12232306", Source: "scunpacked-data@abc1234",
		Generated: time.Date(2026, 8, 13, 12, 0, 0, 0, time.UTC),
	}, statuses)
	if err != nil {
		t.Fatalf("BuildPlan: %v", err)
	}

	if len(plan.Create) != 1 || plan.Create[0].Title != "Dominance-1 Scattergun" {
		t.Fatalf("create = %+v, want just the scattergun", plan.Create)
	}
	if plan.Create[0].Summary != "Create item stub from Alpha 4.9.0 datamine" {
		t.Errorf("summary = %q", plan.Create[0].Summary)
	}

	reasons := map[string]int{}
	for _, c := range plan.Conflicts {
		reasons[c.Reason]++
	}
	for reason, want := range map[string]int{
		"title-exists": 1, "duplicate-name": 1, "invalid-title": 1,
		"review:bespoke": 1, "no-manufacturer": 1,
	} {
		if reasons[reason] != want {
			t.Errorf("conflicts[%s] = %d, want %d (all: %+v)", reason, reasons[reason], want, reasons)
		}
	}
	for _, c := range plan.Conflicts {
		if c.Reason == "duplicate-name" && len(c.UUIDs) != 2 {
			t.Errorf("duplicate-name should list both cup uuids: %+v", c)
		}
		if c.Reason == "review:bespoke" && c.Wikitext == "" {
			t.Error("review conflict must attach the rendered stub")
		}
	}

	if plan.Skipped.Exists != 1 {
		t.Errorf("skipped.exists = %d, want 1", plan.Skipped.Exists)
	}
	if plan.Skipped.Blocked["isPlaceholder"] != 1 {
		t.Errorf("skipped.blocked[isPlaceholder] = %d, want 1", plan.Skipped.Blocked["isPlaceholder"])
	}
	if len(plan.Unmapped) != 1 || plan.Unmapped[0].Type != "Misc.Harvestable" || plan.Unmapped[0].Sample != "Stone Fruit" {
		t.Errorf("unmapped = %+v", plan.Unmapped)
	}
	if !plan.Drift() {
		t.Error("plan with creates+conflicts must report drift")
	}
	report := Report(plan)
	if len(report) == 0 {
		t.Error("report must not be empty")
	}
	reportStr := strings.Join(report, "\n")
	if !strings.Contains(reportStr, "isPlaceholder") {
		t.Errorf("report should itemize blocked by rule (isPlaceholder), got:\n%s", reportStr)
	}
}

// T3: an item whose class name implies a different manufacturer than the one
// resolved from the dump is reported in Mismatches but is NOT blocked from
// being planned — the disagreement is advisory, not a conflict. An
// alias-listed pair (a known-legitimate disagreement) must not be reported.
func TestBuildPlanManufacturerMismatch(t *testing.T) {
	cfg := testConfig()
	wiki := map[string]bool{}

	mismatch := item("APX Fire Extinguisher", "kegr_fire_extinguisher_01", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000040")
	mismatch.Manufacturer = Manufacturer{Name: "Anvil Aerospace", Code: "ANVL"}

	// A ship part: the code names the hull the part fits, not its maker, so
	// disagreeing with the manufacturer is normal and must not be reported.
	shipPart := item("Hornet Flight Blade", "Controller_Flight_ANVL_Hornet_F7C", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000043")
	shipPart.Manufacturer = Manufacturer{Name: "Behring Applied Technology", Code: "BEHR"}

	aliased := item("Old Flight Jacket", "MISC_Jacket_Torso_01_01_01", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000041")
	aliased.Manufacturer = Manufacturer{Name: "Mirai", Code: "MRAI"}

	agree := item("Dominance-1 Scattergun", "HRST_LaserScatterGun_S1", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000042")

	items := []Item{mismatch, aliased, agree, shipPart}

	statuses := func(_ context.Context, titles []string) (map[string]mediawiki.TitleStatus, error) {
		out := map[string]mediawiki.TitleStatus{}
		for _, title := range titles {
			out[title] = mediawiki.TitleMissing
		}
		return out, nil
	}

	plan, err := BuildPlan(context.Background(), items, wiki, nil, cfg, testRegistry(), Meta{
		Build: "4.9.0-LIVE.12232306", Generated: time.Date(2026, 8, 13, 12, 0, 0, 0, time.UTC),
	}, statuses)
	if err != nil {
		t.Fatalf("BuildPlan: %v", err)
	}

	if len(plan.Create) != 4 {
		t.Fatalf("create = %+v, want all 4 items planned regardless of the mismatch", plan.Create)
	}

	// The create entry itself must carry the mismatch flag: an agent applying
	// create[] verbatim has to see it there, not only in the separate
	// Mismatches array.
	var mismatchCreate *CreateEntry
	for i := range plan.Create {
		if plan.Create[i].Title == "APX Fire Extinguisher" {
			mismatchCreate = &plan.Create[i]
		}
	}
	if mismatchCreate == nil {
		t.Fatal("expected APX Fire Extinguisher in create")
	}
	if mismatchCreate.MismatchFromClass != "KEGR" {
		t.Errorf("create[APX Fire Extinguisher].MismatchFromClass = %q, want %q", mismatchCreate.MismatchFromClass, "KEGR")
	}
	for _, c := range plan.Create {
		if c.Title != "APX Fire Extinguisher" && c.MismatchFromClass != "" {
			t.Errorf("create[%s].MismatchFromClass = %q, want empty (no mismatch)", c.Title, c.MismatchFromClass)
		}
	}

	if len(plan.Mismatches) != 1 {
		t.Fatalf("mismatches = %+v, want exactly 1", plan.Mismatches)
	}
	m := plan.Mismatches[0]
	if m.Title != "APX Fire Extinguisher" || m.Resolved != "ANVL" || m.FromClass != "KEGR" || m.ClassName != "kegr_fire_extinguisher_01" {
		t.Errorf("mismatch = %+v, want APX Fire Extinguisher ANVL/KEGR", m)
	}

	for _, mm := range plan.Mismatches {
		if mm.Title == "Old Flight Jacket" {
			t.Errorf("alias-listed pair MISC->MRAI must not be reported as a mismatch: %+v", mm)
		}
		if mm.Title == "Hornet Flight Blade" {
			t.Errorf("a ship code inside a part's class name is not a manufacturer claim: %+v", mm)
		}
	}

	report := strings.Join(Report(plan), "\n")
	if !strings.Contains(report, "APX Fire Extinguisher: dump ANVL, class says KEGR (kegr_fire_extinguisher_01)") {
		t.Errorf("report should render the mismatch, got:\n%s", report)
	}
}

// T1: a title the statuses stub omits from its result map (e.g. because the
// wiki's API answered it outside query.pages entirely) must not fail open to
// create — it has to land in conflicts instead.
func TestBuildPlanUnknownTitleStatus(t *testing.T) {
	cfg := testConfig()
	wiki := map[string]bool{}

	mystery := item("Mystery Item", "HRST_LaserScatterGun_S1", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000030")

	statuses := func(_ context.Context, _ []string) (map[string]mediawiki.TitleStatus, error) {
		return map[string]mediawiki.TitleStatus{}, nil // omits every title queried
	}

	plan, err := BuildPlan(context.Background(), []Item{mystery}, wiki, nil, cfg, testRegistry(), Meta{
		Build: "4.9.0-LIVE.12232306", Generated: time.Date(2026, 8, 13, 12, 0, 0, 0, time.UTC),
	}, statuses)
	if err != nil {
		t.Fatalf("BuildPlan: %v", err)
	}

	if len(plan.Create) != 0 {
		t.Fatalf("create = %+v, want none (unknown status must not fail open)", plan.Create)
	}
	if len(plan.Conflicts) != 1 || plan.Conflicts[0].Reason != "unknown-title-status" {
		t.Fatalf("conflicts = %+v, want exactly one unknown-title-status", plan.Conflicts)
	}
	if plan.Conflicts[0].Title != "Mystery Item" || plan.Conflicts[0].UUID != mystery.UUID {
		t.Errorf("conflict = %+v, want title/uuid for the queried item", plan.Conflicts[0])
	}
}

// T4: a title-exists conflict attaches evidence about what the existing page
// already documents — the on-page item's uuid, class name, and whether its
// description matches the flagged item's — but only when wikiByPage actually
// names a page for that title and that uuid resolves to a dump item.
func TestBuildPlanTitleExistsEvidence(t *testing.T) {
	cfg := testConfig()

	onPageSame := item("Old Page Item", "on_page_class_a", "WeaponGun.Gun", "bbbbbbbb-0000-4000-8000-000000000001")
	onPageSame.Description = "A weapon description."
	onPageDiff := item("Old Page Item 2", "on_page_class_b", "WeaponGun.Gun", "bbbbbbbb-0000-4000-8000-000000000002")
	onPageDiff.Description = "A different weapon."
	onPageEmpty := item("Old Page Item 3", "on_page_class_c", "WeaponGun.Gun", "bbbbbbbb-0000-4000-8000-000000000003")
	onPageEmpty.Description = ""

	sameDesc := item("Same Desc Item", "class_a", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000061")
	sameDesc.Description = "  A weapon description.  " // TrimSpace must still equate this with onPageSame's
	diffDesc := item("Diff Desc Item", "class_b", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000062")
	diffDesc.Description = "Not matching text."
	emptyDesc := item("Empty Desc Item", "class_d", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000064")
	emptyDesc.Description = ""
	noPageRecord := item("No Page Record Item", "class_c", "WeaponGun.Gun", "aaaaaaaa-0000-4000-8000-000000000063")
	noPageRecord.Description = "whatever"

	wiki := map[string]bool{onPageSame.UUID: true, onPageDiff.UUID: true, onPageEmpty.UUID: true}
	wikiByPage := map[string]string{
		"Same Desc Item":  onPageSame.UUID,
		"Diff Desc Item":  onPageDiff.UUID,
		"Empty Desc Item": onPageEmpty.UUID,
		// "No Page Record Item" is deliberately absent: title-exists but no
		// page recorded in the uuidindex scan.
	}

	items := []Item{onPageSame, onPageDiff, onPageEmpty, sameDesc, diffDesc, emptyDesc, noPageRecord}

	statuses := func(_ context.Context, titles []string) (map[string]mediawiki.TitleStatus, error) {
		out := map[string]mediawiki.TitleStatus{}
		for _, title := range titles {
			out[title] = mediawiki.TitleExists
		}
		return out, nil
	}

	plan, err := BuildPlan(context.Background(), items, wiki, wikiByPage, cfg, testRegistry(), Meta{
		Build: "4.9.0-LIVE.12232306", Generated: time.Date(2026, 8, 13, 12, 0, 0, 0, time.UTC),
	}, statuses)
	if err != nil {
		t.Fatalf("BuildPlan: %v", err)
	}

	byTitle := map[string]ConflictEntry{}
	for _, c := range plan.Conflicts {
		if c.Reason == "title-exists" {
			byTitle[c.Title] = c
		}
	}
	if len(byTitle) != 4 {
		t.Fatalf("title-exists conflicts = %+v, want 4", plan.Conflicts)
	}

	same := byTitle["Same Desc Item"]
	if same.OnPageUUID != onPageSame.UUID || same.OnPageClass != "on_page_class_a" || !same.SameDescription {
		t.Errorf("same-description conflict = %+v, want OnPageUUID/OnPageClass set and SameDescription true", same)
	}

	diff := byTitle["Diff Desc Item"]
	if diff.OnPageUUID != onPageDiff.UUID || diff.OnPageClass != "on_page_class_b" || diff.SameDescription {
		t.Errorf("different-description conflict = %+v, want OnPageUUID/OnPageClass set and SameDescription false", diff)
	}

	empty := byTitle["Empty Desc Item"]
	if empty.OnPageUUID != onPageEmpty.UUID || empty.OnPageClass != "on_page_class_c" || empty.SameDescription {
		t.Errorf("both-empty-description conflict = %+v, want SameDescription false even though both sides are empty", empty)
	}

	noPage := byTitle["No Page Record Item"]
	if noPage.OnPageUUID != "" || noPage.OnPageClass != "" || noPage.SameDescription {
		t.Errorf("conflict with no wikiByPage entry = %+v, want none of the three evidence fields set", noPage)
	}

	// The terminal report surfaces a same-description match inline, so it's
	// visible without opening the JSON — but only for the entry that actually
	// has one.
	report := strings.Join(Report(plan), "\n")
	if !strings.Contains(report, "title-exists: Same Desc Item (same description as the item already on the page)") {
		t.Errorf("report should flag the same-description title-exists conflict, got:\n%s", report)
	}
	if strings.Contains(report, "Diff Desc Item (same description") {
		t.Errorf("report must not flag a title-exists conflict whose descriptions differ, got:\n%s", report)
	}
}

// T2: two items whose names differ only by MediaWiki first-letter/whitespace
// normalisation ("Cup" vs "cup") target the same wiki page, so they must
// collapse into a single duplicate-name conflict rather than two separate
// creates for the same title.
func TestBuildPlanDuplicateTitleNormalization(t *testing.T) {
	cfg := testConfig()
	wiki := map[string]bool{}

	cupUpper := item("Cup", "Drink_cup_a", "Drink.UNDEFINED", "aaaaaaaa-0000-4000-8000-000000000031")
	cupLower := item("cup", "Drink_cup_b", "Drink.UNDEFINED", "aaaaaaaa-0000-4000-8000-000000000032")

	statuses := func(_ context.Context, titles []string) (map[string]mediawiki.TitleStatus, error) {
		out := map[string]mediawiki.TitleStatus{}
		for _, title := range titles {
			out[title] = mediawiki.TitleMissing
		}
		return out, nil
	}

	plan, err := BuildPlan(context.Background(), []Item{cupUpper, cupLower}, wiki, nil, cfg, testRegistry(), Meta{
		Build: "4.9.0-LIVE.12232306", Generated: time.Date(2026, 8, 13, 12, 0, 0, 0, time.UTC),
	}, statuses)
	if err != nil {
		t.Fatalf("BuildPlan: %v", err)
	}

	if len(plan.Create) != 0 {
		t.Fatalf("create = %+v, want none for either cup", plan.Create)
	}
	var dup []ConflictEntry
	for _, c := range plan.Conflicts {
		if c.Reason == "duplicate-name" {
			dup = append(dup, c)
		}
	}
	if len(dup) != 1 {
		t.Fatalf("duplicate-name conflicts = %+v, want exactly 1", dup)
	}
	if dup[0].Title != "Cup" {
		t.Errorf("title = %q, want normalized %q", dup[0].Title, "Cup")
	}
	want1, want2 := cupUpper.UUID, cupLower.UUID
	if want1 > want2 {
		want1, want2 = want2, want1
	}
	if len(dup[0].UUIDs) != 2 || dup[0].UUIDs[0] != want1 || dup[0].UUIDs[1] != want2 {
		t.Errorf("uuids = %v, want [%s %s]", dup[0].UUIDs, want1, want2)
	}
}
