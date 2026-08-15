package starmap

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sort"
	"strings"
	"sync"

	"github.com/StarCitizenTools/wiki-tools/scripts/internal/httpx"
)

// BaseURL is the ARK Starmap API root.
const BaseURL = "https://robertsspaceindustries.com/api/starmap"

// knownSystemKeys and knownObjectKeys record every field we have seen upstream,
// whether or not the output uses it. Anything outside these sets is new, and is
// reported as schema drift.
//
// This is the early-warning the previous generator lacked: it silently ignored
// unknown fields, so upstream changes only surfaced when someone diffed the
// output by hand.
var knownSystemKeys = newSet(
	"id", "code", "description", "info_url", "name", "status", "type",
	"affiliation", "aggregated_size", "aggregated_population",
	"aggregated_economy", "aggregated_danger", "celestial_objects",
	"frost_line", "habitable_zone_inner", "habitable_zone_outer",
	"position_x", "position_y", "position_z", "shader_data", "thumbnail",
	"time_modified",
)

var knownObjectKeys = newSet(
	"affiliation", "age", "appearance", "axial_tilt", "children", "code",
	"description", "designation", "distance", "fairchanceact", "habitable",
	"id", "info_url", "latitude", "longitude", "media", "model", "name",
	"orbit_period", "parent_id", "population", "sensor_danger",
	"sensor_economy", "sensor_population", "shader_data", "show_label",
	"show_orbitlines", "size", "subtype", "subtype_id", "texture",
	"thumbnail", "time_modified", "type",
)

func newSet(keys ...string) map[string]struct{} {
	s := make(map[string]struct{}, len(keys))
	for _, k := range keys {
		s[k] = struct{}{}
	}
	return s
}

// Options configures a generation run.
type Options struct {
	// Concurrency is how many systems are processed at once.
	Concurrency int
	// Client issues the (rate-limited) HTTP requests.
	Client *httpx.Client
	// Progress, when set, receives human-readable progress lines.
	Progress func(string)
}

// Result is a completed generation.
type Result struct {
	Document *Document
	// Drift lists upstream fields this tool does not know about, sorted.
	Drift []string
	// Requests counts API calls made.
	Requests int
}

// generator holds per-run state.
type generator struct {
	opts     Options
	mu       sync.Mutex
	drift    map[string]struct{}
	requests int
}

func (g *generator) logf(format string, args ...any) {
	if g.opts.Progress != nil {
		g.opts.Progress(fmt.Sprintf(format, args...))
	}
}

// noteDrift records an unrecognised upstream field.
func (g *generator) noteDrift(shape string, keys map[string]json.RawMessage, known map[string]struct{}) {
	for k := range keys {
		if _, ok := known[k]; ok {
			continue
		}
		g.mu.Lock()
		g.drift[shape+"."+k] = struct{}{}
		g.mu.Unlock()
	}
}

// get issues a POST and unwraps the API envelope.
func (g *generator) get(ctx context.Context, path string) (json.RawMessage, error) {
	body, err := g.opts.Client.Do(ctx, http.MethodPost, BaseURL+path, "")
	if err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	g.mu.Lock()
	g.requests++
	g.mu.Unlock()

	var env envelope
	if err := json.Unmarshal(body, &env); err != nil {
		return nil, fmt.Errorf("%s: decoding envelope: %w", path, err)
	}
	if env.Success != 1 {
		return nil, fmt.Errorf("%s: starmap error: %s", path, env.Msg)
	}
	return env.Data, nil
}

