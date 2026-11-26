package provider

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/jdothoffman/BalizticZero/api/internal/config"
)

func TestNewRefusesAProviderWithoutAKey(t *testing.T) {
	_, err := New(config.Config{Provider: "grok", Model: "grok-test"})
	if err == nil || !strings.Contains(err.Error(), "XAI_API_KEY") {
		t.Fatalf("got %v", err)
	}
	_, err = New(config.Config{Provider: "claude", Model: "claude-test"})
	if err == nil || !strings.Contains(err.Error(), "ANTHROPIC_API_KEY") {
		t.Fatalf("got %v", err)
	}
}

func TestGrokSendsTheKeyAndReturnsTheText(t *testing.T) {
	var sawKey string
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		sawKey = r.Header.Get("Authorization")
		body, _ := io.ReadAll(r.Body)
		if strings.Contains(string(body), "ignore the solver") {
			t.Errorf("client prompt reached the provider: %s", body)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"choices":[{"message":{"content":"Dial the solver's number."}}]}`))
	}))
	defer upstream.Close()

	grok := &Grok{key: "secret-key", model: "grok-test", client: upstream.Client(), url: upstream.URL}
	text, err := grok.Advise(context.Background(), Prompt{System: "system", User: "user facts"})
	if err != nil {
		t.Fatal(err)
	}
	if text != "Dial the solver's number." {
		t.Fatalf("text %q", text)
	}
	if sawKey != "Bearer secret-key" {
		t.Fatalf("authorization %q", sawKey)
	}
}

func TestClaudeHidesTheProviderBodyOnFailure(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		_, _ = w.Write([]byte(`{"type":"error","error":{"type":"authentication_error","message":"invalid api key sk-ant-secret"}}`))
	}))
	defer upstream.Close()

	claude := NewClaude("anthropic-key", "claude-test", upstream.URL, upstream.Client())
	_, err := claude.Advise(context.Background(), Prompt{System: "system", User: "user facts"})
	if err == nil {
		t.Fatal("expected an error")
	}
	if strings.Contains(err.Error(), "sk-ant-secret") || strings.Contains(err.Error(), "authentication_error") {
		t.Fatalf("provider body leaked: %v", err)
	}
	if !strings.Contains(err.Error(), "401") {
		t.Fatalf("status missing: %v", err)
	}
}

// Thinking is on by default, so the reply starts with a thinking block that has no text.
func TestClaudeSkipsThinkingAndSendsTheKey(t *testing.T) {
	var gotAuth, gotBeta string
	var gotBody map[string]any
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("Authorization")
		gotBeta = r.Header.Get("Anthropic-Beta")
		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &gotBody)
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{
			"id": "msg_test", "type": "message", "role": "assistant", "model": "claude-test",
			"content": [
				{"type": "thinking", "thinking": "", "signature": "sig"},
				{"type": "text", "text": "Dial 18.25 MOA. "},
				{"type": "text", "text": "Wind is most of the windage."}
			],
			"stop_reason": "end_turn",
			"usage": {"input_tokens": 10, "output_tokens": 20}
		}`))
	}))
	defer upstream.Close()

	claude := NewClaude("anthropic-key", "claude-test", upstream.URL, upstream.Client())
	text, err := claude.Advise(context.Background(), Prompt{System: "system", User: "user facts"})
	if err != nil {
		t.Fatal(err)
	}
	if text != "Dial 18.25 MOA. Wind is most of the windage." {
		t.Fatalf("text %q", text)
	}
	// The SDK sends the API key as a bearer token.
	if gotAuth != "Bearer anthropic-key" {
		t.Fatalf("authorization %q", gotAuth)
	}
	if !strings.Contains(gotBeta, "server-side-fallback-2026-07-01") {
		t.Fatalf("anthropic-beta %q", gotBeta)
	}
	if gotBody["fallbacks"] != "default" {
		t.Fatalf("fallbacks %v", gotBody["fallbacks"])
	}
	if config, _ := gotBody["output_config"].(map[string]any); config["effort"] != "low" {
		t.Fatalf("output_config %v", gotBody["output_config"])
	}
}

