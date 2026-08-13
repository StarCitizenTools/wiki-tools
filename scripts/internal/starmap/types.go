// Package starmap fetches the ARK Starmap and renders it as the JSON stored at
// Module:Starmap/starmap.json on the Star Citizen Wiki.
//
// Struct field order is significant: encoding/json emits fields in declaration
// order, and that order is the wire format the wiki page is compared against.
// Do not reorder fields without intending to rewrite the page.
//
// These structs were derived from the live payload, not from the type
// declarations in the TypeScript generator this replaces. Those declarations
// are incomplete — ITunnelPortal omits distance, latitude, longitude and type,
// which the API does return. TypeScript passed the objects through untouched at
// runtime so the omissions were invisible there; Go would silently drop them.
package starmap

import (
	"bytes"
	"encoding/json"
	"fmt"
	"strconv"
)

// Number is a JSON number that tolerates being delivered as a string.
//
// The Starmap API is inconsistent: aggregated_size and the sensor_* fields
// arrive quoted ("12.79000000", "4"), while the other aggregates arrive bare.
// Both must serialise back out as bare numbers.
type Number float64

// UnmarshalJSON accepts a bare number, a quoted number, or null.
func (n *Number) UnmarshalJSON(b []byte) error {
	b = bytes.TrimSpace(b)
	if len(b) == 0 || string(b) == "null" {
		*n = 0
		return nil
	}
	if b[0] == '"' {
		var s string
		if err := json.Unmarshal(b, &s); err != nil {
			return err
		}
		if s == "" {
			*n = 0
			return nil
		}
		f, err := strconv.ParseFloat(s, 64)
		if err != nil {
			return fmt.Errorf("starmap: %q is not numeric: %w", s, err)
		}
		*n = Number(f)
		return nil
	}
	var f float64
	if err := json.Unmarshal(b, &f); err != nil {
		return err
	}
	*n = Number(f)
	return nil
}

// Number deliberately has no MarshalJSON method. encoding/json's own float
// encoder is ECMAScript-compatible — shortest round-tripping representation,
// switching to exponent form only below 1e-6 or at/above 1e21 — which is what
// JSON.stringify produced for the values already on the wiki. Supplying a
// marshaller here using strconv 'g' formatting silently rewrote large values
// such as a planet's size from 3458865.2579 to 3.4588652579e+06.

// ---------------------------------------------------------------------------
// Output shapes — these define the JSON written to the wiki.
// ---------------------------------------------------------------------------

// Affiliation is a faction membership. The membership.id key is an internal
// join-row identifier that churns between snapshots without meaning anything.
type Affiliation struct {
	ID           int     `json:"id"`
	Code         string  `json:"code"`
	Color        string  `json:"color"`
	Name         string  `json:"name"`
	MembershipID float64 `json:"membership.id"`
}

// Subtype classifies an object below its top-level type.
type Subtype struct {
	ID   *int   `json:"id"`
	Name string `json:"name"`
	Type string `json:"type"`
}

// SystemRef is the denormalised system stamped onto every object.
type SystemRef struct {
	ID     int    `json:"id"`
	Code   string `json:"code"`
	Name   string `json:"name"`
	Type   string `json:"type"`
	Status string `json:"status"`
}

// ParentRef is the denormalised parent body of an object.
type ParentRef struct {
	ID          int     `json:"id"`
	Code        string  `json:"code"`
	Designation *string `json:"designation"`
	Name        *string `json:"name"`
	Type        string  `json:"type"`
}

// TunnelPortal is one end of a jump tunnel.
type TunnelPortal struct {
	ID           int     `json:"id"`
	Code         string  `json:"code"`
	Designation  *string `json:"designation"`
	Distance     Number  `json:"distance"`
	Latitude     *Number `json:"latitude"`
	Longitude    *Number `json:"longitude"`
	Name         *string `json:"name"`
	StarSystemID int     `json:"star_system_id"`
	Status       string  `json:"status"`
	Type         string  `json:"type"`
}

// Tunnel is a jump point pair.
type Tunnel struct {
	ID        int           `json:"id"`
	Direction string        `json:"direction"`
	EntryID   int           `json:"entry_id"`
	ExitID    int           `json:"exit_id"`
	Name      *string       `json:"name"`
	Size      *string       `json:"size"`
	Entry     *TunnelPortal `json:"entry"`
	Exit      *TunnelPortal `json:"exit"`
}