// Generate fetches the whole starmap and builds the output document.
func Generate(ctx context.Context, opts Options) (*Result, error) {
	if opts.Client == nil {
		return nil, fmt.Errorf("starmap: an HTTP client is required")
	}
	if opts.Concurrency < 1 {
		opts.Concurrency = 4
	}
	g := &generator{opts: opts, drift: map[string]struct{}{}}

	// --- bootup: the system roster and every tunnel -------------------------
	bootRaw, err := g.get(ctx, "/bootup")
	if err != nil {
		return nil, err
	}
	var boot struct {
		Systems struct {
			Resultset []struct {
				Code string `json:"code"`
			} `json:"resultset"`
		} `json:"systems"`
		Tunnels struct {
			Resultset []Tunnel `json:"resultset"`
		} `json:"tunnels"`
	}
	if err := json.Unmarshal(bootRaw, &boot); err != nil {
		return nil, fmt.Errorf("decoding bootup: %w", err)
	}
	codes := make([]string, 0, len(boot.Systems.Resultset))
	for _, s := range boot.Systems.Resultset {
		codes = append(codes, s.Code)
	}
	g.logf("bootup: %d systems, %d tunnels", len(codes), len(boot.Tunnels.Resultset))

	// Index tunnels by the object id at either end. Iterating in upstream order
	// and keeping the first match preserves the previous generator's semantics
	// (Array.prototype.find returns the earliest hit).
	tunnelByObject := make(map[int]*Tunnel, len(boot.Tunnels.Resultset)*2)
	for i := range boot.Tunnels.Resultset {
		t := &boot.Tunnels.Resultset[i]
		for _, id := range [2]int{t.EntryID, t.ExitID} {
			if _, seen := tunnelByObject[id]; !seen {
				tunnelByObject[id] = t
			}
		}
	}

	// --- systems, processed concurrently ------------------------------------
	type slot struct {
		system  System
		objects []Object
		err     error
	}
	slots := make([]slot, len(codes))

	sem := make(chan struct{}, opts.Concurrency)
	var wg sync.WaitGroup
	var done int
	for i, code := range codes {
		wg.Add(1)
		go func(i int, code string) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			if ctx.Err() != nil {
				slots[i].err = ctx.Err()
				return
			}
			sys, objs, err := g.fetchSystem(ctx, code, tunnelByObject)
			slots[i] = slot{system: sys, objects: objs, err: err}

			g.mu.Lock()
			done++
			n := done
			g.mu.Unlock()
			g.logf("fetched %s (%d/%d)", code, n, len(codes))
		}(i, code)
	}
	wg.Wait()

	doc := &Document{Systems: make([]System, 0, len(codes))}
	for i, s := range slots {
		if s.err != nil {
			return nil, fmt.Errorf("system %s: %w", codes[i], s.err)
		}
		doc.Systems = append(doc.Systems, s.system)
		doc.Objects = append(doc.Objects, s.objects...)
	}

	// Deterministic output: sort by upper-cased code, as the wiki file is.
	// Every code is ASCII, so byte ordering matches the JavaScript comparison
	// the previous generator used.
	sort.SliceStable(doc.Systems, func(a, b int) bool {
		return strings.ToUpper(doc.Systems[a].Code) < strings.ToUpper(doc.Systems[b].Code)
	})
	sort.SliceStable(doc.Objects, func(a, b int) bool {
		return strings.ToUpper(doc.Objects[a].Code) < strings.ToUpper(doc.Objects[b].Code)
	})

	drift := make([]string, 0, len(g.drift))
	for k := range g.drift {
		drift = append(drift, k)
	}
	sort.Strings(drift)

	return &Result{Document: doc, Drift: drift, Requests: g.requests}, nil
}

// fetchSystem loads one system and every object belonging to it.
func (g *generator) fetchSystem(ctx context.Context, code string, tunnels map[int]*Tunnel) (System, []Object, error) {
	raw, err := g.get(ctx, "/star-systems/"+code)
	if err != nil {
		return System{}, nil, err
	}

	// Decode twice: once into the typed shape, once loosely to spot new fields.
	var typed struct {
		Resultset []apiSystem `json:"resultset"`
	}
	if err := json.Unmarshal(raw, &typed); err != nil {
		return System{}, nil, fmt.Errorf("decoding system: %w", err)
	}
	if len(typed.Resultset) == 0 {
		return System{}, nil, fmt.Errorf("empty resultset")
	}
	sys := typed.Resultset[0]
	g.inspectSystem(raw)

	out := System{
		ID:                   sys.ID,
		Code:                 sys.Code,
		Description:          sys.Description,
		InfoURL:              sys.InfoURL,
		Name:                 sys.Name,
		Status:               sys.Status,
		Type:                 sys.Type,
		Affiliation:          orEmpty(sys.Affiliation),
		AggregatedSize:       sys.AggregatedSize,
		AggregatedPopulation: sys.AggregatedPopulation,
		AggregatedEconomy:    sys.AggregatedEconomy,
		// The generator this replaces wrote aggregated_economy here, so every
		// system's danger reading was really its economy reading.
		AggregatedDanger: sys.AggregatedDanger,
	}

	ref := SystemRef{ID: sys.ID, Code: sys.Code, Name: sys.Name, Type: sys.Type, Status: sys.Status}

	byID := make(map[int]*apiObject, len(sys.CelestialObjects))
	for i := range sys.CelestialObjects {
		byID[sys.CelestialObjects[i].ID] = &sys.CelestialObjects[i]
	}

	objects := make([]Object, 0, len(sys.CelestialObjects))
	for i := range sys.CelestialObjects {
		src := &sys.CelestialObjects[i]

		var parent *apiObject
		if src.ParentID != nil {
			parent = byID[*src.ParentID]
		}
		obj := buildObject(src, ref, parent, tunnels[src.ID])

		// Planetary moons are re-labelled as their own type. Applied only here,
		// matching the previous generator, which did not apply it to the
		// children fetched below.
		if obj.Subtype != nil && obj.Subtype.Name == "Planetary Moon" {
			obj.Subtype.Type = "MOON"
			obj.Subtype.ID = nil
		}
		objects = append(objects, obj)

		if src.Type != "PLANET" {
			continue
		}

		// A planet's moons are not included in the system payload, so fetch the
		// planet on its own and take any child we have not already seen.
		childRaw, err := g.get(ctx, "/celestial-objects/"+src.Code)
		if err != nil {
			return System{}, nil, err
		}
		var childDoc struct {
			Resultset []apiObject `json:"resultset"`
		}
		if err := json.Unmarshal(childRaw, &childDoc); err != nil {
			return System{}, nil, fmt.Errorf("decoding %s: %w", src.Code, err)
		}
		if len(childDoc.Resultset) == 0 {
			continue
		}
		for j := range childDoc.Resultset[0].Children {
			child := &childDoc.Resultset[0].Children[j]
			if _, seen := byID[child.ID]; seen {
				continue
			}
			objects = append(objects, buildObject(child, ref, src, nil))
		}
	}

	return out, objects, nil
}

