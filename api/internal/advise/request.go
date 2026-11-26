package advise

import "fmt"

// Request is the shot the phone already solved. The phone sends facts.
// The prompt is built here, so a client cannot supply its own instructions.
type Request struct {
	RangeYards           float64 `json:"rangeYards"`
	AzimuthDegrees       float64 `json:"azimuthDegrees"`
	InclineDegrees       float64 `json:"inclineDegrees"`
	LatitudeDegrees      float64 `json:"latitudeDegrees"`
	LongitudeDegrees     float64 `json:"longitudeDegrees"`
	TemperatureF         float64 `json:"temperatureF"`
	StationPressureInHg  float64 `json:"stationPressureInHg"`
	HumidityPercent      float64 `json:"humidityPercent"`
	AltitudeFeet         float64 `json:"altitudeFeet"`
	WindSpeedMph         float64 `json:"windSpeedMph"`
	WindFromDegrees      float64 `json:"windFromDegrees"`
	ComeUpMOA            float64 `json:"comeUpMOA"`
	WindageMOA           float64 `json:"windageMOA"`
	SpinDriftInches      float64 `json:"spinDriftInches"`
	CoriolisHorizontalIn float64 `json:"coriolisHorizontalInches"`
	CoriolisVerticalIn   float64 `json:"coriolisVerticalInches"`
	WindDriftInches      float64 `json:"aerodynamicWindageInches"`
}

func (r Request) Validate() error {
	if r.RangeYards <= 0 {
		return fmt.Errorf("rangeYards must be greater than zero")
	}
	if r.HumidityPercent < 0 || r.HumidityPercent > 100 {
		return fmt.Errorf("humidityPercent must be from 0 to 100")
	}
	if r.StationPressureInHg <= 0 {
		return fmt.Errorf("stationPressureInHg must be greater than zero")
	}
	return nil
}
