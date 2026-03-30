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

	userRoleID, err := s.getUserRoleID(userID)
	if err != nil {
		return nil, err
	}

	var items []models.NotificationItem

	lowStock, err := s.lowStockNotifications(companyID, locationID, readKeys)
	if err != nil {
		return nil, err
	}
	items = append(items, lowStock...)

	workflows, err := s.workflowPendingNotifications(companyID, userRoleID, readKeys)
	if err != nil {
		return nil, err
	}
	items = append(items, workflows...)

	sort.Slice(items, func(i, j int) bool {
		if items[i].IsOverdue != items[j].IsOverdue {
			return items[i].IsOverdue
		}
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

func (s *NotificationsService) getUserRoleID(userID int) (int, error) {
	var roleID int
	if err := s.db.QueryRow(`SELECT COALESCE(role_id, 0) FROM users WHERE user_id = $1`, userID).Scan(&roleID); err != nil {
		if err == sql.ErrNoRows {
			return 0, fmt.Errorf("user not found")
		}
		return 0, fmt.Errorf("failed to get user role: %w", err)
	}
	return roleID, nil
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
               COALESCE(pb.barcode, '') as barcode,
               COALESCE(st.quantity,0) as quantity,
               COALESCE(p.reorder_level,0) as reorder_level,
               COALESCE(st.last_updated, CURRENT_TIMESTAMP) as last_updated
        FROM stock st
        JOIN locations l ON st.location_id = l.location_id
        JOIN products p ON st.product_id = p.product_id
        LEFT JOIN LATERAL (
            SELECT barcode
            FROM product_barcodes
            WHERE product_id = p.product_id
              AND COALESCE(is_active, TRUE) = TRUE
            ORDER BY is_primary DESC, barcode_id
            LIMIT 1
        ) pb ON TRUE
        WHERE l.company_id = $1
          AND l.is_active = TRUE
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
		var locName, productName, barcode string
		var qty float64
		var updated time.Time
		if err := rows.Scan(&locID, &locName, &productID, &productName, &barcode, &qty, &reorder, &updated); err != nil {
			return nil, fmt.Errorf("failed to scan low stock row: %w", err)
		}
		key := fmt.Sprintf("low_stock:loc:%d:product:%d", locID, productID)
		_, isRead := readKeys[key]

		status := "PENDING"
		severity := "WARNING"
		badge := "Low stock"
		if qty <= 0 {
			status = "OVERDUE"
			severity = "CRITICAL"
			badge = "Stockout"
		}

		title := fmt.Sprintf("Low stock: %s", productName)
		bodyParts := []string{fmt.Sprintf("Qty %.2f <= reorder %d at %s", qty, reorder, locName)}
		if strings.TrimSpace(barcode) != "" {
			bodyParts = append(bodyParts, fmt.Sprintf("Barcode %s", strings.TrimSpace(barcode)))
		}

		entityType := "PRODUCT"
		actionLabel := "Open inventory"
		badgeLabel := badge
		list = append(list, models.NotificationItem{
			Key:         key,
			Type:        "LOW_STOCK",
			Title:       title,
			Body:        strings.Join(bodyParts, " • "),
			Status:      status,
			Severity:    severity,
			CreatedAt:   updated,
			IsRead:      isRead,
			IsOverdue:   status == "OVERDUE",
			EntityType:  &entityType,
			EntityID:    &productID,
			LocationID:  &locID,
			ProductID:   &productID,
			ActionLabel: &actionLabel,
			BadgeLabel:  &badgeLabel,
		})
	}
	return list, nil
}

func (s *NotificationsService) workflowPendingNotifications(companyID, userRoleID int, readKeys map[string]struct{}) ([]models.NotificationItem, error) {
	rows, err := s.db.Query(`
        SELECT approval_id,
               entity_type,
               entity_id,
               title,
               COALESCE(summary, '') AS summary,
               COALESCE(priority, 'NORMAL') AS priority,
               due_at,
               created_at
        FROM workflow_requests
        WHERE company_id = $1
          AND approver_role_id = $2
          AND status = 'PENDING'
        ORDER BY COALESCE(due_at, created_at) ASC, created_at DESC
        LIMIT 50
    `, companyID, userRoleID)
	if err != nil {
		return nil, fmt.Errorf("failed to query workflow pending: %w", err)
	}
	defer rows.Close()

	now := time.Now()
	var list []models.NotificationItem
	for rows.Next() {
		var approvalID int
		var entityType string
		var entityID sql.NullInt64
		var title, summary, priority string
		var dueAt, createdAt sql.NullTime
		if err := rows.Scan(&approvalID, &entityType, &entityID, &title, &summary, &priority, &dueAt, &createdAt); err != nil {
			return nil, fmt.Errorf("failed to scan workflow row: %w", err)
		}

		key := fmt.Sprintf("workflow_request:%d", approvalID)
		_, isRead := readKeys[key]

		status := "PENDING"
		severity := "INFO"
		isOverdue := false
		escalationBadge := "Pending approval"
		var duePtr *time.Time
		if dueAt.Valid {
			value := dueAt.Time
			duePtr = &value
			if dueAt.Time.Before(now) {
				status = "OVERDUE"
				severity = "WARNING"
				isOverdue = true
				escalationBadge = "Overdue approval"
			}
		}
		if strings.EqualFold(strings.TrimSpace(priority), "HIGH") {
			severity = "CRITICAL"
		}

		bodyParts := []string{}
		if strings.TrimSpace(summary) != "" {
			bodyParts = append(bodyParts, strings.TrimSpace(summary))
		}
		if dueAt.Valid {
			bodyParts = append(bodyParts, fmt.Sprintf("Due %s", dueAt.Time.Local().Format("2006-01-02 15:04")))
		}

		actionLabel := "Review approval"
		item := models.NotificationItem{
			Key:         key,
			Type:        "APPROVAL_PENDING",
			Title:       title,
			Body:        strings.Join(bodyParts, " • "),
			Status:      status,
			Severity:    severity,
			CreatedAt:   now,
			IsRead:      isRead,
			IsOverdue:   isOverdue,
			ApprovalID:  &approvalID,
			EntityType:  &entityType,
			ActionLabel: &actionLabel,
			BadgeLabel:  &escalationBadge,
			DueAt:       duePtr,
		}
		if entityID.Valid {
			entityIDValue := int(entityID.Int64)
			item.EntityID = &entityIDValue
		}
		if createdAt.Valid {
			item.CreatedAt = createdAt.Time
		}
		list = append(list, item)
	}
	return list, nil
}
