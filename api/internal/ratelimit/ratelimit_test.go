package ratelimit

import (
	"net/http/httptest"
	"testing"
	"time"
)

// fixedClock lets tests move time by hand instead of sleeping.
type fixedClock struct{ t time.Time }

func (c *fixedClock) now() time.Time          { return c.t }
func (c *fixedClock) advance(d time.Duration) { c.t = c.t.Add(d) }

func newTestLimiter(limits Limits) (*Limiter, *fixedClock) {
	clock := &fixedClock{t: time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)}
	l := New(limits)
	l.now = clock.now
	return l, clock
}

func TestClientGetsItsBurstThenWaits(t *testing.T) {
	l, clock := newTestLimiter(Limits{PerClientPerMinute: 6, PerClientBurst: 3})
	for i := 0; i < 3; i++ {
		if ok, _ := l.AllowClient("203.0.113.7"); !ok {
			t.Fatalf("request %d refused inside the burst", i+1)
		}
	}
	ok, wait := l.AllowClient("203.0.113.7")
	if ok {
		t.Fatal("fourth request allowed past the burst")
	}
	// 6 per minute refills one token every 10 seconds.
	if wait <= 0 || wait > 10*time.Second {
		t.Fatalf("retry after %v", wait)
	}
	clock.advance(10 * time.Second)
	if ok, _ := l.AllowClient("203.0.113.7"); !ok {
		t.Fatal("still refused after the refill interval")
	}
}

func TestClientsHaveSeparateBuckets(t *testing.T) {
	l, _ := newTestLimiter(Limits{PerClientPerMinute: 1, PerClientBurst: 1})
	if ok, _ := l.AllowClient("203.0.113.7"); !ok {
		t.Fatal("first client refused")
	}
	if ok, _ := l.AllowClient("203.0.113.7"); ok {
		t.Fatal("first client allowed twice")
	}
	if ok, _ := l.AllowClient("198.51.100.9"); !ok {
		t.Fatal("second client blocked by the first one's limit")
	}
}

func TestRefusedRequestsDoNotDeepenTheWait(t *testing.T) {
	l, clock := newTestLimiter(Limits{PerClientPerMinute: 6, PerClientBurst: 1})
	l.AllowClient("203.0.113.7")
	for i := 0; i < 20; i++ {
		l.AllowClient("203.0.113.7")
	}
	clock.advance(10 * time.Second)
	if ok, _ := l.AllowClient("203.0.113.7"); !ok {
		t.Fatal("hammering while limited pushed the next allowed request further out")
	}
}

func TestGlobalCapCoversEveryClient(t *testing.T) {
	l, clock := newTestLimiter(Limits{GlobalPerHour: 60, GlobalBurst: 2})
	for i := 0; i < 2; i++ {
		if ok, _ := l.AllowGlobal(); !ok {
			t.Fatalf("global request %d refused inside the burst", i+1)
		}
	}
	ok, wait := l.AllowGlobal()
	if ok {
		t.Fatal("global cap let a third request through")
	}
	if wait <= 0 || wait > time.Minute {
		t.Fatalf("retry after %v", wait)
	}
	clock.advance(time.Minute)
	if ok, _ := l.AllowGlobal(); !ok {
		t.Fatal("global cap did not refill")
	}
}

func TestZeroTurnsALimitOff(t *testing.T) {
	l, _ := newTestLimiter(Limits{})
	for i := 0; i < 1000; i++ {
		if ok, _ := l.AllowClient("203.0.113.7"); !ok {
			t.Fatal("per-client limit applied while off")
		}
		if ok, _ := l.AllowGlobal(); !ok {
			t.Fatal("global limit applied while off")
		}
	}
}

func TestIdleClientsAreForgotten(t *testing.T) {
	l, clock := newTestLimiter(Limits{PerClientPerMinute: 1, PerClientBurst: 1})
	l.AllowClient("203.0.113.7")
	clock.advance(idleAfter + 2*time.Minute)
	l.AllowClient("198.51.100.9")
	l.mu.Lock()
	_, kept := l.clients["203.0.113.7"]
	l.mu.Unlock()
	if kept {
		t.Fatal("idle client still in the table")
	}
}

func TestClientKeyTrustsForwardedForOnlyFromLoopback(t *testing.T) {
	cases := []struct {
		name       string
		remoteAddr string
		forwarded  string
		want       string
	}{
		{"caddy on loopback", "127.0.0.1:51234", "203.0.113.7", "203.0.113.7"},
		{"rightmost entry is the one caddy added", "127.0.0.1:51234", "10.0.0.1, 203.0.113.7", "203.0.113.7"},
		{"ipv6 loopback", "[::1]:51234", "2001:db8::5", "2001:db8::5"},
		{"direct caller cannot spoof", "198.51.100.9:443", "203.0.113.7", "198.51.100.9"},
		{"loopback without header", "127.0.0.1:51234", "", "127.0.0.1"},
		{"garbage header falls back", "127.0.0.1:51234", "not-an-ip", "127.0.0.1"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			r := httptest.NewRequest("POST", "/v1/advise", nil)
			r.RemoteAddr = tc.remoteAddr
			if tc.forwarded != "" {
				r.Header.Set("X-Forwarded-For", tc.forwarded)
			}
			if got := ClientKey(r); got != tc.want {
				t.Fatalf("got %q, want %q", got, tc.want)
			}
		})
	}
}
