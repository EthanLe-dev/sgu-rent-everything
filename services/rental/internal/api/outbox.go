package api

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
)

type OutboxEventPayload struct {
	EventID      string   `json:"event_id"`
	Type         string   `json:"type"`
	OccurredAt   string   `json:"occurred_at"`
	TargetType   string   `json:"target_type"`
	TargetID     string   `json:"target_id"`
	RecipientIDs []string `json:"recipient_ids"`
}

func (s *Server) StartOutboxWorker(ctx context.Context) {
	if s.cfg.NotificationURL == "" {
		return
	}
	client := &http.Client{Timeout: 5 * time.Second}
	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			s.ProcessOutboxOnce(ctx, client)
		}
	}
}

func (s *Server) ProcessOutboxOnce(ctx context.Context, client *http.Client) int {
	rows, err := s.db.Query(ctx, `
		SELECT id, event_type, occurred_at, target_type, target_id, recipient_ids, attempts
		FROM outbox_events
		WHERE delivered_at IS NULL AND next_attempt_at <= $1
		ORDER BY created_at ASC
		LIMIT 20
	`, s.now().UTC())
	if err != nil {
		return 0
	}
	type item struct {
		payload  OutboxEventPayload
		attempts int
	}
	var batch []item
	for rows.Next() {
		var it item
		var occ time.Time
		if err := rows.Scan(&it.payload.EventID, &it.payload.Type, &occ, &it.payload.TargetType, &it.payload.TargetID, &it.payload.RecipientIDs, &it.attempts); err == nil {
			it.payload.OccurredAt = formatTS(occ)
			batch = append(batch, it)
		}
	}
	rows.Close()

	delivered := 0
	for _, it := range batch {
		if err := s.deliverOutboxEvent(ctx, client, it.payload); err != nil {
			backoff := time.Duration(1<<min(it.attempts, 5)) * time.Second
			_, _ = s.db.Exec(ctx, `
				UPDATE outbox_events
				SET attempts = attempts + 1, next_attempt_at = $2, last_error = $3
				WHERE id = $1
			`, it.payload.EventID, s.now().UTC().Add(backoff), err.Error())
			log.Printf("outbox delivery failed (%s): %v", it.payload.EventID, err)
			continue
		}
		_, _ = s.db.Exec(ctx, `UPDATE outbox_events SET delivered_at = $2 WHERE id = $1`, it.payload.EventID, s.now().UTC())
		delivered++
	}
	return delivered
}

func (s *Server) deliverOutboxEvent(ctx context.Context, client *http.Client, payload OutboxEventPayload) error {
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, s.cfg.NotificationURL+"/internal/v1/events", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+s.cfg.InternalServiceToken)
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusNoContent && (resp.StatusCode < 200 || resp.StatusCode >= 300) {
		return fmt.Errorf("notification returned status %d", resp.StatusCode)
	}
	return nil
}
