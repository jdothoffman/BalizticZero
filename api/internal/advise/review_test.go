package advise

import (
	"encoding/json"
	"strings"
	"testing"
	"unicode/utf8"
)

const goodReview = `{
	"verdict": "check_wind",
	"headline": "The miss follows the wind, not the dope.",
	"causes": [
		{"factor": "wind", "likelihood": "likely", "note": "A gust would push it this far."},
		{"factor": "shooter", "likelihood": "possible", "note": "A pulled shot looks the same."}
	],
	"nextStep": "Watch the mirage and hold the call.",
	"caution": ""
}`

func TestParseReviewAcceptsTheSchema(t *testing.T) {
	review, err := ParseReview(goodReview)
	if err != nil {
		t.Fatal(err)
	}
	if review.Verdict != "check_wind" || len(review.Causes) != 2 || review.Causes[1].Factor != "shooter" {
		t.Fatalf("review %+v", review)
	}
}

func TestParseReviewToleratesACodeFence(t *testing.T) {
	if _, err := ParseReview("```json\n" + goodReview + "\n```"); err != nil {
		t.Fatal(err)
	}
}

func TestParseReviewRejectsWhatThePhoneCannotDraw(t *testing.T) {
	cases := map[string]string{
		"plain text":        "The wind did it.",
		"unknown verdict":   strings.Replace(goodReview, `"check_wind"`, `"dial_up"`, 1),
		"unknown factor":    strings.Replace(goodReview, `"shooter"`, `"ammo"`, 1),
		"unknown field":     strings.Replace(goodReview, `"caution": ""`, `"caution": "", "dial": "2.1"`, 1),
		"missing headline":  strings.Replace(goodReview, `"The miss follows the wind, not the dope."`, `"  "`, 1),
		"bad likelihood":    strings.Replace(goodReview, `"possible"`, `"certain"`, 1),
		"trailing text":     goodReview + " and more",
		"two json objects":  goodReview + goodReview,
		"missing next step": strings.Replace(goodReview, `"Watch the mirage and hold the call."`, `""`, 1),
	}
	for name, text := range cases {
		t.Run(name, func(t *testing.T) {
			if _, err := ParseReview(text); err == nil {
				t.Fatal("accepted")
			}
		})
	}
}

func TestParseReviewCapsCausesAndLength(t *testing.T) {
	cause := `{"factor":"wind","likelihood":"possible","note":"` + strings.Repeat("gusting wind ", 40) + `"}`
	text := `{"verdict":"within_call","headline":"` + strings.Repeat("word ", 60) + `",
		"causes":[` + strings.Repeat(cause+",", 5) + cause + `],
		"nextStep":"Fire again.","caution":""}`
	review, err := ParseReview(text)
	if err != nil {
		t.Fatal(err)
	}
	if len(review.Causes) != maxCauses {
		t.Fatalf("%d causes", len(review.Causes))
	}
	if n := utf8.RuneCountInString(review.Headline); n > maxHeadline || !strings.HasSuffix(review.Headline, "…") {
		t.Fatalf("headline %d runes: %q", n, review.Headline)
	}
	if n := utf8.RuneCountInString(review.Causes[0].Note); n > maxNote {
		t.Fatalf("note %d runes", n)
	}
}

func TestParseReviewAlwaysReturnsACauseList(t *testing.T) {
	review, err := ParseReview(`{"verdict":"on_call","headline":"Good hit.","causes":[],"nextStep":"Keep the dial.","caution":""}`)
	if err != nil {
		t.Fatal(err)
	}
	body, _ := json.Marshal(review)
	if !strings.Contains(string(body), `"causes":[]`) {
		t.Fatalf("causes must encode as a list, got %s", body)
	}
}

// Structured outputs reject numeric and length constraints, and need additionalProperties false on every object.
func TestSchemaUsesOnlyWhatStructuredOutputsSupport(t *testing.T) {
	var schema map[string]any
	if err := json.Unmarshal(Schema, &schema); err != nil {
		t.Fatal(err)
	}
	var walk func(node map[string]any, path string)
	walk = func(node map[string]any, path string) {
		for _, banned := range []string{"minimum", "maximum", "minLength", "maxLength", "minItems", "maxItems"} {
			if _, ok := node[banned]; ok {
				t.Errorf("%s uses %s", path, banned)
			}
		}
		if node["type"] == "object" && node["additionalProperties"] != false {
			t.Errorf("%s needs additionalProperties: false", path)
		}
		if props, ok := node["properties"].(map[string]any); ok {
			for name, child := range props {
				walk(child.(map[string]any), path+"."+name)
			}
		}
		if items, ok := node["items"].(map[string]any); ok {
			walk(items, path+"[]")
		}
	}
	walk(schema, "$")
}
