// Package ratelimit caps how often clients can reach the paid AI provider.
//
// Two limits apply. Each client address gets its own token bucket, so one phone
// cannot hog the service. A global bucket caps every caller together, so a leaked
// token still cannot spend more than a fixed number of provider calls per hour.
package ratelimit

import (
	"math"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"golang.org/x/time/rate"
)

// Limits are the configured rates. A zero rate turns that limit off.
type Limits struct {
	PerClientPerMinute float64
	PerClientBurst     int
	GlobalPerHour      float64
	GlobalBurst        int
}

// Defaults suit one person testing on a phone.
var Defaults = Limits{
	PerClientPerMinute: 10,
	PerClientBurst:     5,
	GlobalPerHour:      200,
	GlobalBurst:        20,
}

const (
	// A client idle this long is forgotten, so the table does not grow forever.
	idleAfter = 10 * time.Minute
	// Hard cap on remembered clients. Past it, unknown clients are refused until
	// idle ones age out, which bounds memory under a flood of spoofed sources.
	maxClients = 10000
)

type client struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

// Limiter holds the per-client buckets and the global bucket.
type Limiter struct {
	limits Limits
	global *rate.Limiter
	now    func() time.Time

	mu        sync.Mutex
	clients   map[string]*client
	lastSweep time.Time
}

func New(limits Limits) *Limiter {
	l := &Limiter{
		limits:  limits,
		now:     time.Now,
		clients: make(map[string]*client),
	}
	if limits.GlobalPerHour > 0 {
		l.global = rate.NewLimiter(rate.Limit(limits.GlobalPerHour/3600), max(limits.GlobalBurst, 1))
	}
	return l
}

// AllowClient spends one request from the client's own bucket. When it refuses,
// it returns how long until the client can try again.
func (l *Limiter) AllowClient(key string) (bool, time.Duration) {
	if l.limits.PerClientPerMinute <= 0 {
		return true, 0
	}
	now := l.now()

	l.mu.Lock()
	defer l.mu.Unlock()
	if now.Sub(l.lastSweep) > time.Minute {
		l.sweep(now)
	}
	c, ok := l.clients[key]
	if !ok {
		if len(l.clients) >= maxClients {
			l.sweep(now)
			if len(l.clients) >= maxClients {
				return false, time.Minute
			}
		}
		c = &client{limiter: rate.NewLimiter(rate.Limit(l.limits.PerClientPerMinute/60), max(l.limits.PerClientBurst, 1))}
		l.clients[key] = c
	}
	c.lastSeen = now
	return reserve(c.limiter, now)
}

// AllowGlobal spends one request from the shared bucket. Call it only for requests
// that will reach the provider, so rejected or malformed ones do not use it up.
func (l *Limiter) AllowGlobal() (bool, time.Duration) {
	if l.global == nil {
		return true, 0
	}
	return reserve(l.global, l.now())
}

func reserve(limiter *rate.Limiter, now time.Time) (bool, time.Duration) {
	r := limiter.ReserveN(now, 1)
	if !r.OK() {
		return false, time.Minute
	}
	if wait := r.DelayFrom(now); wait > 0 {
		// Not allowed yet: give the token back and tell the caller when to retry.
		r.CancelAt(now)
		return false, wait
	}
	return true, 0
}

func (l *Limiter) sweep(now time.Time) {
	for key, c := range l.clients {
		if now.Sub(c.lastSeen) > idleAfter {
			delete(l.clients, key)
		}
	}
	l.lastSweep = now
}

// ClientKey identifies the caller. Caddy on the same machine is the only thing that can
// reach this service, and it sets X-Forwarded-For to the real client address, replacing
// whatever the client sent. So the header is trusted only from a loopback peer, and the
// rightmost entry (the one Caddy added) is used. Anything else is keyed by its own address.
func ClientKey(r *http.Request) string {
	peer, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		peer = r.RemoteAddr
	}
	if ip := net.ParseIP(peer); ip != nil && ip.IsLoopback() {
		if forwarded := r.Header.Get("X-Forwarded-For"); forwarded != "" {
			parts := strings.Split(forwarded, ",")
			if last := strings.TrimSpace(parts[len(parts)-1]); net.ParseIP(last) != nil {
				return last
			}
		}
	}
	return peer
}

// RetryAfterSeconds rounds a wait up to whole seconds for the Retry-After header.
func RetryAfterSeconds(wait time.Duration) int {
	return max(1, int(math.Ceil(wait.Seconds())))
}
