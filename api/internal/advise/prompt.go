package advise

import "fmt"

const systemPrompt = `You are the shooting advisor for Baliztic Zero. The on-device ballistic solver already computed the correction. Explain that correction in plain language: what the shooter should dial, which input is moving the hit the most, and when the wind call is too uncertain to trust the last digit. Do not invent a different correction or a more precise number than you were given.`

// Prompt turns a solved shot into the instructions the provider sees.
// The system text stays on the server.
func Prompt(r Request) (system, user string) {
	user = fmt.Sprintf(`Solved shot:
Range: %.0f yd
Azimuth: %.0f degrees magnetic
Incline: %.1f degrees
Location: %.4f, %.4f
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
Coriolis vertical: %.1f in`,
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
	)
	return systemPrompt, user
}
