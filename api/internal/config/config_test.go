package config

import (
	"strings"
	"testing"
)

func TestClaudeRequiresTheAnthropicKey(t *testing.T) {
	t.Setenv("DEV_TOKEN", "dev-token")
	t.Setenv("AI_PROVIDER", "claude")
	t.Setenv("ANTHROPIC_API_KEY", "")
	t.Setenv("AI_MODEL", "")

	_, err := FromEnv()
	if err == nil || err.Error() != "ANTHROPIC_API_KEY is required" {
		t.Fatalf("got %v", err)
	}
}

func TestClaudeDefaultsTheModel(t *testing.T) {
	t.Setenv("DEV_TOKEN", "dev-token")
	t.Setenv("AI_PROVIDER", "claude")
	t.Setenv("ANTHROPIC_API_KEY", "sk-ant-test")
	t.Setenv("AI_MODEL", "")

	cfg, err := FromEnv()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Provider != "claude" {
		t.Fatalf("provider %q", cfg.Provider)
	}
	if cfg.AnthropicKey != "sk-ant-test" {
		t.Fatalf("key %q", cfg.AnthropicKey)
	}
	if cfg.Model != "claude-sonnet-5-5" {
		t.Fatalf("model %q", cfg.Model)
	}
}

func TestRateLimitsComeFromTheEnvironment(t *testing.T) {
	t.Setenv("DEV_TOKEN", "dev-token")
	t.Setenv("AI_PROVIDER", "none")
	t.Setenv("RATE_PER_MINUTE", "4")
	t.Setenv("RATE_BURST", "2")
	t.Setenv("RATE_GLOBAL_PER_HOUR", "0")
	t.Setenv("RATE_GLOBAL_BURST", "")

	cfg, err := FromEnv()
	if err != nil {
		t.Fatal(err)
	}
	if cfg.Limits.PerClientPerMinute != 4 || cfg.Limits.PerClientBurst != 2 {
		t.Fatalf("per-client limits %+v", cfg.Limits)
	}
	if cfg.Limits.GlobalPerHour != 0 {
		t.Fatalf("global limit should be off, got %v", cfg.Limits.GlobalPerHour)
	}
	if cfg.Limits.GlobalBurst != 20 {
		t.Fatalf("unset burst should keep the default, got %d", cfg.Limits.GlobalBurst)
	}
}

func TestRateLimitsRejectNonsense(t *testing.T) {
	t.Setenv("DEV_TOKEN", "dev-token")
	t.Setenv("AI_PROVIDER", "none")
	for key, value := range map[string]string{"RATE_PER_MINUTE": "-1", "RATE_BURST": "0", "RATE_GLOBAL_PER_HOUR": "lots"} {
		t.Run(key, func(t *testing.T) {
			t.Setenv(key, value)
			if _, err := FromEnv(); err == nil || !strings.Contains(err.Error(), key) {
				t.Fatalf("got %v", err)
			}
		})
	}
}
