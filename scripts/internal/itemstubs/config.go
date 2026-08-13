package itemstubs

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
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
	// Navplate names the type navplate ({{Navplate <value>}}); empty omits it.
	Navplate string `json:"navplate,omitempty"`
}

// PatternRule matches items by name or class name. Class checks are exact;
// name checks are case-insensitive (dump names vary freely in case).
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
// article. ByPrefix wins over the dump's own data (it exists for items whose
// manufacturer field is missing or wrong); Renames fix stale dump codes.
type Manufacturers struct {
	Renames  map[string]string `json:"renames,omitempty"`
	ByPrefix map[string]string `json:"byPrefix,omitempty"`
	ByName   map[string]string `json:"byName,omitempty"`
	// Names maps a code to its wiki article title; missing codes fall back to
	// the dump's own manufacturer name.
	Names map[string]string `json:"names,omitempty"`
	// OmitInLead lists codes whose "manufactured by" clause and navplate are
	// dropped (UNKN, generic consumable makers): a lead linking [[Consumable]]
	// as a company would be wrong.
	OmitInLead []string `json:"omitInLead,omitempty"`
	// Aliases suppress known-legitimate disagreements between the code in a
	// class name and the resolved manufacturer, keyed classToken -> resolved
	// code (Mirai's items still carry MISC class names from before the
	// rename). A pair listed here is not reported as a mismatch.
	Aliases map[string]string `json:"aliases,omitempty"`
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

// ParseConfig decodes and validates a config document. Unknown fields are
// errors: a typoed key silently doing nothing is how allowlists rot.
func ParseConfig(b []byte) (*Config, error) {
	dec := json.NewDecoder(bytes.NewReader(b))
	dec.DisallowUnknownFields()
	var cfg Config
	if err := dec.Decode(&cfg); err != nil {
		return nil, fmt.Errorf("itemstubs config: %w", err)
	}
	if err := cfg.validate(); err != nil {
		return nil, fmt.Errorf("itemstubs config: %w", err)
	}
	return &cfg, nil
}

// LoadConfig reads and parses a config file.
func LoadConfig(path string) (*Config, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return ParseConfig(b)
}

func (c *Config) validate() error {
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
		if rule.Label == "" {
			return fmt.Errorf("type %q: label is required", typ)
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
	return nil
}
