package uuidindex

import (
	"reflect"
	"testing"
)

func TestTitleForUsesStoredCase(t *testing.T) {
	// The namespace is first-letter case-insensitive, so MediaWiki stores
	// letter-initial uuids with the first character uppercased.
	got := TitleFor("a039ab20-5484-4211-972b-facfa59f5233")
	want := "UUID:A039ab20-5484-4211-972b-facfa59f5233"
	if got != want {
		t.Errorf("TitleFor = %q, want %q", got, want)
	}
	if got := TitleFor("0029eeb3-9062-47d6-82bd-27246f31427b"); got != "UUID:0029eeb3-9062-47d6-82bd-27246f31427b" {
		t.Errorf("digit-initial TitleFor = %q", got)
	}
}

func TestUUIDFromTitle(t *testing.T) {
	cases := []struct {
		title string
		uuid  string
		ok    bool
	}{
		{"UUID:A039ab20-5484-4211-972b-facfa59f5233", "a039ab20-5484-4211-972b-facfa59f5233", true},
		{"UUID:0029eeb3-9062-47d6-82bd-27246f31427b", "0029eeb3-9062-47d6-82bd-27246f31427b", true},
		// Case variants normalise to the same uuid.
		{"UUID:A039AB20-5484-4211-972B-FACFA59F5233", "a039ab20-5484-4211-972b-facfa59f5233", true},
		// A group one digit short, as left behind by a typo'd infobox value.
		{"UUID:00000000-0000-0000-0000-00000000000", "", false},
		{"UUID:not-a-uuid", "", false},
		{"Somewhere else", "", false},
	}
	for _, c := range cases {
		uuid, ok := UUIDFromTitle(c.title)
		if ok != c.ok || (ok && uuid != c.uuid) {
			t.Errorf("UUIDFromTitle(%q) = %q, %v; want %q, %v", c.title, uuid, ok, c.uuid, c.ok)
		}
	}
}

const (
	uuidA = "aaaaaaaa-1111-2222-3333-444444444444"
	uuidB = "bbbbbbbb-1111-2222-3333-444444444444"
)

func TestPropertyScanAdd(t *testing.T) {
	s := NewPropertyScan()
	s.Add("Page A", 0, "Uuid", uuidA)
	s.Add("Page A#_subobject", 0, "Uuid", uuidA)                    // fragment folds into the page
	s.Add("Page A", 0, "UUID", uuidA)                               // duplicate via legacy property
	s.Add("User:Sandbox/temp", 2, "UUID", uuidB)                    // non-main namespace
	s.Add("Deferred", 0, "Uuid", PlaceholderUUID)                   // placeholder
	s.Add("Typo", 0, "UUID", "00000000-0000-0000-0000-00000000000") // malformed

	if got := s.Holders[uuidA]; !reflect.DeepEqual(got, []Holder{{"Page A", "Uuid"}}) {
		t.Errorf("holders for %s = %v", uuidA, got)
	}
	if _, held := s.Holders[uuidB]; held {
		t.Error("sandbox annotation must not own an index entry")
	}
	if len(s.Ignored) != 2 {
		t.Errorf("ignored = %v, want the sandbox and the placeholder", s.Ignored)
	}
	if len(s.Invalid) != 1 || s.Invalid[0].Page != "Typo" {
		t.Errorf("invalid = %v", s.Invalid)
	}
}

func TestPropertyScanKeepsModernLabelOverLegacy(t *testing.T) {
	s := NewPropertyScan()
	s.Add("Page A", 0, "UUID", uuidA)
	s.Add("Page A", 0, "Uuid", uuidA)
	if got := s.Holders[uuidA][0].Property; got != "Uuid" {
		t.Errorf("property label = %q, want the modern one", got)
	}
}

// scanWith builds a ScanResult from holder annotations and namespace pages.
func scanWith(t *testing.T, annotate func(*PropertyScan), pages ...NSPage) *ScanResult {
	t.Helper()
	props := NewPropertyScan()
	if annotate != nil {
		annotate(props)
	}
	return &ScanResult{Properties: props, Pages: pages}
}

func TestReconcileInSync(t *testing.T) {
	plan := Reconcile(scanWith(t,
		func(s *PropertyScan) { s.Add("Page A", 0, "Uuid", uuidA) },
		NSPage{Title: TitleFor(uuidA), Redirect: true, Target: "Page A"},
	), "api")
	if plan.Drift() || plan.InSync != 1 {
		t.Errorf("expected clean plan, got %+v", plan)
	}
}

func TestReconcileCreate(t *testing.T) {
	plan := Reconcile(scanWith(t,
		func(s *PropertyScan) { s.Add("Page A", 0, "Uuid", uuidA) },
	), "api")
	want := []Create{{uuidA, TitleFor(uuidA), "Page A"}}
	if !reflect.DeepEqual(plan.Create, want) {
		t.Errorf("create = %v, want %v", plan.Create, want)
	}
}

