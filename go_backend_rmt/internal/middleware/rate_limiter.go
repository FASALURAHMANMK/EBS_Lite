package middleware

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"erp-backend/internal/config"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
)

const (
	rateLimitKeyByIP     = "ip"
	rateLimitKeyByUser   = "user"
	rateLimitKeyByIPUser = "ip_user"
)

var rateLimitScript = redis.NewScript(`
local current = redis.call("INCR", KEYS[1])
if current == 1 then
  redis.call("PEXPIRE", KEYS[1], ARGV[1])
end
return current
`)

// RateLimiter applies Redis-backed rate limiting using fixed windows.
func RateLimiter(cfg *config.Config) gin.HandlerFunc {
	if cfg == nil || !cfg.RateLimitEnabled || cfg.RateLimitRequests <= 0 || cfg.RateLimitWindow <= 0 {
		return func(c *gin.Context) {
			c.Next()
		}
	}

	client, err := newRedisClient(cfg.RedisURL)
	if err != nil {
		log.Printf("rate_limiter: disabled (redis init failed): %v", err)
		return func(c *gin.Context) {
			c.Next()
		}
	}

	if err := client.Ping(context.Background()).Err(); err != nil {
		log.Printf("rate_limiter: disabled (redis ping failed): %v", err)
		return func(c *gin.Context) {
			c.Next()
		}
	}

	limiter := &redisRateLimiter{
		client:    client,
		limit:     cfg.RateLimitRequests,
		window:    cfg.RateLimitWindow,
		keyPrefix: cfg.RateLimitKeyPrefix,
		keyBy:     cfg.RateLimitKeyBy,
		failOpen:  cfg.RateLimitFailOpen,
	}

	return func(c *gin.Context) {
		if c.Request.Method == http.MethodOptions {
			c.Next()
			return
		}

		allowed, remaining, resetAt, err := limiter.Allow(c)
		if err != nil {
			if limiter.failOpen {
				log.Printf("rate_limiter: allow on error: %v", err)
				c.Next()
				return
			}
			utils.ErrorResponse(c, http.StatusTooManyRequests, "Rate limit exceeded", nil)
			c.Abort()
			return
		}

		if remaining >= 0 {
			c.Header("X-RateLimit-Limit", strconv.Itoa(limiter.limit))
			c.Header("X-RateLimit-Remaining", strconv.Itoa(remaining))
		}
		if !resetAt.IsZero() {
			c.Header("X-RateLimit-Reset", strconv.FormatInt(resetAt.Unix(), 10))
		}

		if !allowed {
			utils.ErrorResponse(c, http.StatusTooManyRequests, "Rate limit exceeded", nil)
			c.Abort()
			return
		}

		c.Next()
	}
}

type redisRateLimiter struct {
	client    *redis.Client
	limit     int
	window    time.Duration
	keyPrefix string
	keyBy     string
	failOpen  bool
}

func (l *redisRateLimiter) Allow(c *gin.Context) (bool, int, time.Time, error) {
	if l == nil || l.client == nil || c == nil {
		return true, -1, time.Time{}, nil
	}

	key := l.buildKey(c)
	if key == "" {
		return true, -1, time.Time{}, nil
	}

	ctx := c.Request.Context()
	count, err := rateLimitScript.Run(ctx, l.client, []string{key}, l.window.Milliseconds()).Int64()
	if err != nil {
		return true, -1, time.Time{}, err
	}

	remaining := l.limit - int(count)
	if remaining < 0 {
		remaining = 0
	}

	ttl, err := l.client.PTTL(ctx, key).Result()
	if err != nil {
		return count <= int64(l.limit), remaining, time.Time{}, nil
	}

	resetAt := time.Now().Add(ttl)
	return count <= int64(l.limit), remaining, resetAt, nil
}

func (l *redisRateLimiter) buildKey(c *gin.Context) string {
	if c == nil {
		return ""
	}
	keyBy := l.keyBy
	if keyBy == "" {
		keyBy = rateLimitKeyByIP
	}
	var identifier string
	switch keyBy {
	case rateLimitKeyByUser:
		if userID := c.GetInt("user_id"); userID > 0 {
			identifier = fmt.Sprintf("user:%d", userID)
		} else if ip := c.ClientIP(); ip != "" {
			identifier = fmt.Sprintf("ip:%s", ip)
		}
	case rateLimitKeyByIPUser:
		ip := c.ClientIP()
		userID := c.GetInt("user_id")
		if userID > 0 {
			identifier = fmt.Sprintf("ip:%s:user:%d", ip, userID)
		} else if ip != "" {
			identifier = fmt.Sprintf("ip:%s", ip)
		}
	default:
		if ip := c.ClientIP(); ip != "" {
			identifier = fmt.Sprintf("ip:%s", ip)
		}
	}

	if identifier == "" {
		return ""
	}

	prefix := l.keyPrefix
	if prefix == "" {
		prefix = "rate_limit"
	}
	return fmt.Sprintf("%s:%s", prefix, identifier)
}

func newRedisClient(redisURL string) (*redis.Client, error) {
	if redisURL == "" {
		return nil, fmt.Errorf("redis url is empty")
	}
	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, err
	}
	return redis.NewClient(opts), nil
}
