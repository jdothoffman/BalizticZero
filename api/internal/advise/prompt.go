package advise

import (
	"fmt"
	"math"
)

const systemPrompt = `You are the shooting advisor for Baliztic Zero. The shooter fired the correction the on-device solver already computed, then recorded where the round hit relative to the point of aim. Review that impact.

Reply with only a JSON object with these fields:
- verdict: "on_call" when the impact is within normal dispersion at this range. "within_call" when the miss is small next to the wind call and ordinary wind variation explains it. "check_wind", "check_zero" or "check_velocity" when the miss points at that input and the shooter should confirm it before changing anything.
- headline: one plain sentence for the top of the card. Use no numbers or units; the app shows the measurements beside it.
- causes: up to four factors that could explain the miss, most likely first. Each has a factor, a likelihood ("likely", "possible" or "unlikely") and a one-sentence note. Use an empty list when the shot was on call.
- nextStep: one or two sentences on what to do for the next shot.
- caution: one short sentence on what a single shot cannot tell, or an empty string.

One impact is not a trued muzzle velocity. Do not give a replacement dial value or any number more precise than this single shot supports.`

// Prompt turns a solved shot into the instructions the provider sees.
// The system text stays on the server.
func Prompt(r Request) (system, user string) {
	user = fmt.Sprintf(`Solved shot:
Range: %.0f yd
Azimuth: %.0f degrees magnetic
Incline: %.1f degrees
Location: %.2f, %.2f
Temperature: %.0f F
Station pressure: %.2f inHg
Humidity: %.0f%%
Altitude: %.0f ft
Wind: %.1f mph from %.0f degrees
Come-up: %.2f MOA
Windage: %.2f MOA
Wind drift: %.1f in
Spin drift: %.1f in
Coriolis horizontal: %.1f in
Coriolis vertical: %.1f in
Impact from the point of aim: elevation %s, windage %s`,
		r.RangeYards,
		r.AzimuthDegrees,
		r.InclineDegrees,
		r.LatitudeDegrees,
		r.LongitudeDegrees,
		r.TemperatureF,
		r.StationPressureInHg,
		r.HumidityPercent,
		r.AltitudeFeet,
		r.WindSpeedMph,
		r.WindFromDegrees,
		r.ComeUpMOA,
		r.WindageMOA,
		r.WindDriftInches,
		r.SpinDriftInches,
		r.CoriolisHorizontalIn,
		r.CoriolisVerticalIn,
		offset(r.ImpactHighMOA, r.RangeYards, "high", "low"),
		offset(r.ImpactRightMOA, r.RangeYards, "right", "left"),
	)
	return systemPrompt, user
}

// inchesPerMOA is one true minute of angle at 100 yards.
const inchesPerMOA = 1.04720

// offset describes one axis of the miss in MOA and in inches at the target, so the
// model can compare it with the drift figures without converting units itself.
func offset(value, rangeYards float64, positive, negative string) string {
	if math.Abs(value) < 0.005 {
		return "on call"
	}
	direction := positive
	if value < 0 {
		direction = negative
	}
	inches := math.Abs(value) * inchesPerMOA * rangeYards / 100
	return fmt.Sprintf("%.2f MOA %s (%.1f in)", math.Abs(value), direction, inches)
}