func TestReconcileRetargetAfterPageMove(t *testing.T) {
	plan := Reconcile(scanWith(t,
		func(s *PropertyScan) { s.Add("New Name", 0, "Uuid", uuidA) },
		NSPage{Title: TitleFor(uuidA), Redirect: true, Target: "Old Name"},
	), "api")
	want := []Retarget{{uuidA, TitleFor(uuidA), "Old Name", "New Name"}}
	if !reflect.DeepEqual(plan.Retarget, want) {
		t.Errorf("retarget = %v, want %v", plan.Retarget, want)
	}
}

func TestReconcileDeleteOrphanRedirect(t *testing.T) {
	plan := Reconcile(scanWith(t, nil,
		NSPage{Title: TitleFor(uuidA), Redirect: true, Target: "Removed Page"},
	), "api")
	want := []Delete{{TitleFor(uuidA), "Removed Page"}}
	if !reflect.DeepEqual(plan.Delete, want) {
		t.Errorf("delete = %v, want %v", plan.Delete, want)
	}
}

func TestReconcileLeavesNonRedirectsAlone(t *testing.T) {
	// The placeholder note page: valid uuid title, no holder, not a redirect.
	plan := Reconcile(scanWith(t, nil,
		NSPage{Title: "UUID:" + PlaceholderUUID, Redirect: false},
	), "api")
	if len(plan.Delete) != 0 {
		t.Errorf("must not delete non-redirect pages, got %v", plan.Delete)
	}
	if len(plan.Review) != 1 {
		t.Errorf("review = %v, want the placeholder flagged", plan.Review)
	}
}

func TestReconcileFlagsOccupiedTitle(t *testing.T) {
	// A non-redirect squatting on a title whose uuid is genuinely held.
	plan := Reconcile(scanWith(t,
		func(s *PropertyScan) { s.Add("Page A", 0, "Uuid", uuidA) },
		NSPage{Title: TitleFor(uuidA), Redirect: false},
	), "api")
	if plan.Drift() {
		t.Errorf("occupied title is review, not drift: %+v", plan)
	}
	if len(plan.Review) != 1 {
		t.Errorf("review = %v", plan.Review)
	}
}

func TestReconcileConflictActionsNothing(t *testing.T) {
	plan := Reconcile(scanWith(t,
		func(s *PropertyScan) {
			s.Add("Page A", 0, "Uuid", uuidA)
			s.Add("Page B", 0, "Uuid", uuidA)
		},
		NSPage{Title: TitleFor(uuidA), Redirect: true, Target: "Page A"},
	), "api")
	want := []Conflict{{uuidA, []string{"Page A", "Page B"}}}
	if !reflect.DeepEqual(plan.Conflicts, want) {
		t.Errorf("conflicts = %v, want %v", plan.Conflicts, want)
	}
	if plan.Drift() {
		t.Errorf("conflicted uuid must not produce actions: %+v", plan)
	}
}

func TestReconcileUnparsableTitleIsReviewNotDelete(t *testing.T) {
	plan := Reconcile(scanWith(t, nil,
		NSPage{Title: "UUID:00000000-0000-0000-0000-00000000000", Redirect: true, Target: "Somewhere"},
	), "api")
	if len(plan.Delete) != 0 {
		t.Errorf("unparsable titles must not be auto-deleted, got %v", plan.Delete)
	}
	if len(plan.Review) != 1 {
		t.Errorf("review = %v", plan.Review)
	}
}

func TestReconcileCaseVariantCollision(t *testing.T) {
	upper := "UUID:AAAAAAAA-1111-2222-3333-444444444444"
	plan := Reconcile(scanWith(t,
		func(s *PropertyScan) { s.Add("Page A", 0, "Uuid", uuidA) },
		NSPage{Title: TitleFor(uuidA), Redirect: true, Target: "Page A"},
		NSPage{Title: upper, Redirect: true, Target: "Page A"},
	), "api")
	if plan.Drift() {
		t.Errorf("collisions are review, not drift: %+v", plan)
	}
	if len(plan.Review) != 2 {
		t.Errorf("review = %v, want both variants flagged", plan.Review)
	}
}

func TestReconcileTracksLegacyPages(t *testing.T) {
	plan := Reconcile(scanWith(t,
		func(s *PropertyScan) {
			s.Add("Old Item", 0, "UUID", uuidA)
			s.Add("New Item", 0, "Uuid", uuidB)
		},
	), "api")
	if !reflect.DeepEqual(plan.LegacyPages, []string{"Old Item"}) {
		t.Errorf("legacy pages = %v", plan.LegacyPages)
	}
}