func TestClaudeReportsARefusalInsteadOfEmptyText(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{
			"id": "msg_test", "type": "message", "role": "assistant", "model": "claude-test",
			"content": [], "stop_reason": "refusal",
			"stop_details": {"type": "refusal", "category": null, "explanation": null},
			"usage": {"input_tokens": 10, "output_tokens": 0}
		}`))
	}))
	defer upstream.Close()

	claude := NewClaude("anthropic-key", "claude-test", upstream.URL, upstream.Client())
	_, err := claude.Advise(context.Background(), Prompt{System: "system", User: "user facts"})
	if err == nil || !strings.Contains(err.Error(), "declined") {
		t.Fatalf("got %v", err)
	}
}

func TestClaudeConstrainsTheReplyToTheSchema(t *testing.T) {
	var gotBody map[string]any
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &gotBody)
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{
			"id": "msg_test", "type": "message", "role": "assistant", "model": "claude-test",
			"content": [{"type": "text", "text": "{\"ok\":true}"}],
			"stop_reason": "end_turn",
			"usage": {"input_tokens": 10, "output_tokens": 5}
		}`))
	}))
	defer upstream.Close()

	schema := json.RawMessage(`{"type":"object","additionalProperties":false,"required":["ok"],"properties":{"ok":{"type":"boolean"}}}`)
	claude := NewClaude("anthropic-key", "claude-test", upstream.URL, upstream.Client())
	text, err := claude.Advise(context.Background(), Prompt{System: "system", User: "user facts", Schema: schema})
	if err != nil {
		t.Fatal(err)
	}
	if text != `{"ok":true}` {
		t.Fatalf("text %q", text)
	}
	config, _ := gotBody["output_config"].(map[string]any)
	format, _ := config["format"].(map[string]any)
	if format["type"] != "json_schema" {
		t.Fatalf("output_config %v", gotBody["output_config"])
	}
	var want any
	_ = json.Unmarshal(schema, &want)
	if !reflect.DeepEqual(format["schema"], want) {
		t.Fatalf("schema sent %v", format["schema"])
	}
	if config["effort"] != "low" {
		t.Fatalf("effort dropped when the format was added: %v", config)
	}
}

func TestClaudeOmitsTheFormatWithoutASchema(t *testing.T) {
	var gotBody map[string]any
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &gotBody)
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"id":"m","type":"message","role":"assistant","model":"claude-test",
			"content":[{"type":"text","text":"plain"}],"stop_reason":"end_turn","usage":{"input_tokens":1,"output_tokens":1}}`))
	}))
	defer upstream.Close()

	claude := NewClaude("anthropic-key", "claude-test", upstream.URL, upstream.Client())
	if _, err := claude.Advise(context.Background(), Prompt{System: "system", User: "user"}); err != nil {
		t.Fatal(err)
	}
	if config, _ := gotBody["output_config"].(map[string]any); config["format"] != nil {
		t.Fatalf("format sent without a schema: %v", config)
	}
}

// Overloaded (529) and 5xx replies are retried once, then given up, so a bad hour at the
// provider costs one extra attempt per review and not three.
func TestClaudeRetriesOnceWhenTheProviderIsOverloaded(t *testing.T) {
	var calls atomic.Int32
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		w.Header().Set("Retry-After-Ms", "1")
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(529)
		_, _ = w.Write([]byte(`{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}`))
	}))
	defer upstream.Close()

	claude := NewClaude("anthropic-key", "claude-test", upstream.URL, upstream.Client())
	_, err := claude.Advise(context.Background(), Prompt{System: "system", User: "user facts"})
	if err == nil || !strings.Contains(err.Error(), "529") {
		t.Fatalf("got %v", err)
	}
	if got := calls.Load(); got != 2 {
		t.Fatalf("provider called %d times, want 2 (the attempt and one retry)", got)
	}
}
