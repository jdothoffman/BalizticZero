package provider

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/jdothoffman/BalizticZero/api/internal/config"
)

// Advisor calls one model provider. Implementations add the provider key
// themselves. Callers pass the prompt and receive text.
type Advisor interface {
	Name() string
	Advise(ctx context.Context, system, user string) (string, error)
}

// Unconfigured keeps the process serving health checks before a provider is chosen.
type Unconfigured struct{}

func (Unconfigured) Name() string { return "none" }

func (Unconfigured) Advise(context.Context, string, string) (string, error) {
	return "", fmt.Errorf("no AI provider is configured")
}

// New selects the provider from server configuration. A missing key is a startup failure.
func New(cfg config.Config) (Advisor, error) {
	client := &http.Client{Timeout: 30 * time.Second}
	switch cfg.Provider {
	case "", "none":
		return Unconfigured{}, nil
	case "grok":
		if cfg.XAIKey == "" {
			return nil, fmt.Errorf("XAI_API_KEY is required when AI_PROVIDER=grok")
		}
		if cfg.Model == "" {
			return nil, fmt.Errorf("AI_MODEL is required when AI_PROVIDER=grok")
		}
		return &Grok{key: cfg.XAIKey, model: cfg.Model, client: client}, nil
	case "claude":
		if cfg.AnthropicKey == "" {
			return nil, fmt.Errorf("ANTHROPIC_API_KEY is required when AI_PROVIDER=claude")
		}
		if cfg.Model == "" {
			return nil, fmt.Errorf("AI_MODEL is required when AI_PROVIDER=claude")
		}
		return NewClaude(cfg.AnthropicKey, cfg.Model, "", nil), nil
	default:
		return nil, fmt.Errorf("unknown AI_PROVIDER %q", cfg.Provider)
	}
}
