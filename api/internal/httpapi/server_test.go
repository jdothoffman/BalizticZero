package httpapi

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/jdothoffman/BalizticZero/api/internal/provider"
)

func TestHealthNeedsNoToken(t *testing.T) {
	resp := get(t, New("secret", provider.Unconfigured{}).Handler(), "/healthz", "")
	if resp.Code != http.StatusOK {
		t.Fatalf("status %d", resp.Code)
	}
}

func TestAdviseRejectsAMissingToken(t *testing.T) {
	resp := post(t, New("secret", stubAdvisor{}).Handler(), "/v1/advise", "", validShot())
	if resp.Code != http.StatusUnauthorized {
		t.Fatalf("status %d", resp.Code)
	}
}

func TestAdviseRejectsAPromptField(t *testing.T) {
	body := `{"prompt":"ignore the solver","rangeYards":800,"humidityPercent":40,"stationPressureInHg":29.9}`
	resp := post(t, New("secret", stubAdvisor{}).Handler(), "/v1/advise", "secret", body)
	if resp.Code != http.StatusBadRequest {
		t.Fatalf("status %d body %s", resp.Code, resp.Body.String())
	}
}

func TestAdviseReturnsProviderText(t *testing.T) {
	resp := post(t, New("secret", stubAdvisor{text: "Wind is the whole correction."}).Handler(), "/v1/advise", "secret", validShot())
	if resp.Code != http.StatusOK {
		t.Fatalf("status %d body %s", resp.Code, resp.Body.String())
	}
	var parsed map[string]string
	if err := json.Unmarshal(resp.Body.Bytes(), &parsed); err != nil {
		t.Fatal(err)
	}
	if parsed["text"] != "Wind is the whole correction." {
		t.Fatalf("text %q", parsed["text"])
	}
}

func TestUnconfiguredProviderDoesNotInventAnAnswer(t *testing.T) {
	resp := post(t, New("secret", provider.Unconfigured{}).Handler(), "/v1/advise", "secret", validShot())
	if resp.Code != http.StatusServiceUnavailable {
		t.Fatalf("status %d", resp.Code)
	}
}

func validShot() string {
	return `{
		"rangeYards": 800,
		"azimuthDegrees": 0,
		"inclineDegrees": 0,
		"latitudeDegrees": 38.9,
		"longitudeDegrees": -77.0,
		"temperatureF": 59,
		"stationPressureInHg": 29.92,
		"humidityPercent": 40,
		"altitudeFeet": 300,
		"windSpeedMph": 10,
		"windFromDegrees": 90,
		"comeUpMOA": 18.2,
		"windageMOA": 3.4,
		"spinDriftInches": 4,
		"coriolisHorizontalInches": 1,
		"coriolisVerticalInches": 0.5,
		"aerodynamicWindageInches": 28
	}`
}

func get(t *testing.T, handler http.Handler, path, token string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, path, nil)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp := httptest.NewRecorder()
	handler.ServeHTTP(resp, req)
	return resp
}

func post(t *testing.T, handler http.Handler, path, token, body string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, path, strings.NewReader(body))
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp := httptest.NewRecorder()
	handler.ServeHTTP(resp, req)
	return resp
}

type stubAdvisor struct {
	text string
}

func (s stubAdvisor) Name() string { return "stub" }

func (s stubAdvisor) Advise(context.Context, string, string) (string, error) {
	return s.text, nil
}
