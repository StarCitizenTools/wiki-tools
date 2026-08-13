package itemstubs

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"slices"
	"sort"
	"strings"
)

// Kind is a stub page layout: which canonical sections the page carries and
// whether the lead states the item's size.
type Kind struct {
	Sections []string `json:"sections"`
	LeadSize bool     `json:"leadSize,omitempty"`
}

// TypeRule is the allowlist entry for one dump Type ("WeaponGun.Gun").
// Skip=true records "decided: no pages" — distinct from an absent type, which
// means "nobody has decided" and is reported as unmapped on every run.
type TypeRule struct {
	Skip  bool   `json:"skip,omitempty"`
	Kind  string `json:"kind,omitempty"`
	Label string `json:"label,omitempty"`
	// LabelLink pipes the lead's label link ([[LabelLink|label]]) when the
	// article name differs from the label; empty links [[label]] directly.
	LabelLink string `json:"labelLink,omitempty"`
	// NoLabelLink renders the lead's label as plain text. Some labels have no
	// article to link ("deployable"), and a red link on every page of a type
	// is worse than an unlinked noun.
	NoLabelLink bool `json:"noLabelLink,omitempty"`
	// Navplate names the type navplate ({{Navplate <value>}}); empty omits it.
	Navplate string `json:"navplate,omitempty"`
}

// PatternRule matches items by name or class name. NameContains and
// DescContains are case-insensitive; NameExact, NamePrefixes and all class
// checks are case-sensitive.
type PatternRule struct {
	ID string `json:"id"`
	// NameExact matches the whole name. Short placeholder names ("PH") are
	// what it exists for: as a prefix or substring they would swallow real
	// items, and the dump has no other way to say "this name is a stand-in".
	NameExact     []string `json:"nameExact,omitempty"`
	NameContains  []string `json:"nameContains,omitempty"`
	NamePrefixes  []string `json:"namePrefixes,omitempty"`
	ClassContains []string `json:"classContains,omitempty"`
	ClassPrefixes []string `json:"classPrefixes,omitempty"`
	ClassSuffixes []string `json:"classSuffixes,omitempty"`
	// DescContains matches the dump's description, case-insensitively. It is
	// how built-in hardware announces itself ("bespoke", "designed
	// specifically for the …") when the name and class name do not.
	DescContains []string `json:"descContains,omitempty"`
	// DescPrefixes and DescSuffixes match the ends of the description, where
	// CIG's own stub markers live: a description opening "(PH)" or "PH " is
	// flagged provisional, and one closing " Description" is the shape of an
	// unwritten localisation string ("Schematic: Aegis Hammerhead
	// Description") rather than prose. Both are case-sensitive: the markers
	// are literal.
	DescPrefixes []string `json:"descPrefixes,omitempty"`
	DescSuffixes []string `json:"descSuffixes,omitempty"`
}

// Matches reports whether the rule matches an item's name, class name, or
// description.
func (r PatternRule) Matches(name, className, description string) bool {
	lower := strings.ToLower(name)
	lowerDesc := strings.ToLower(description)
	for _, s := range r.NameExact {
		if name == s {
			return true
		}
	}
	for _, s := range r.DescContains {
		if strings.Contains(lowerDesc, strings.ToLower(s)) {
			return true
		}
	}
	trimmedDesc := strings.TrimSpace(description)
	for _, s := range r.DescPrefixes {
		if strings.HasPrefix(trimmedDesc, s) {
			return true
		}
	}
	for _, s := range r.DescSuffixes {
		if strings.HasSuffix(trimmedDesc, s) {
			return true
		}
	}
	for _, s := range r.NameContains {
		if strings.Contains(lower, strings.ToLower(s)) {
			return true
		}
	}
	for _, p := range r.NamePrefixes {
		if strings.HasPrefix(name, p) {
			return true
		}
	}
	for _, s := range r.ClassContains {
		if strings.Contains(className, s) {
			return true
		}
	}
	for _, p := range r.ClassPrefixes {
		if strings.HasPrefix(className, p) {
			return true
		}
	}
	for _, s := range r.ClassSuffixes {
		if strings.HasSuffix(className, s) {
			return true
		}
	}
	return false
}

// Manufacturers configures how an item's maker resolves to a code and a wiki
// article. The dump's own code wins (after ByName/Renames); ByPrefix only
// fills in when that yields nothing usable ("" or "UNKN"), never overrides
// it. It used to override outright, and that silently discarded 73 real
// manufacturers on the 4.9 dump — srvl_ overwrote Doomsday 52 times, volt_
// overwrote Klaus & Werner 9 times, none_ overwrote Hurston Dynamics 3
// times — while the dump agreed with the prefix in 812 other cases; those
// disagreements now surface in the mismatch report instead of being thrown
// away. Renames fix stale dump codes.
type Manufacturers struct {
	Renames  map[string]string `json:"renames,omitempty"`
	ByPrefix map[string]string `json:"byPrefix,omitempty"`
	ByName   map[string]string `json:"byName,omitempty"`
	// OmitInLead lists codes whose "manufactured by" clause and navplate are
	// dropped (UNKN, generic consumable makers): a lead linking [[Consumable]]
	// as a company would be wrong.
	OmitInLead []string `json:"omitInLead,omitempty"`
	// Aliases suppress known-legitimate disagreements between the code in a
	// class name and the resolved manufacturer, keyed classToken -> resolved
	// code (Mirai's items still carry MISC class names from before the
	// rename). A pair listed here is not reported as a mismatch.
	Aliases map[string]string `json:"aliases,omitempty"`
	// Synthetic lists manufacturer codes this tool works with that are not in
	// the wiki's manufacturer registry because they are not real
	// manufacturers — sentinels for "no manufacturer" that the dump or this
	// tool's own rules produce (NONE from the none_ byPrefix rule, TBD from
	// the dump itself). Validate accepts these in place of a registry entry.
	Synthetic []string `json:"synthetic,omitempty"`
}

