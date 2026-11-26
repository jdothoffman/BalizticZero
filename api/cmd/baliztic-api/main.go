package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
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
		Handler:           server.Handler(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       15 * time.Second,
		// Longer than the handler's provider cap, so a slow answer still reaches the phone.
		WriteTimeout: httpapi.DefaultProviderTimeout + 10*time.Second,
		IdleTimeout:  60 * time.Second,
	}
	listener, err := net.Listen("tcp", cfg.Addr)
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("listening on %s provider=%s limits: %.0f/min per client (burst %d), %.0f/hour overall (burst %d)",
		listener.Addr(), advisor.Name(),
		cfg.Limits.PerClientPerMinute, cfg.Limits.PerClientBurst, cfg.Limits.GlobalPerHour, cfg.Limits.GlobalBurst)

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if err := serve(ctx, httpServer, listener); err != nil {
		log.Fatal(err)
	}
}

// serve runs the server until ctx ends, then lets in-flight requests finish before it
// returns. systemd sends SIGTERM on every deploy; without the drain, each deploy would cut
// off whoever was waiting on the advisor at that moment.
func serve(ctx context.Context, server *http.Server, listener net.Listener) error {
	failed := make(chan error, 1)
	go func() { failed <- server.Serve(listener) }()

	select {
	case err := <-failed:
		return err
	case <-ctx.Done():
	}
	log.Print("stopping; waiting for in-flight requests to finish")
	// A little longer than the provider cap, so the drain itself never cuts a review off.
	drain, cancel := context.WithTimeout(context.Background(), httpapi.DefaultProviderTimeout+5*time.Second)
	defer cancel()
	if err := server.Shutdown(drain); err != nil {
		return fmt.Errorf("shutdown: %w", err)
	}
	return nil
}
