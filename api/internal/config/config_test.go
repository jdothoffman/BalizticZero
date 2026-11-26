package config

import "testing"

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
