package advise

import (
	"encoding/json"
	"fmt"
	"strings"
)

// Review is the structured answer the phone renders as a card. Every number on that card
// comes from the phone's own solver; the review only explains them in words.
type Review struct {
	Verdict  string  `json:"verdict"`
	Headline string  `json:"headline"`
	Causes   []Cause `json:"causes"`
	NextStep string  `json:"nextStep"`
	Caution  string  `json:"caution"`
}

// Cause is one factor that could explain the miss.
type Cause struct {
	Factor     string `json:"factor"`
	Likelihood string `json:"likelihood"`
	Note       string `json:"note"`
}

var (
	verdicts    = []string{"on_call", "within_call", "check_wind", "check_zero", "check_velocity"}
	factors     = []string{"wind", "spin_drift", "coriolis", "zero", "muzzle_velocity", "atmosphere", "shooter"}
	likelihoods = []string{"likely", "possible", "unlikely"}
)

// The schema cannot carry length limits, so ParseReview enforces these.
const (
	maxCauses   = 4
	maxHeadline = 160
	maxNote     = 220
	maxNextStep = 320
	maxCaution  = 220
)

// Schema is the JSON schema the provider's reply must match. Claude enforces it with
// structured outputs; ParseReview checks it again for any provider.
var Schema = json.RawMessage(mustSchema())

func mustSchema() []byte {
	schema := map[string]any{
		"type":                 "object",
		"additionalProperties": false,
		"required":             []string{"verdict", "headline", "causes", "nextStep", "caution"},
		"properties": map[string]any{
			"verdict":  map[string]any{"type": "string", "enum": verdicts},
			"headline": map[string]any{"type": "string"},
			"causes": map[string]any{
				"type": "array",
				"items": map[string]any{
					"type":                 "object",
					"additionalProperties": false,
					"required":             []string{"factor", "likelihood", "note"},
					"properties": map[string]any{
						"factor":     map[string]any{"type": "string", "enum": factors},
						"likelihood": map[string]any{"type": "string", "enum": likelihoods},
						"note":       map[string]any{"type": "string"},
					},
				},
			},
			"nextStep": map[string]any{"type": "string"},
			"caution":  map[string]any{"type": "string"},
		},
	}
	data, err := json.Marshal(schema)
	if err != nil {
		panic(err)
	}
	return data
}

// ParseReview reads the provider's reply. It rejects anything that does not match the
// schema, so the phone only ever receives fields it knows how to draw.
func ParseReview(text string) (Review, error) {
	dec := json.NewDecoder(strings.NewReader(stripFence(text)))
	dec.DisallowUnknownFields()
	var review Review
	if err := dec.Decode(&review); err != nil {
		return Review{}, fmt.Errorf("reply is not the review JSON: %w", err)
	}
	if dec.More() {
		return Review{}, fmt.Errorf("reply has text after the review JSON")
	}
	if !oneOf(review.Verdict, verdicts) {
		return Review{}, fmt.Errorf("unknown verdict %q", review.Verdict)
	}
	review.Headline = clip(review.Headline, maxHeadline)
	review.NextStep = clip(review.NextStep, maxNextStep)
	review.Caution = clip(review.Caution, maxCaution)
	if review.Headline == "" || review.NextStep == "" {
		return Review{}, fmt.Errorf("headline and nextStep are required")
	}
	if review.Causes == nil {
		review.Causes = []Cause{}
	}
	if len(review.Causes) > maxCauses {
		review.Causes = review.Causes[:maxCauses]
	}
	for i, cause := range review.Causes {
		if !oneOf(cause.Factor, factors) {
			return Review{}, fmt.Errorf("unknown factor %q", cause.Factor)
		}
		if !oneOf(cause.Likelihood, likelihoods) {
			return Review{}, fmt.Errorf("unknown likelihood %q", cause.Likelihood)
		}
		review.Causes[i].Note = clip(cause.Note, maxNote)
	}
	return review, nil
}

// stripFence removes a Markdown code fence, which a provider without schema
// enforcement may wrap around the JSON.
func stripFence(text string) string {
	text = strings.TrimSpace(text)
	if !strings.HasPrefix(text, "```") {
		return text
	}
	text = strings.TrimPrefix(text, "```")
	if newline := strings.IndexByte(text, '\n'); newline >= 0 {
		text = text[newline+1:]
	}
	return strings.TrimSpace(strings.TrimSuffix(strings.TrimSpace(text), "```"))
}

func oneOf(value string, allowed []string) bool {
	for _, a := range allowed {
		if value == a {
			return true
		}
	}
	return false
}

// clip trims whitespace and shortens text past limit runes, ending on a word.
func clip(text string, limit int) string {
	text = strings.TrimSpace(text)
	runes := []rune(text)
	if len(runes) <= limit {
		return text
	}
	cut := string(runes[:limit-1])
	if space := strings.LastIndexByte(cut, ' '); space > limit/2 {
		cut = cut[:space]
	}
	return strings.TrimRight(cut, " ,;:.") + "…"
}
