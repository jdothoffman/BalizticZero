package httpapi

import (
	"crypto/subtle"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"strings"

	"github.com/jdothoffman/BalizticZero/api/internal/advise"
	"github.com/jdothoffman/BalizticZero/api/internal/provider"
)

// Server is the development API. The dev token is a shared secret for this
// process. It is not an AI provider key.
type Server struct {
	DevToken string
	Advisor  provider.Advisor
	log      *log.Logger
}

func New(devToken string, advisor provider.Advisor) *Server {
	return &Server{
		DevToken: devToken,
		Advisor:  advisor,
		log:      log.Default(),
	}
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