// Config is everything editorial about the tool, committed next to the
// command so scope changes are PR-reviewed data, not code.
type Config struct {
	Kinds         map[string]Kind     `json:"kinds"`
	Types         map[string]TypeRule `json:"types"`
	Blocklist     []PatternRule       `json:"blocklist,omitempty"`
	Review        []PatternRule       `json:"review,omitempty"`
	Manufacturers Manufacturers       `json:"manufacturers"`
}

// LabelFor resolves the label a type's stub lead should use: the rule's
// explicit Label when it has one, otherwise the wiki's own name for the
// type's base (everything before the first "."), lowercased. "" means
// neither source has an answer.
func (c *Config) LabelFor(dumpType string, reg *Registry) string {
	if rule, ok := c.Types[dumpType]; ok && rule.Label != "" {
		return rule.Label
	}
	base, _, _ := strings.Cut(dumpType, ".")
	return strings.ToLower(reg.TypeName(base))
}

// ParseConfig decodes and validates a config document against the wiki's
// registries. Unknown fields are errors: a typoed key silently doing nothing
// is how allowlists rot.
func ParseConfig(b []byte, reg *Registry) (*Config, error) {
	dec := json.NewDecoder(bytes.NewReader(b))
	dec.DisallowUnknownFields()
	var cfg Config
	if err := dec.Decode(&cfg); err != nil {
		return nil, fmt.Errorf("itemstubs config: %w", err)
	}
	if err := cfg.Validate(reg); err != nil {
		return nil, fmt.Errorf("itemstubs config: %w", err)
	}
	return &cfg, nil
}

// LoadConfig reads and parses a config file against the wiki's registries.
func LoadConfig(path string, reg *Registry) (*Config, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return ParseConfig(b, reg)
}

// Validate checks the config for internal consistency and against the wiki's
// registries: every active type must resolve to a label (explicit or via the
// registry) and must not carry a label that merely restates the registry's
// name — that entry is a copy waiting to drift, and should be deleted so it
// tracks the registry instead.
func (c *Config) Validate(reg *Registry) error {
	for name, kind := range c.Kinds {
		for _, section := range kind.Sections {
			if _, ok := sectionBody[section]; !ok {
				return fmt.Errorf("kind %q: unknown section %q", name, section)
			}
		}
	}
	for typ, rule := range c.Types {
		if rule.Skip {
			if rule.Kind != "" || rule.Label != "" {
				return fmt.Errorf("type %q: skip entries must not carry kind or label", typ)
			}
			continue
		}
		if _, ok := c.Kinds[rule.Kind]; !ok {
			return fmt.Errorf("type %q: unknown kind %q", typ, rule.Kind)
		}
		if c.LabelFor(typ, reg) == "" {
			return fmt.Errorf("type %q: no label (set an explicit label, or add its base type to the types registry)", typ)
		}
		if rule.Label != "" {
			// Case-only differences are allowed: LabelFor lowercases the
			// registry's name, which is right for "Arm armor" and wrong for a
			// brand like mobiGlas, whose article is not "Mobiglas". Only an
			// exact copy is redundant.
			base, _, _ := strings.Cut(typ, ".")
			if derived := reg.TypeName(base); derived != "" && rule.Label == strings.ToLower(derived) {
				return fmt.Errorf("type %q: label %q duplicates the registry's name for %q; remove the label so it tracks the registry", typ, rule.Label, base)
			}
		}
		if rule.LabelLink != "" && rule.NoLabelLink {
			return fmt.Errorf("type %q: labelLink and noLabelLink are mutually exclusive", typ)
		}
	}
	seen := map[string]bool{}
	for _, list := range [][]PatternRule{c.Blocklist, c.Review} {
		for _, rule := range list {
			if rule.ID == "" {
				return fmt.Errorf("pattern rule without id")
			}
			if seen[rule.ID] {
				return fmt.Errorf("duplicate pattern rule id %q", rule.ID)
			}
			seen[rule.ID] = true
		}
	}
	// A code referenced by one of these maps' values, or listed in
	// omitInLead, but absent from the manufacturer registry (and not
	// declared synthetic) is a typo: today it silently falls back to the
	// dump's own manufacturer name instead of failing, so the map appears to
	// work while doing nothing.
	known := func(code string) bool {
		if _, ok := reg.Manufacturers[code]; ok {
			return true
		}
		return slices.Contains(c.Manufacturers.Synthetic, code)
	}
	for _, ref := range []struct {
		field string
		m     map[string]string
	}{
		{"renames", c.Manufacturers.Renames},
		{"byPrefix", c.Manufacturers.ByPrefix},
		{"byName", c.Manufacturers.ByName},
		{"aliases", c.Manufacturers.Aliases},
	} {
		keys := make([]string, 0, len(ref.m))
		for k := range ref.m {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, k := range keys {
			code := ref.m[k]
			if !known(code) {
				return fmt.Errorf("manufacturers.%s: code %q is not in the manufacturers registry or manufacturers.synthetic", ref.field, code)
			}
		}
	}
	for _, code := range c.Manufacturers.OmitInLead {
		if !known(code) {
			return fmt.Errorf("manufacturers.omitInLead: code %q is not in the manufacturers registry or manufacturers.synthetic", code)
		}
	}
	return nil
}
