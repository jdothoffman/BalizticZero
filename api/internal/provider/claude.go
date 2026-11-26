package provider

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/anthropics/anthropic-sdk-go/v2"
	"github.com/anthropics/anthropic-sdk-go/v2/option"
)

// Claude talks to the Anthropic Messages API through the official SDK. The key stays in this process.
type Claude struct {
	client anthropic.Client
	model  string
}

// NewClaude builds the provider. baseURL and httpClient are for tests; pass "" and nil in production.
func NewClaude(key, model, baseURL string, httpClient *http.Client) *Claude {
	opts := []option.RequestOption{
		option.WithAPIKey(key),
		// The phone waits on this call, so cap the whole attempt, retries included.
		option.WithRequestTimeout(45 * time.Second),
		option.WithMaxRetries(2),
	}
	if baseURL != "" {
		opts = append(opts, option.WithBaseURL(baseURL))
	}
	if httpClient != nil {
		opts = append(opts, option.WithHTTPClient(httpClient))
	}
	return &Claude{client: anthropic.NewClient(opts...), model: model}
}

func (c *Claude) Name() string { return "claude" }

func (c *Claude) Advise(ctx context.Context, system, user string) (string, error) {
	message, err := c.client.Beta.Messages.New(ctx, anthropic.BetaMessageNewParams{
		Model: c.model,
		// Thinking is on by default and counts toward this limit. Low effort keeps a short
		// explanation short; the headroom keeps the answer from being cut off after thinking.
		MaxTokens:    16000,
		OutputConfig: anthropic.BetaOutputConfigParam{Effort: anthropic.BetaOutputConfigEffortLow},
		System:       []anthropic.BetaTextBlockParam{{Text: system}},
		Messages:     []anthropic.BetaMessageParam{anthropic.NewBetaUserMessage(anthropic.NewBetaTextBlock(user))},
		// A safety decline is retried server-side on the model Anthropic recommends for its category.
		Fallbacks: anthropic.BetaFallbacksParamOfDefault(),
		Betas:     []anthropic.AnthropicBeta{anthropic.AnthropicBetaServerSideFallback2026_07_01},
	})
	if err != nil {
		// The SDK error carries the provider's response body. Log and return only the status.
		var apiErr *anthropic.Error
		if errors.As(err, &apiErr) {
			return "", fmt.Errorf("provider returned %d", apiErr.StatusCode)
		}
		// Anything else is a transport failure or a timeout; those carry no response body.
		return "", fmt.Errorf("provider request failed: %w", err)
	}

	switch message.StopReason {
	case anthropic.BetaStopReasonRefusal:
		return "", fmt.Errorf("provider declined the request")
	case anthropic.BetaStopReasonMaxTokens:
		return "", fmt.Errorf("provider ran out of tokens before answering")
	}

	// Thinking blocks come first and carry no text; the answer is in the text blocks.
	var text strings.Builder
	for _, block := range message.Content {
		if t, ok := block.AsAny().(anthropic.BetaTextBlock); ok {
			text.WriteString(t.Text)
		}
	}
	if strings.TrimSpace(text.String()) == "" {
		return "", fmt.Errorf("provider returned no text")
	}
	return text.String(), nil
}
