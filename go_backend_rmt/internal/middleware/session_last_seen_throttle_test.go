package middleware

import (
	"context"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/redis/go-redis/v9"
)

func TestRedisSessionLastSeenLimiter_Throttles(t *testing.T) {
	redisServer, err := miniredis.Run()
	if err != nil {
		t.Fatalf("failed to start miniredis: %v", err)
	}
	defer redisServer.Close()

	opts, err := redis.ParseURL("redis://" + redisServer.Addr())
	if err != nil {
		t.Fatalf("failed to parse redis url: %v", err)
	}
	client := redis.NewClient(opts)

	limiter := &redisSessionLastSeenLimiter{
		client:   client,
		interval: 100 * time.Millisecond,
		prefix:   "session_last_seen",
	}

	ctx := context.Background()
	if allowed, err := limiter.Allow(ctx, "sess-1"); err != nil || !allowed {
		t.Fatalf("expected first allow, got allowed=%v err=%v", allowed, err)
	}
	if allowed, err := limiter.Allow(ctx, "sess-1"); err != nil || allowed {
		t.Fatalf("expected second call to be throttled, got allowed=%v err=%v", allowed, err)
	}

	redisServer.FastForward(120 * time.Millisecond)
	if allowed, err := limiter.Allow(ctx, "sess-1"); err != nil || !allowed {
		t.Fatalf("expected allow after interval, got allowed=%v err=%v", allowed, err)
	}
}
