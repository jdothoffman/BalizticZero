package main

import (
	"context"
	"io"
	"net"
	"net/http"
	"sync"
	"testing"
	"time"
)

func TestServeFinishesInFlightRequestsBeforeStopping(t *testing.T) {
	var once sync.Once
	inHandler := make(chan struct{})
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		once.Do(func() { close(inHandler) })
		time.Sleep(200 * time.Millisecond)
		_, _ = io.WriteString(w, "done")
	})
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	server := &http.Server{Handler: handler}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	served := make(chan error, 1)
	go func() { served <- serve(ctx, server, listener) }()

	type reply struct {
		body string
		err  error
	}
	replies := make(chan reply, 1)
	go func() {
		resp, err := http.Get("http://" + listener.Addr().String() + "/")
		if err != nil {
			replies <- reply{err: err}
			return
		}
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
		replies <- reply{body: string(body)}
	}()

	<-inHandler
	cancel() // What SIGTERM does.

	if got := <-replies; got.err != nil || got.body != "done" {
		t.Fatalf("in-flight request was cut off: %+v", got)
	}
	select {
	case err := <-served:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("serve did not return after the drain")
	}
	if _, err := http.Get("http://" + listener.Addr().String() + "/"); err == nil {
		t.Fatal("still accepting connections after shutdown")
	}
}

func TestServeReportsAListenerFailure(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	listener.Close() // Serve on a closed listener fails at once.
	err = serve(context.Background(), &http.Server{Handler: http.NotFoundHandler()}, listener)
	if err == nil {
		t.Fatal("expected the listener error")
	}
}
