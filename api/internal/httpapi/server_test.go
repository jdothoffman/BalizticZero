package httpapi

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/jdothoffman/BalizticZero/api/internal/provider"
	"github.com/jdothoffman/BalizticZero/api/internal/ratelimit"
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

type countingAdvisor struct{ calls atomic.Int32 }

func (c *countingAdvisor) Name() string { return "counting" }

func (c *countingAdvisor) Advise(context.Context, string, string) (string, error) {
	c.calls.Add(1)
	return "ok", nil
}

func TestAdviseLimitsEachClient(t *testing.T) {
	advisor := &countingAdvisor{}
	limiter := ratelimit.New(ratelimit.Limits{PerClientPerMinute: 1, PerClientBurst: 2})
	handler := New("secret", advisor, WithLimiter(limiter)).Handler()

	for i := 0; i < 2; i++ {
		if resp := post(t, handler, "/v1/advise", "secret", validShot()); resp.Code != http.StatusOK {
			t.Fatalf("request %d: status %d", i+1, resp.Code)
		}
	}
	resp := post(t, handler, "/v1/advise", "secret", validShot())
	if resp.Code != http.StatusTooManyRequests {
		t.Fatalf("third request: status %d", resp.Code)
	}
	if resp.Header().Get("Retry-After") == "" {
		t.Fatal("429 without Retry-After")
	}
	if got := advisor.calls.Load(); got != 2 {
		t.Fatalf("provider called %d times, want 2", got)
	}
}

func TestAdviseThrottlesTokenGuessing(t *testing.T) {
	limiter := ratelimit.New(ratelimit.Limits{PerClientPerMinute: 1, PerClientBurst: 1})
	handler := New("secret", &countingAdvisor{}, WithLimiter(limiter)).Handler()

	if resp := post(t, handler, "/v1/advise", "wrong", validShot()); resp.Code != http.StatusUnauthorized {
		t.Fatalf("first guess: status %d", resp.Code)
	}
	if resp := post(t, handler, "/v1/advise", "wrong-again", validShot()); resp.Code != http.StatusTooManyRequests {
		t.Fatalf("second guess: status %d", resp.Code)
	}
}

func TestGlobalCapCountsOnlyRequestsThatReachTheProvider(t *testing.T) {
	advisor := &countingAdvisor{}
	limiter := ratelimit.New(ratelimit.Limits{GlobalPerHour: 1, GlobalBurst: 1})
	handler := New("secret", advisor, WithLimiter(limiter)).Handler()

	// Unauthorized and malformed requests must not use up the shared budget.
	post(t, handler, "/v1/advise", "wrong", validShot())
	post(t, handler, "/v1/advise", "secret", `{"rangeYards": 0, "stationPressureInHg": 29.9}`)

	if resp := post(t, handler, "/v1/advise", "secret", validShot()); resp.Code != http.StatusOK {
		t.Fatalf("first valid request: status %d body %s", resp.Code, resp.Body.String())
	}
	if resp := post(t, handler, "/v1/advise", "secret", validShot()); resp.Code != http.StatusTooManyRequests {
		t.Fatalf("over the global cap: status %d", resp.Code)
	}
	if got := advisor.calls.Load(); got != 1 {
		t.Fatalf("provider called %d times, want 1", got)
	}
}

func TestHealthIsNotRateLimited(t *testing.T) {
	limiter := ratelimit.New(ratelimit.Limits{PerClientPerMinute: 1, PerClientBurst: 1, GlobalPerHour: 1, GlobalBurst: 1})
	handler := New("secret", provider.Unconfigured{}, WithLimiter(limiter)).Handler()
	for i := 0; i < 5; i++ {
		if resp := get(t, handler, "/healthz", ""); resp.Code != http.StatusOK {
			t.Fatalf("health check %d: status %d", i+1, resp.Code)
		}
	}
}
