package config

import (
	"fmt"
	"os"
	"strings"
)

// Config is everything the process needs. Provider keys are read from the
// environment on the server and are never returned to the phone.
type Config struct {
	Addr         string
	DevToken     string
	Provider     string
	Model        string
	XAIKey       string
	AnthropicKey string
}

func FromEnv() (Config, error) {
	cfg := Config{
		Addr:         env("ADDR", ":8080"),
		DevToken:     os.Getenv("DEV_TOKEN"),
		Provider:     env("AI_PROVIDER", "claude"),
		Model:        os.Getenv("AI_MODEL"),
		XAIKey:       os.Getenv("XAI_API_KEY"),
		AnthropicKey: os.Getenv("ANTHROPIC_API_KEY"),
	}
	if cfg.DevToken == "" {
		return Config{}, fmt.Errorf("DEV_TOKEN is required")
	}
	if cfg.Provider == "claude" {
		if cfg.AnthropicKey == "" {
			return Config{}, fmt.Errorf("ANTHROPIC_API_KEY is required")
		}
		if cfg.Model == "" {
			cfg.Model = "claude-sonnet-5-5"
		}
	}
	return cfg, nil
}

// LoadDotEnv reads KEY=VALUE lines into the environment. Existing variables win,
// so a key exported on the server is not overwritten by a file.
func LoadDotEnv(path string) {
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		key = strings.TrimSpace(key)
		value = strings.Trim(strings.TrimSpace(value), `"'`)
		if key == "" || os.Getenv(key) != "" {
			continue
		}
		_ = os.Setenv(key, value)
	}
}

func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
