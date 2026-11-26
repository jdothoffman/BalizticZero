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
}
