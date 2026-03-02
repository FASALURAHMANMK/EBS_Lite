package handlers

import (
	"net/http"
	"time"

	"erp-backend/internal/buildinfo"
	"erp-backend/internal/config"
	"erp-backend/internal/database"
	"erp-backend/internal/utils"

	"github.com/gin-gonic/gin"
)

type SupportHandler struct {
	cfg *config.Config
}

func NewSupportHandler(cfg *config.Config) *SupportHandler {
	return &SupportHandler{cfg: cfg}
}

// GET /support/bundle
// Enabled only when not production, unless SUPPORT_BUNDLE_ENABLED=true.
func (h *SupportHandler) GetSupportBundle(c *gin.Context) {
	if h.cfg.Environment == "production" && !h.cfg.SupportBundleEnabled {
		utils.ForbiddenResponse(c, "Support bundle is disabled in production")
		return
	}

	dbErr := database.HealthCheck()
	redisErr := error(nil)
	if h.cfg.ReadyCheckRedis {
		redisErr = database.RedisHealthCheck(h.cfg.RedisURL, h.cfg.ReadyCheckTimeout)
	}

	payload := gin.H{
		"generated_at": time.Now().UTC().Format(time.RFC3339),
		"build":        buildinfo.Get(),
		"health": gin.H{
			"db_ok":    dbErr == nil,
			"redis_ok": redisErr == nil,
		},
		"config": gin.H{
			"environment":                h.cfg.Environment,
			"port":                       h.cfg.Port,
			"rate_limit_enabled":         h.cfg.RateLimitEnabled,
			"rate_limit_requests":        h.cfg.RateLimitRequests,
			"rate_limit_window":          h.cfg.RateLimitWindow.String(),
			"session_last_seen_redis":    h.cfg.SessionLastSeenUseRedis,
			"session_last_seen_throttle": h.cfg.SessionLastSeenThrottle.String(),
			"max_upload_size_bytes":      h.cfg.MaxUploadSize,
			"upload_path":                h.cfg.UploadPath,
			"run_migrations":             h.cfg.RunMigrations,
			"migrations_dir":             h.cfg.MigrationsDir,
			"ready_check_redis":          h.cfg.ReadyCheckRedis,
			"ready_check_timeout":        h.cfg.ReadyCheckTimeout.String(),
		},
		"logs": redactLogLines(utils.DefaultLogLines(h.cfg.SupportBundleLogLines)),
	}

	if dbErr != nil {
		payload["health"].(gin.H)["db_error"] = dbErr.Error()
	}
	if redisErr != nil {
		payload["health"].(gin.H)["redis_error"] = redisErr.Error()
	}

	utils.JSONResponse(c, http.StatusOK, true, "Support bundle generated", payload, nil)
}

func redactLogLines(lines []string) []string {
	if len(lines) == 0 {
		return lines
	}
	out := make([]string, len(lines))
	for i, l := range lines {
		out[i] = utils.RedactSecrets(l)
	}
	return out
}
