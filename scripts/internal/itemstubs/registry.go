package itemstubs

import (
	"encoding/json"
	"fmt"
	"os"
)

// ManufacturerRecord is one entry of Module:Manufacturers/data.json: the
// wiki's canonical record for a manufacturer code.
type ManufacturerRecord struct {
	Name  string `json:"name"`
	Short string `json:"short,omitempty"`
	// Page is the wiki article to link when it differs from Name — e.g. ARCC's
	// Name is "ArcCorp" but its Page is "ArcCorp (company)", because
	// "ArcCorp" the article is the planet.
	Page string `json:"page,omitempty"`
}

// TypeRecord is one entry of Module:Entity/Item/types.json: the wiki's
// canonical display name and category for a dump BaseType.
type TypeRecord struct {
	Name     string `json:"name"`
	Category string `json:"category"`
}

// Registry is the wiki's own reference data, read from the module pages this
// repo already maintains. itemstubs reads them rather than copying them: a
// copy drifts, and one already had — ArcCorp's article is "ArcCorp (company)"
// because "ArcCorp" is the planet, which a flat code-to-name map cannot say.
type Registry struct {
	Manufacturers map[string]ManufacturerRecord
	Types         map[string]TypeRecord
}

// ManufacturerPage returns the wiki article to link for a manufacturer code:
// its Page when set, else its Name, else "" when the code has no record.
func (r *Registry) ManufacturerPage(code string) string {
	rec, ok := r.Manufacturers[code]
	if !ok {
		return ""
	}
	if rec.Page != "" {
		return rec.Page
	}
	return rec.Name
}

// TypeName returns the wiki's display name for a dump BaseType (the part of
// Type before the first "."), or "" when the base type has no record.
func (r *Registry) TypeName(baseType string) string {
	return r.Types[baseType].Name
}

// LoadRegistry reads and decodes both registry files.
func LoadRegistry(manufacturersPath, typesPath string) (*Registry, error) {
	var reg Registry
	if err := loadJSONFile(manufacturersPath, &reg.Manufacturers); err != nil {
		return nil, fmt.Errorf("itemstubs: manufacturers registry %s: %w", manufacturersPath, err)
	}
	if err := loadJSONFile(typesPath, &reg.Types); err != nil {
		return nil, fmt.Errorf("itemstubs: types registry %s: %w", typesPath, err)
	}
	return &reg, nil
}

func loadJSONFile(path string, v any) error {
	b, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(b, v)
}
