package httpapi

import (
	"crypto/subtle"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jdothoffman/BalizticZero/api/internal/advise"
	"github.com/jdothoffman/BalizticZero/api/internal/provider"
	"github.com/jdothoffman/BalizticZero/api/internal/ratelimit"
)

// Server is the development API. The dev token is a shared secret for this
// process. It is not an AI provider key.
type Server struct {
	DevToken string
	Advisor  provider.Advisor
	limiter  *ratelimit.Limiter
	log      *log.Logger
}

// Option changes a Server built by New.
type Option func(*Server)

// WithLimiter replaces the default rate limits.
func WithLimiter(limiter *ratelimit.Limiter) Option {
	return func(s *Server) { s.limiter = limiter }
}

// New builds the server. Rate limits are on by default (ratelimit.Defaults), so a
// server built without options still cannot run up the provider bill.
func New(devToken string, advisor provider.Advisor, opts ...Option) *Server {
	s := &Server{
		DevToken: devToken,
		Advisor:  advisor,
		limiter:  ratelimit.New(ratelimit.Defaults),
		log:      log.Default(),
	}
	for _, opt := range opts {
		opt(s)
	}
	return s
}

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", s.health)
	mux.HandleFunc("POST /v1/advise", s.advise)
	return mux
}

func (s *Server) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{
		"status":   "ok",
		"provider": s.Advisor.Name(),
	})
}

func (s *Server) advise(w http.ResponseWriter, r *http.Request) {
	// Per-client first, before the token check, so guessing tokens is throttled too.
	client := ratelimit.ClientKey(r)
	if ok, wait := s.limiter.AllowClient(client); !ok {
		s.log.Printf("advise rate limited client=%s", client)
		tooManyRequests(w, wait, "too many requests; slow down")
		return
	}
	if !authorized(r, s.DevToken) {
		writeJSON(w, http.StatusUnauthorized, errorBody{Error: "unauthorized"})
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, 1<<16)
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	var shot advise.Request
	if err := dec.Decode(&shot); err != nil {
		writeJSON(w, http.StatusBadRequest, errorBody{Error: "request must be the solved shot, with no extra fields"})
		return
	}
	if err := shot.Validate(); err != nil {
		writeJSON(w, http.StatusBadRequest, errorBody{Error: err.Error()})
		return
	}

	// The global cap counts only requests that will reach the paid provider.
	if ok, wait := s.limiter.AllowGlobal(); !ok {
		s.log.Printf("advise global limit reached")
		tooManyRequests(w, wait, "the advisor is busy; try again later")
		return
	}

	system, user := advise.Prompt(shot)
	text, err := s.Advisor.Advise(r.Context(), system, user)
	if err != nil {
		s.log.Printf("advise provider=%s err=%s", s.Advisor.Name(), err)
		status := http.StatusBadGateway
		if errors.Is(err, errUnconfigured) || s.Advisor.Name() == "none" {
			status = http.StatusServiceUnavailable
		}
		writeJSON(w, status, errorBody{Error: "advisor is unavailable"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"text": text})
}

func authorized(r *http.Request, token string) bool {
	header := r.Header.Get("Authorization")
	const prefix = "Bearer "
	if len(header) < len(prefix) || !strings.EqualFold(header[:len(prefix)], prefix) {
		return false
	}
	got := strings.TrimSpace(header[len(prefix):])
	if len(got) != len(token) {
		return false
	}
	return subtle.ConstantTimeCompare([]byte(got), []byte(token)) == 1
}

func tooManyRequests(w http.ResponseWriter, wait time.Duration, message string) {
	w.Header().Set("Retry-After", strconv.Itoa(ratelimit.RetryAfterSeconds(wait)))
	writeJSON(w, http.StatusTooManyRequests, errorBody{Error: message})
}

type errorBody struct {
	Error string `json:"error"`
}

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

// errUnconfigured is unused as a sentinel today; the unconfigured advisor is detected by name.
var errUnconfigured = errors.New("unconfigured")