// inspectSystem reports unrecognised fields on a system payload and its objects.
func (g *generator) inspectSystem(raw json.RawMessage) {
	var loose struct {
		Resultset []map[string]json.RawMessage `json:"resultset"`
	}
	if err := json.Unmarshal(raw, &loose); err != nil || len(loose.Resultset) == 0 {
		return
	}
	g.noteDrift("system", loose.Resultset[0], knownSystemKeys)

	if objsRaw, ok := loose.Resultset[0]["celestial_objects"]; ok {
		var objs []map[string]json.RawMessage
		if err := json.Unmarshal(objsRaw, &objs); err == nil {
			for _, o := range objs {
				g.noteDrift("object", o, knownObjectKeys)
			}
		}
	}
}

// buildObject maps an upstream object onto the output shape.
func buildObject(src *apiObject, system SystemRef, parent *apiObject, tunnel *Tunnel) Object {
	obj := Object{
		ID:               src.ID,
		Age:              src.Age,
		AxialTilt:        src.AxialTilt,
		FairChanceAct:    src.FairChanceAct,
		Code:             src.Code,
		Description:      src.Description,
		Designation:      src.Designation,
		Distance:         src.Distance,
		Habitable:        src.Habitable,
		InfoURL:          src.InfoURL,
		Name:             src.Name,
		OrbitPeriod:      src.OrbitPeriod,
		SensorDanger:     src.SensorDanger,
		SensorEconomy:    src.SensorEconomy,
		SensorPopulation: src.SensorPopulation,
		Size:             src.Size,
		Type:             src.Type,
		Affiliation:      orEmpty(src.Affiliation),
		StarSystemID:     system.ID,
		StarSystem:       system,
		ParentID:         src.ParentID,
		Tunnel:           tunnel,
	}
	if src.Subtype != nil {
		st := *src.Subtype // copy, so the moon re-label cannot leak across objects
		obj.Subtype = &st
	}
	if parent != nil {
		obj.Parent = &ParentRef{
			ID:          parent.ID,
			Code:        parent.Code,
			Designation: parent.Designation,
			Name:        parent.Name,
			Type:        parent.Type,
		}
	}
	return obj
}

// orEmpty keeps an absent list serialising as [] rather than null, matching the
// existing page.
func orEmpty(a []Affiliation) []Affiliation {
	if a == nil {
		return []Affiliation{}
	}
	return a
}

// Encode renders the document exactly as MediaWiki stores it: tab-indented,
// with &, < and > escaped. Go's encoding/json escapes those three by default,
// which is the same set MediaWiki's JSON content model escapes, so the bytes
// this produces match the page content byte for byte.
func Encode(doc *Document) ([]byte, error) {
	b, err := json.MarshalIndent(doc, "", "\t")
	if err != nil {
		return nil, err
	}
	return append(b, '\n'), nil
}
