package services

import (
	"database/sql"
	"fmt"
	"sort"
	"strings"
	"time"

	"erp-backend/internal/database"
	"erp-backend/internal/models"
)

type NotificationsService struct {
	db *sql.DB
}

func NewNotificationsService() *NotificationsService {
	return &NotificationsService{db: database.GetDB()}
}

func (s *NotificationsService) ListNotifications(companyID, userID int, locationID *int) ([]models.NotificationItem, error) {
	readKeys, err := s.getReadKeys(companyID, userID)
	if err != nil {
		return nil, err
	}

	var items []models.NotificationItem

	lowStock, err := s.lowStockNotifications(companyID, locationID, readKeys)
	if err != nil {
		return nil, err
	}
	items = append(items, lowStock...)

	approvals, err := s.workflowPendingNotifications(companyID, readKeys)
	if err != nil {
		return nil, err
	}
	items = append(items, approvals...)

	// Newest first (best-effort; some sources may not have true created timestamps).
	sort.Slice(items, func(i, j int) bool {
		return items[i].CreatedAt.After(items[j].CreatedAt)
	})

	return items, nil
}

func (s *NotificationsService) UnreadCount(companyID, userID int, locationID *int) (int, error) {
	items, err := s.ListNotifications(companyID, userID, locationID)
	if err != nil {
		return 0, err
	}
	n := 0
	for _, it := range items {
		if !it.IsRead {
			n++
		}
	}
	return n, nil
}

func (s *NotificationsService) MarkRead(companyID, userID int, keys []string) error {
	if len(keys) == 0 {
		return fmt.Errorf("keys required")
	}
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare(`
        INSERT INTO notification_reads (company_id, user_id, notification_key, read_at)
        VALUES ($1,$2,$3,CURRENT_TIMESTAMP)
        ON CONFLICT (company_id, user_id, notification_key) DO NOTHING
    `)
	if err != nil {
		return fmt.Errorf("failed to prepare: %w", err)
	}
	defer stmt.Close()

	for _, k := range keys {
		key := strings.TrimSpace(k)
		if key == "" {
			continue
		}
		if _, err := stmt.Exec(companyID, userID, key); err != nil {
			return fmt.Errorf("failed to mark read: %w", err)
		}
	}

	return tx.Commit()
}

func (s *NotificationsService) getReadKeys(companyID, userID int) (map[string]struct{}, error) {
	rows, err := s.db.Query(`SELECT notification_key FROM notification_reads WHERE company_id=$1 AND user_id=$2`, companyID, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to read notification keys: %w", err)
	}
	defer rows.Close()

	m := make(map[string]struct{})
	for rows.Next() {
		var key string
		if err := rows.Scan(&key); err != nil {
			return nil, fmt.Errorf("failed to scan read key: %w", err)
		}
		if key != "" {
			m[key] = struct{}{}
		}
	}
	return m, nil
}

func (s *NotificationsService) lowStockNotifications(companyID int, locationID *int, readKeys map[string]struct{}) ([]models.NotificationItem, error) {
	query := `
        SELECT st.location_id,
               COALESCE(l.name,'') as location_name,
               st.product_id,
               COALESCE(p.name,'') as product_name,
               COALESCE(st.quantity,0) as quantity,
               COALESCE(p.reorder_level,0) as reorder_level,
               COALESCE(st.last_updated, CURRENT_TIMESTAMP) as last_updated
        FROM stock st
        JOIN locations l ON st.location_id = l.location_id
        JOIN products p ON st.product_id = p.product_id
        WHERE l.company_id = $1
          AND l.is_deleted = FALSE
          AND p.is_deleted = FALSE
          AND p.is_active = TRUE
          AND COALESCE(p.reorder_level,0) > 0
          AND COALESCE(st.quantity,0) <= COALESCE(p.reorder_level,0)
    `

	args := []interface{}{companyID}
	if locationID != nil && *locationID != 0 {
		query += " AND st.location_id = $2"
		args = append(args, *locationID)
	}

	query += " ORDER BY COALESCE(st.quantity,0) ASC, p.name ASC LIMIT 50"

	rows, err := s.db.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query low stock: %w", err)
	}
	defer rows.Close()

	var list []models.NotificationItem
	for rows.Next() {
		var locID, productID, reorder int
		var locName, productName string
		var qty float64
		var updated time.Time
		if err := rows.Scan(&locID, &locName, &productID, &productName, &qty, &reorder, &updated); err != nil {
			return nil, fmt.Errorf("failed to scan low stock row: %w", err)
		}
		key := fmt.Sprintf("low_stock:loc:%d:product:%d", locID, productID)
		_, isRead := readKeys[key]

		title := fmt.Sprintf("Low stock: %s", productName)
		body := fmt.Sprintf("Qty %.2f ≤ reorder %d at %s", qty, reorder, locName)

		list = append(list, models.NotificationItem{
			Key:       key,
			Type:      "LOW_STOCK",
			Title:     title,
			Body:      body,
			CreatedAt: updated,
			IsRead:    isRead,
		})
	}
	return list, nil
}

func (s *NotificationsService) workflowPendingNotifications(companyID int, readKeys map[string]struct{}) ([]models.NotificationItem, error) {
	rows, err := s.db.Query(`
        SELECT wa.approval_id,
               wa.state_id,
               COALESCE(ws.state_name,'') as state_name,
               wa.approver_role_id,
               wa.created_by
        FROM workflow_approvals wa
        LEFT JOIN workflow_states ws ON wa.state_id = ws.state_id
        JOIN users u ON wa.created_by = u.user_id
        WHERE wa.status = 'PENDING'
          AND u.company_id = $1
        ORDER BY wa.approval_id DESC
        LIMIT 50
    `, companyID)
	if err != nil {
		return nil, fmt.Errorf("failed to query workflow pending: %w", err)
	}
	defer rows.Close()

	now := time.Now()
	var list []models.NotificationItem
	for rows.Next() {
		var approvalID, stateID, approverRoleID, createdBy int
		var stateName string
		if err := rows.Scan(&approvalID, &stateID, &stateName, &approverRoleID, &createdBy); err != nil {
			return nil, fmt.Errorf("failed to scan workflow row: %w", err)
		}

		key := fmt.Sprintf("workflow_approval:%d", approvalID)
		_, isRead := readKeys[key]

		title := "Approval pending"
		body := fmt.Sprintf("Approval #%d pending (state %d %s)", approvalID, stateID, strings.TrimSpace(stateName))

		list = append(list, models.NotificationItem{
			Key:       key,
			Type:      "APPROVAL_PENDING",
			Title:     title,
			Body:      body,
			CreatedAt: now,
			IsRead:    isRead,
		})
	}
	return list, nil
}
