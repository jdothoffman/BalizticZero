package main

import (
	"log"
	"net/http"
	"time"

	"github.com/jdothoffman/BalizticZero/api/internal/config"
	"github.com/jdothoffman/BalizticZero/api/internal/httpapi"
	"github.com/jdothoffman/BalizticZero/api/internal/provider"
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

	server := httpapi.New(cfg.DevToken, advisor)
	httpServer := &http.Server{
		Addr:              cfg.Addr,
		Handler:           server.Handler(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       15 * time.Second,
		// Longer than the provider's 45-second cap, so a slow answer still reaches the phone.
		WriteTimeout: 60 * time.Second,
		IdleTimeout:  60 * time.Second,
	}
	log.Printf("listening on %s provider=%s", cfg.Addr, advisor.Name())
	if err := httpServer.ListenAndServe(); err != nil {
		log.Fatal(err)
	}
}
