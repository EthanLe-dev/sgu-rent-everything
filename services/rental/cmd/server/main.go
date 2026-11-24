package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"sgu-rent-everything/services/rental/internal/api"
)

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	dbURL := envOr("DATABASE_URL", "postgres://postgres:postgres@postgres:5432/rent?sslmode=disable")
	pool, err := pgxpool.New(ctx, dbURL)
	if err != nil {
		log.Fatalf("pgxpool.New: %v", err)
	}
	defer pool.Close()

	for range 15 {
		if err := pool.Ping(ctx); err == nil {
			break
		}
		time.Sleep(1 * time.Second)
	}

	cooldown, _ := strconv.Atoi(envOr("OTP_COOLDOWN_SECONDS", "30"))
	cfg := api.Config{
		SMTPHost:             envOr("SMTP_HOST", "mailpit"),
		SMTPPort:             envOr("SMTP_PORT", "1025"),
		SMTPFrom:             envOr("SMTP_FROM", "no-reply@sgu.test"),
		OTPPepper:            envOr("OTP_PEPPER", "local-dev-pepper"),
		OTPCooldownSeconds:   cooldown,
		S3Endpoint:           envOr("S3_ENDPOINT", "http://seaweedfs:8333"),
		S3Bucket:             envOr("S3_BUCKET", "campus-rent"),
		S3AccessKey:          envOr("S3_ACCESS_KEY", ""),
		S3SecretKey:          envOr("S3_SECRET_KEY", ""),
		NotificationURL:      envOr("NOTIFICATION_INTERNAL_URL", "http://notification-service:8082"),
		InternalServiceToken: envOr("INTERNAL_SERVICE_TOKEN", "local-internal-token"),
	}

	if appEnv := os.Getenv("APP_ENV"); appEnv == "production" || appEnv == "pilot" {
		if cfg.OTPPepper == "" || cfg.OTPPepper == "local-dev-pepper" || cfg.InternalServiceToken == "" || cfg.InternalServiceToken == "local-internal-token" {
			log.Fatalf("APP_ENV=%s requires non-default OTP_PEPPER and INTERNAL_SERVICE_TOKEN", appEnv)
		}
	}

	srv := api.NewServer(pool, cfg)
	s3c := api.NewS3Client(cfg.S3Endpoint, cfg.S3Bucket, cfg.S3AccessKey, cfg.S3SecretKey)
	for range 10 {
		if err := s3c.EnsureBucket(ctx); err == nil {
			break
		}
		time.Sleep(1 * time.Second)
	}

	go srv.StartOutboxWorker(ctx)

	port := envOr("PORT", "8081")
	httpSrv := &http.Server{
		Addr:              ":" + port,
		Handler:           srv.Routes(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		log.Printf("rental-service listening on :%s", port)
		if err := httpSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("ListenAndServe: %v", err)
		}
	}()

	<-ctx.Done()
	shutCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = httpSrv.Shutdown(shutCtx)
}
