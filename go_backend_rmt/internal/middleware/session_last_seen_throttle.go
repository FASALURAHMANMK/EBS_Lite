package middleware

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"

	"erp-backend/internal/config"

	"github.com/redis/go-redis/v9"
)

type sessionLastSeenLimiter interface {
	Allow(ctx context.Context, sessionID string) (bool, error)
}

type noopSessionLastSeenLimiter struct{}

func (noopSessionLastSeenLimiter) Allow(_ context.Context, _ string) (bool, error) {
	return true, nil
}

type redisSessionLastSeenLimiter struct {
	client   *redis.Client
	interval time.Duration
	prefix   string
}

func (l *redisSessionLastSeenLimiter) Allow(ctx context.Context, sessionID string) (bool, error) {
	if l == nil || l.client == nil || sessionID == "" {
		return false, nil
	}
	key := fmt.Sprintf("%s:%s", l.prefix, sessionID)
	allowed, err := l.client.SetNX(ctx, key, "1", l.interval).Result()
	if err != nil {
		return false, err
	}
	return allowed, nil
}

type memorySessionLastSeenLimiter struct {
	interval time.Duration
	mu       sync.Mutex
	lastSeen map[string]time.Time
}

func newMemorySessionLastSeenLimiter(interval time.Duration) *memorySessionLastSeenLimiter {
	return &memorySessionLastSeenLimiter{
		interval: interval,
		lastSeen: make(map[string]time.Time),
	}
}

func (l *memorySessionLastSeenLimiter) Allow(_ context.Context, sessionID string) (bool, error) {
	if l == nil || sessionID == "" {
		return false, nil
	}
	now := time.Now()

	l.mu.Lock()
	defer l.mu.Unlock()

	if last, ok := l.lastSeen[sessionID]; ok {
		if now.Sub(last) < l.interval {
			return false, nil
		}
	}
	l.lastSeen[sessionID] = now

	if len(l.lastSeen) > 10000 {
		cutoff := now.Add(-2 * l.interval)
		for key, ts := range l.lastSeen {
			if ts.Before(cutoff) {
				delete(l.lastSeen, key)
			}
		}
	}

	return true, nil
}

type compositeSessionLastSeenLimiter struct {
	primary  sessionLastSeenLimiter
	fallback sessionLastSeenLimiter
}

func (c *compositeSessionLastSeenLimiter) Allow(ctx context.Context, sessionID string) (bool, error) {
	if c == nil || c.primary == nil {
		if c == nil || c.fallback == nil {
			return false, nil
		}
		return c.fallback.Allow(ctx, sessionID)
	}
	allowed, err := c.primary.Allow(ctx, sessionID)
	if err == nil {
		return allowed, nil
	}
	if c.fallback != nil {
		return c.fallback.Allow(ctx, sessionID)
	}
	return false, err
}

var (
	sessionLastSeenOnce        sync.Once
	sessionLastSeenLimiterInst sessionLastSeenLimiter
)

func getSessionLastSeenLimiter() sessionLastSeenLimiter {
	sessionLastSeenOnce.Do(func() {
		cfg := config.Load()
		if cfg.SessionLastSeenThrottle <= 0 {
			sessionLastSeenLimiterInst = noopSessionLastSeenLimiter{}
			return
		}

		memoryLimiter := newMemorySessionLastSeenLimiter(cfg.SessionLastSeenThrottle)

		if !cfg.SessionLastSeenUseRedis {
			sessionLastSeenLimiterInst = memoryLimiter
			return
		}

		client, err := newRedisClient(cfg.RedisURL)
		if err != nil {
			log.Printf("session_last_seen: redis init failed, using memory limiter: %v", err)
			sessionLastSeenLimiterInst = memoryLimiter
			return
		}

		if err := client.Ping(context.Background()).Err(); err != nil {
			log.Printf("session_last_seen: redis ping failed, using memory limiter: %v", err)
			sessionLastSeenLimiterInst = memoryLimiter
			return
		}

		redisLimiter := &redisSessionLastSeenLimiter{
			client:   client,
			interval: cfg.SessionLastSeenThrottle,
			prefix:   "session_last_seen",
		}
		sessionLastSeenLimiterInst = &compositeSessionLastSeenLimiter{
			primary:  redisLimiter,
			fallback: memoryLimiter,
		}
	})

	return sessionLastSeenLimiterInst
}
