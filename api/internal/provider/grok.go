package provider

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

// Grok talks to the xAI chat completions API. The key stays in this process.
type Grok struct {
	key    string
	model  string
	client *http.Client
	url    string
}

type chatRequest struct {
	Model    string        `json:"model"`
	Messages []chatMessage `json:"messages"`
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type chatResponse struct {
	Choices []struct {
		Message chatMessage `json:"message"`
	} `json:"choices"`
}

func (g *Grok) Name() string { return "grok" }

func (g *Grok) Advise(ctx context.Context, system, user string) (string, error) {
	body, err := json.Marshal(chatRequest{
		Model: g.model,
		Messages: []chatMessage{
			{Role: "system", Content: system},
			{Role: "user", Content: user},
		},
	})
	if err != nil {
		return "", err
	}
	endpoint := g.url
	if endpoint == "" {
		endpoint = "https://api.x.ai/v1/chat/completions"
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+g.key)
	req.Header.Set("Content-Type", "application/json")
	return readChat(g.client, req)
}

func readChat(client *http.Client, req *http.Request) (string, error) {
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	payload, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return "", err
	}
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("provider returned %d", resp.StatusCode)
	}
	var parsed chatResponse
	if err := json.Unmarshal(payload, &parsed); err != nil {
		return "", err
	}
	if len(parsed.Choices) == 0 || parsed.Choices[0].Message.Content == "" {
		return "", fmt.Errorf("provider returned no text")
	}
	return parsed.Choices[0].Message.Content, nil
}