// System is a star system as written to the wiki.
type System struct {
	ID                   int           `json:"id"`
	Code                 string        `json:"code"`
	Description          string        `json:"description"`
	InfoURL              *string       `json:"info_url"`
	Name                 string        `json:"name"`
	Status               string        `json:"status"`
	Type                 string        `json:"type"`
	Affiliation          []Affiliation `json:"affiliation"`
	AggregatedSize       Number        `json:"aggregated_size"`
	AggregatedPopulation Number        `json:"aggregated_population"`
	AggregatedEconomy    Number        `json:"aggregated_economy"`
	AggregatedDanger     Number        `json:"aggregated_danger"`
}

// Object is a celestial object as written to the wiki.
type Object struct {
	ID               int           `json:"id"`
	Age              *Number       `json:"age"`
	AxialTilt        *Number       `json:"axial_tilt"`
	FairChanceAct    *bool         `json:"fairchanceact"`
	Code             string        `json:"code"`
	Description      *string       `json:"description"`
	Designation      *string       `json:"designation"`
	Habitable        *bool         `json:"habitable"`
	InfoURL          *string       `json:"info_url"`
	Name             *string       `json:"name"`
	OrbitPeriod      *Number       `json:"orbit_period"`
	SensorDanger     Number        `json:"sensor_danger"`
	SensorEconomy    Number        `json:"sensor_economy"`
	SensorPopulation Number        `json:"sensor_population"`
	Size             *Number       `json:"size"`
	Type             string        `json:"type"`
	Subtype          *Subtype      `json:"subtype"`
	Affiliation      []Affiliation `json:"affiliation"`
	StarSystemID     int           `json:"star_system_id"`
	StarSystem       SystemRef     `json:"star_system"`
	ParentID         *int          `json:"parent_id"`
	Parent           *ParentRef    `json:"parent"`
	Tunnel           *Tunnel       `json:"tunnel"`
}

// Document is the top-level file written to Module:Starmap/starmap.json.
type Document struct {
	Systems []System `json:"systems"`
	Objects []Object `json:"objects"`
}

// ---------------------------------------------------------------------------
// Upstream shapes — what the API returns.
// ---------------------------------------------------------------------------

// apiSystem is a star system as delivered by /star-systems/{code}.
type apiSystem struct {
	ID                   int           `json:"id"`
	Code                 string        `json:"code"`
	Description          string        `json:"description"`
	InfoURL              *string       `json:"info_url"`
	Name                 string        `json:"name"`
	Status               string        `json:"status"`
	Type                 string        `json:"type"`
	Affiliation          []Affiliation `json:"affiliation"`
	AggregatedSize       Number        `json:"aggregated_size"`
	AggregatedPopulation Number        `json:"aggregated_population"`
	AggregatedEconomy    Number        `json:"aggregated_economy"`
	AggregatedDanger     Number        `json:"aggregated_danger"`
	CelestialObjects     []apiObject   `json:"celestial_objects"`
}

// apiObject is a celestial object as delivered by the API. Only the fields the
// output needs are decoded; the rest (shader_data, media, appearance, …) are
// intentionally dropped, matching the generator this replaces.
type apiObject struct {
	ID               int           `json:"id"`
	Age              *Number       `json:"age"`
	AxialTilt        *Number       `json:"axial_tilt"`
	FairChanceAct    *bool         `json:"fairchanceact"`
	Code             string        `json:"code"`
	Description      *string       `json:"description"`
	Designation      *string       `json:"designation"`
	Habitable        *bool         `json:"habitable"`
	InfoURL          *string       `json:"info_url"`
	Name             *string       `json:"name"`
	OrbitPeriod      *Number       `json:"orbit_period"`
	ParentID         *int          `json:"parent_id"`
	SensorDanger     Number        `json:"sensor_danger"`
	SensorEconomy    Number        `json:"sensor_economy"`
	SensorPopulation Number        `json:"sensor_population"`
	Size             *Number       `json:"size"`
	Type             string        `json:"type"`
	Subtype          *Subtype      `json:"subtype"`
	Affiliation      []Affiliation `json:"affiliation"`
	Children         []apiObject   `json:"children"`
}

// envelope is the standard API wrapper: {"success":1,"code":"OK","data":{…}}.
type envelope struct {
	Success int             `json:"success"`
	Code    string          `json:"code"`
	Msg     string          `json:"msg"`
	Data    json.RawMessage `json:"data"`
}
