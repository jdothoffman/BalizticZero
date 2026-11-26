package advise

import (
	"strings"
	"testing"
)

func TestPromptUsesTheSolvedNumbers(t *testing.T) {
	system, user := Prompt(Request{
		RangeYards:          800,
		ComeUpMOA:           18.25,
		WindageMOA:          3.4,
		WindSpeedMph:        10,
		StationPressureInHg: 24.9,
		HumidityPercent:     40,
	})
	if !strings.Contains(system, "already computed") {
		t.Fatalf("system prompt %q", system)
	}
	if !strings.Contains(user, "800 yd") || !strings.Contains(user, "18.25 MOA") {
		t.Fatalf("user prompt %q", user)
	}
	if !strings.Contains(user, "on call") {
		t.Fatalf("user prompt %q", user)
	}
}

func TestPromptDescribesTheRecordedImpact(t *testing.T) {
	_, user := Prompt(Request{RangeYards: 800, ImpactHighMOA: 0.4, ImpactRightMOA: -0.25})
	if !strings.Contains(user, "0.40 MOA high (3.4 in)") || !strings.Contains(user, "0.25 MOA left (2.1 in)") {
		t.Fatalf("user prompt %q", user)
	}
}

func TestPromptAsksForTheReviewWithoutNumbersInTheHeadline(t *testing.T) {
	system, _ := Prompt(Request{RangeYards: 800})
	for _, want := range []string{"verdict", "headline", "causes", "nextStep", "caution", "no numbers"} {
		if !strings.Contains(system, want) {
			t.Errorf("system prompt does not mention %q", want)
		}
	}
}

func TestPromptRoundsTheLocation(t *testing.T) {
	_, user := Prompt(Request{RangeYards: 800, LatitudeDegrees: 38.89768, LongitudeDegrees: -77.03653})
	if !strings.Contains(user, "Location: 38.90, -77.04") {
		t.Fatalf("user prompt %q", user)
	}
}
