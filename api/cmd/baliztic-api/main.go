package main

import (
	"log"
	"net/http"
	"time"

	"github.com/jdothoffman/BalizticZero/api/internal/config"
	"github.com/jdothoffman/BalizticZero/api/internal/httpapi"
	"github.com/jdothoffman/BalizticZero/api/internal/provider"
	"github.com/jdothoffman/BalizticZero/api/internal/ratelimit"
)

func main() {
	config.LoadDotEnv(".env")
	cfg, err := config.FromEnv()
	if err != nil {
		log.Fatal(err)
	}
	advisor, err := provider.New(cfg)
	if err != nil {
		log.Fatal(err)
	}

	server := httpapi.New(cfg.DevToken, advisor, httpapi.WithLimiter(ratelimit.New(cfg.Limits)))
	httpServer := &http.Server{
		Addr:              cfg.Addr,
		Handler:           server.Handler(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       15 * time.Second,
		// Longer than the provider's 45-second cap, so a slow answer still reaches the phone.
		WriteTimeout: 60 * time.Second,
		IdleTimeout:  60 * time.Second,
	}
	log.Printf("listening on %s provider=%s limits: %.0f/min per client (burst %d), %.0f/hour overall (burst %d)",
		cfg.Addr, advisor.Name(),
		cfg.Limits.PerClientPerMinute, cfg.Limits.PerClientBurst, cfg.Limits.GlobalPerHour, cfg.Limits.GlobalBurst)
	if err := httpServer.ListenAndServe(); err != nil {
		log.Fatal(err)
	}
}
