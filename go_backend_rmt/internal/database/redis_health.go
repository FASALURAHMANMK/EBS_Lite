package database

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// RedisHealthCheck pings Redis using the given URL.
func RedisHealthCheck(redisURL string, timeout time.Duration) error {
	if redisURL == "" {
		return fmt.Errorf("redis url is empty")
	}
	if timeout <= 0 {
		timeout = 2 * time.Second
	}

	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		return fmt.Errorf("failed to parse redis url: %w", err)
	}
	client := redis.NewClient(opts)
	defer client.Close()

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return fmt.Errorf("redis ping failed: %w", err)
	}
	return nil
}
