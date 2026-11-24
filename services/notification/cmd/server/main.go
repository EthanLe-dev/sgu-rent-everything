package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"sgu-rent-everything/services/notification/internal/api"
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

	internalToken := envOr("INTERNAL_SERVICE_TOKEN", "local-internal-token")
	if appEnv := os.Getenv("APP_ENV"); appEnv == "production" || appEnv == "pilot" {
		if internalToken == "" || internalToken == "local-internal-token" {
			log.Fatalf("APP_ENV=%s requires non-default INTERNAL_SERVICE_TOKEN", appEnv)
		}
	}
	srv := api.NewServer(pool, api.Config{
		InternalServiceToken: internalToken,
	})

	port := envOr("PORT", "8082")
	httpSrv := &http.Server{
		Addr:              ":" + port,
		Handler:           srv.Routes(),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		log.Printf("notification-service listening on :%s", port)
		if err := httpSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("ListenAndServe: %v", err)
		}
	}()

	<-ctx.Done()
	shutCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = httpSrv.Shutdown(shutCtx)
}
